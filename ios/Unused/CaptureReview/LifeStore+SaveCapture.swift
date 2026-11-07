import ExperienceCore
import Foundation

// Was the end of LifeStore in Experience/Life/LifeStore.swift.
extension LifeStore {

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
