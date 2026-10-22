import ExperienceCore
import Foundation
import Observation
import Supabase

/// What the person is saving, before the server has it.
struct ExperienceDraft: Codable, Equatable {
    var title: String
    var description: String?
    var state: ExperienceState = .experienced
    var startsAt: Date?
    var endsAt: Date?
    var precision: TimePrecision = .unknown
    var timezone: String?
    var placeName: String?
    var categories: [String] = []
    var listingId: UUID?
    /// Field provenance, e.g. ["time": .source] when the date came from a photo.
    var provenance: [String: Provenance] = [:]
}

/// A photo or video picked or shot for a save. The file is already in `LifeFiles.originals`.
struct PendingMedia: Codable, Equatable {
    var clientId: UUID
    var kind: MediaAsset.Kind
    var fileName: String
    var takenAt: Date?
    var duration: Double?
    var width: Int?
    var height: Int?
    var contentType: String
}

/// Put the saved Experience into a collection; `newTitle` creates the collection too.
struct CollectionChoice: Codable, Equatable {
    var collectionId: UUID
    var newTitle: String?
    var newKind: ExperienceCollection.Kind?
}

/// One save waiting for the server. Its id is the Experience's id and its save_id, so a retry can't duplicate it.
struct PendingSave: Codable, Identifiable, Equatable {
    var id: UUID
    var draft: ExperienceDraft
    var media: [PendingMedia]
    var collection: CollectionChoice?
    var createdAt: Date
    var attempts = 0
    var lastError: String?
}

/// The person's own life: their Experiences, collections and media, saved on the phone first and synced
/// when the server is reachable (brief §6, ADR-007). The UI reads one merged list, pending saves included.
@MainActor @Observable
final class LifeStore {
    private(set) var experiences: [Experience] = []
    private(set) var collections: [ExperienceCollection] = []
    private(set) var items: [CollectionItem] = []
    private(set) var media: [UUID: [MediaAsset]] = [:]
    private(set) var pending: [PendingSave] = []
    private(set) var loaded = false
    private(set) var loadError: String?
    private(set) var syncing = false

    private let supabase: SupabaseClient
    var storage: SupabaseStorageClient { supabase.storage }

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        LifeFiles.prepare()
        pending = Self.readOutbox()
    }

    // MARK: Reading

    /// Everything, server rows first, then saves still on the phone. Newest lived time first.
    var all: [Experience] {
        let serverIds = Set(experiences.map(\.id))
        let local = pending.filter { !serverIds.contains($0.id) }.compactMap(localExperience)
        // Newest lived time first; on the same day, the one added most recently first.
        return (experiences + local).sorted { a, b in
            let ta = a.startsAt ?? a.createdAt, tb = b.startsAt ?? b.createdAt
            return ta != tb ? ta > tb : a.createdAt > b.createdAt
        }
    }

    var experienced: [Experience] { all.filter { $0.state == .experienced && $0.archivedAt == nil } }
    var wants: [Experience] { all.filter { ($0.state == .want || $0.state == .planned) && $0.archivedAt == nil } }
    var experiencedCount: Int { all.experiencedCount }

    /// Distinct places lived in, by city when known, else the last part of the locality.
    var cityCount: Int {
        Set(experienced.compactMap { e in e.cityId ?? e.placeLocality?.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } }).count
    }

    var allCollections: [ExperienceCollection] {
        let serverIds = Set(collections.map(\.id))
        var local: [ExperienceCollection] = []
        for p in pending {
            guard let c = p.collection, let title = c.newTitle, !serverIds.contains(c.collectionId),
                  !local.contains(where: { $0.id == c.collectionId }) else { continue }
            local.append(ExperienceCollection(id: c.collectionId, ownerId: p.id, title: title, description: nil,
                                              kind: c.newKind ?? .other, visibility: .private, coverMediaId: nil, createdAt: p.createdAt))
        }
        // Most recently lived first: a collection sits where its latest Experience does.
        let latest = { (c: ExperienceCollection) -> Date in
            self.members(of: c.id).compactMap { $0.startsAt ?? $0.completedAt }.max() ?? c.createdAt
        }
        return (collections + local).sorted { latest($0) > latest($1) }
    }

    /// The Experiences in a collection, in its order (pending ones at the end).
    func members(of collection: UUID) -> [Experience] {
        let byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let server = items.filter { $0.collectionId == collection }.sorted { $0.position < $1.position }.compactMap { byId[$0.experienceId] }
        let local = pending.filter { p in p.collection?.collectionId == collection && !server.contains { $0.id == p.id } }
            .compactMap { byId[$0.id] }
        return server + local
    }

    func mediaFor(_ id: UUID) -> [MediaAsset] {
        if let p = pending.first(where: { $0.id == id }) {
            return p.media.enumerated().map { i, m in
                MediaAsset(id: m.clientId, experienceId: id, clientId: m.clientId, kind: m.kind, position: i, caption: nil, altText: nil,
                           takenAt: m.takenAt, durationSeconds: m.duration, width: m.width, height: m.height, originalPath: nil,
                           thumbPath: nil, deviceFile: m.fileName, status: .onDevice)
            }
        }
        return (media[id] ?? []).sorted { $0.position < $1.position }
    }

    /// The card's picture: the chosen cover, else the first photo or video.
    func cover(for id: UUID) -> MediaAsset? {
        let list = mediaFor(id)
        let chosen = all.first { $0.id == id }?.coverMediaId
        return list.first { $0.id == chosen } ?? list.first
    }

    func isPending(_ id: UUID) -> Bool { pending.contains { $0.id == id } }

    /// Plain words for where a save stands (brief §20: never a bare spinner).
    func syncStatus(_ id: UUID) -> String? {
        guard let p = pending.first(where: { $0.id == id }) else { return nil }
        return p.lastError == nil || p.attempts == 0 ? "Saved on this device; waiting to upload" : "Saved on this device; will retry the upload"
    }

    func load() async {
        do {
            let me = try await supabase.auth.session.user.id
            async let exps: [Experience] = supabase.from("experiences").select().eq("owner_id", value: me).execute().value
            async let cols: [ExperienceCollection] = supabase.from("collections").select().eq("owner_id", value: me)
                .order("created_at", ascending: false).execute().value
            async let assets: [MediaAsset] = supabase.from("media_assets").select().eq("owner_id", value: me).execute().value
            let (e, c, m) = try await (exps, cols, assets)
            let mine = Set(c.map(\.id))
            let its: [CollectionItem] = mine.isEmpty ? [] : try await supabase.from("collection_items").select()
                .in("collection_id", values: mine.map(\.uuidString)).execute().value
            experiences = e
            collections = c
            items = its
            media = Dictionary(grouping: m, by: \.experienceId)
            loadError = nil
        } catch {
            loadError = "Couldn't refresh your Experiences. What's saved on this phone is still here."
        }
        loaded = true
        await sync()
    }

    // MARK: Saving

    /// Saves on the phone first. Returns at once; the upload follows when it can.
    @discardableResult
    func save(_ draft: ExperienceDraft, media: [PendingMedia], collection: CollectionChoice?) -> UUID {
        let save = PendingSave(id: UUID(), draft: draft, media: media, collection: collection, createdAt: Date())
        write(save)
        pending.append(save)
        Task { await sync() }
        return save.id
    }

    /// Uploads every pending save in order. Safe to call any time: ids make every step idempotent.
    func sync() async {
        guard !syncing else { return }
        guard let me = try? await supabase.auth.session.user.id else { return }
        syncing = true
        defer { syncing = false }
        for save in pending {
            do {
                try await upload(save, owner: me)
                remove(save)
            } catch {
                var failed = save
                failed.attempts += 1
                failed.lastError = String(describing: error)
                write(failed)
                if let i = pending.firstIndex(where: { $0.id == save.id }) { pending[i] = failed }
                break // the server or the network is unhappy; try again later rather than hammer it
            }
        }
        await uploadStrays(owner: me)
        await refreshAfterSync()
    }

    /// Media the server knows about but that never finished uploading (an interrupted sync, or photos from the
    /// first in-app camera): if the file is still on this phone, send it now. Nothing stays stranded.
    private func uploadStrays(owner: UUID) async {
        let strays = media.values.joined().filter { $0.status != .ready && !isPending($0.experienceId) }
        for m in strays {
            guard let name = m.deviceFile, let file = LifeFiles.locate(name) else { continue }
            let base = "\(owner.uuidString.lowercased())/\(m.experienceId.uuidString.lowercased())/\(m.clientId.uuidString.lowercased())"
            let ext = file.pathExtension.isEmpty ? (m.kind == .photo ? "jpg" : "mov") : file.pathExtension.lowercased()
            let facts = await LifeMedia.facts(of: file, kind: m.kind)
            do {
                try await storage.from("media").upload("\(base).\(ext)", fileURL: file, options: FileOptions(contentType: facts.contentType, upsert: true))
                var thumb: String?
                if let data = await LifeMedia.makeThumbnail(of: file, kind: m.kind) {
                    try? data.write(to: LifeFiles.thumb(m.clientId))
                    try await storage.from("media").upload("\(base).thumb.jpg", data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    thumb = "\(base).thumb.jpg"
                }
                struct Done: Encodable {
                    let status = "ready", original_path: String, thumb_path: String?, width: Int?, height: Int?, content_type: String
                }
                try await supabase.from("media_assets").update(Done(original_path: "\(base).\(ext)", thumb_path: thumb, width: facts.width,
                                                                    height: facts.height, content_type: facts.contentType))
                    .eq("id", value: m.id).execute()
                struct Cover: Encodable { let cover_media_id: UUID }
                try? await supabase.from("experiences").update(Cover(cover_media_id: m.id))
                    .eq("id", value: m.experienceId).is("cover_media_id", value: nil).execute()
            } catch {
                continue // stays on the phone; the next sync tries again
            }
        }
    }

    private func upload(_ save: PendingSave, owner: UUID) async throws {
        let d = save.draft
        if let c = save.collection, let title = c.newTitle {
            struct NewCollection: Encodable { let id: UUID; let title: String; let kind: String }
            try await supabase.from("collections")
                .upsert(NewCollection(id: c.collectionId, title: title, kind: (c.newKind ?? .other).rawValue), onConflict: "id", ignoreDuplicates: true)
                .execute()
        }

        struct Row: Encodable {
            let id: UUID, save_id: UUID, title: String, description: String?, state: String
            let starts_at: Date?, ends_at: Date?, time_precision: String, timezone: String?
            let place_name: String?, categories: [String], listing_id: UUID?, provenance: [String: String]
        }
        try await supabase.from("experiences").upsert(Row(
            id: save.id, save_id: save.id, title: d.title, description: d.description, state: d.state.rawValue,
            starts_at: d.startsAt, ends_at: d.endsAt, time_precision: (d.startsAt == nil ? TimePrecision.unknown : d.precision).rawValue,
            timezone: d.timezone, place_name: d.placeName, categories: d.categories, listing_id: d.listingId,
            provenance: d.provenance.mapValues(\.rawValue)
        ), onConflict: "id", ignoreDuplicates: true).execute()

        for (position, m) in save.media.enumerated() {
            let ext = (m.fileName as NSString).pathExtension.lowercased()
            let base = "\(owner.uuidString.lowercased())/\(save.id.uuidString.lowercased())/\(m.clientId.uuidString.lowercased())"
            let original = "\(base).\(ext.isEmpty ? (m.kind == .photo ? "jpg" : "mov") : ext)"
            let thumb = "\(base).thumb.jpg"
            let file = LifeFiles.original(m.fileName)
            try await storage.from("media").upload(original, fileURL: file, options: FileOptions(contentType: m.contentType, upsert: true))
            var thumbPath: String?
            if let data = await LifeMedia.makeThumbnail(of: file, kind: m.kind) {
                try? data.write(to: LifeFiles.thumb(m.clientId))
                try await storage.from("media").upload(thumb, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                thumbPath = thumb
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: file.path())[.size] as? Int64) ?? nil
            struct MediaRow: Encodable {
                let id: UUID, experience_id: UUID, client_id: UUID, kind: String, position: Int
                let taken_at: Date?, duration_seconds: Double?, width: Int?, height: Int?, byte_size: Int64?, content_type: String
                let original_path: String, thumb_path: String?, device_file: String, status: String
            }
            try await supabase.from("media_assets").upsert(MediaRow(
                id: m.clientId, experience_id: save.id, client_id: m.clientId, kind: m.kind.rawValue, position: position,
                taken_at: m.takenAt, duration_seconds: m.duration, width: m.width, height: m.height, byte_size: size,
                content_type: m.contentType, original_path: original, thumb_path: thumbPath, device_file: m.fileName, status: "ready"
            ), onConflict: "owner_id,client_id").execute()
        }
        if let first = save.media.first {
            struct Cover: Encodable { let cover_media_id: UUID }
            try await supabase.from("experiences").update(Cover(cover_media_id: first.clientId))
                .eq("id", value: save.id).is("cover_media_id", value: nil).execute()
        }

        if let c = save.collection {
            struct Item: Encodable { let collection_id: UUID; let experience_id: UUID; let position: Int }
            let count = items.filter { $0.collectionId == c.collectionId }.count
            try await supabase.from("collection_items")
                .upsert(Item(collection_id: c.collectionId, experience_id: save.id, position: count),
                        onConflict: "collection_id,experience_id", ignoreDuplicates: true)
                .execute()
        }
    }

    /// After a sync, re-read what changed so cards switch from local to server rows without a flash.
    private func refreshAfterSync() async {
        guard let me = try? await supabase.auth.session.user.id else { return }
        if let e: [Experience] = try? await supabase.from("experiences").select().eq("owner_id", value: me).execute().value { experiences = e }
        if let c: [ExperienceCollection] = try? await supabase.from("collections").select().eq("owner_id", value: me)
            .order("created_at", ascending: false).execute().value { collections = c }
        if let m: [MediaAsset] = try? await supabase.from("media_assets").select().eq("owner_id", value: me).execute().value {
            media = Dictionary(grouping: m, by: \.experienceId)
        }
        let mine = collections.map { $0.id.uuidString }
        if !mine.isEmpty, let its: [CollectionItem] = try? await supabase.from("collection_items").select()
            .in("collection_id", values: mine).execute().value { items = its }
    }

    /// Signing out: forget the server copy in memory. Saves still on the phone stay for the next sign-in.
    func reset() {
        experiences = []; collections = []; items = []; media = [:]; loaded = false
    }

    // MARK: Outbox files

    private func write(_ save: PendingSave) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(save) else { return }
        try? data.write(to: LifeFiles.outbox.appending(path: "\(save.id.uuidString).json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func remove(_ save: PendingSave) {
        try? FileManager.default.removeItem(at: LifeFiles.outbox.appending(path: "\(save.id.uuidString).json"))
        pending.removeAll { $0.id == save.id }
    }

    private static func readOutbox() -> [PendingSave] {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: LifeFiles.outbox, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? dec.decode(PendingSave.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func localExperience(_ p: PendingSave) -> Experience? {
        let d = p.draft
        return Experience(id: p.id, ownerId: p.id, saveId: p.id, state: d.state, isDraft: false, archivedAt: nil, visibility: .private,
                          title: d.title, description: d.description, categories: d.categories, startsAt: d.startsAt, endsAt: d.endsAt,
                          timePrecision: d.startsAt == nil ? .unknown : d.precision, timezone: d.timezone, placeName: d.placeName,
                          placeLocality: nil, placeLat: nil, placeLng: nil, cityId: nil, listingId: d.listingId, inspiredBy: nil,
                          completedAt: d.state == .experienced ? p.createdAt : nil, coverMediaId: p.media.first?.clientId,
                          provenance: d.provenance, createdAt: p.createdAt, updatedAt: p.createdAt)
    }

    // MARK: Camera

    /// A photo or video from the in-app camera becomes an Experience of its own (with the place, when one was
    /// picked from the catalog). It's copied into the originals and saved like any other: phone first.
    func saveCapture(_ captured: CapturedMedia, listing: CatalogItem?) async {
        let clientId = UUID()
        let file = "\(clientId.uuidString.lowercased()).\(captured.url.pathExtension.isEmpty ? "jpg" : captured.url.pathExtension)"
        try? FileManager.default.copyItem(at: captured.url, to: LifeFiles.original(file))
        let kind: MediaAsset.Kind = captured.kind == .video ? .video : .photo
        let facts = await LifeMedia.facts(of: LifeFiles.original(file), kind: kind)
        let tz = TimeZone.current.identifier
        var provenance: [String: Provenance] = ["time": .source]
        if let listing { provenance["title"] = listing.sourcedTitle.provenance; provenance["categories"] = .estimated }
        let title = listing?.title ?? ExperienceTime(start: captured.takenAt, precision: .day, timezone: tz).label()
        if listing == nil { provenance["title"] = .source }
        let draft = ExperienceDraft(title: title, startsAt: captured.takenAt, precision: .day, timezone: tz,
                                    placeName: listing?.place?.name, categories: listing.map { [$0.category.life.rawValue] } ?? [],
                                    listingId: listing?.id, provenance: provenance)
        save(draft, media: [PendingMedia(clientId: clientId, kind: kind, fileName: file, takenAt: captured.takenAt,
                                         duration: captured.duration ?? facts.duration, width: facts.width, height: facts.height,
                                         contentType: facts.contentType)], collection: nil)
    }
}
