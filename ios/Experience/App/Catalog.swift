import ExperienceCore
import Foundation
import Supabase

/// One catalog Experience as the map and lists need it (light: loaded for the whole city at once).
struct CatalogItem: Identifiable, Equatable, Decodable {
    struct PlaceLink: Decodable, Equatable {
        struct Place: Decodable, Equatable { let name: String; let neighborhood: String?; let lat: Double?; let lng: Double? }
        let role: String
        let places: Place?
    }

    let id: UUID
    let title: String
    let category: ExperienceCategory
    let kind: String
    let subcategory: String?
    let tags: [String]
    let priceMinCents: Int?
    let priceMaxCents: Int?
    let provenance: [String: Provenance]
    let experiencePlaces: [PlaceLink]

    enum CodingKeys: String, CodingKey {
        case id, title, category, kind, subcategory, tags, provenance
        case priceMinCents = "price_min_cents", priceMaxCents = "price_max_cents", experiencePlaces = "experience_places"
    }

    var place: PlaceLink.Place? { experiencePlaces.first { $0.role == "primary" }?.places }
    var coordinate: (lat: Double, lng: Double)? { place.flatMap { p in p.lat.flatMap { lat in p.lng.map { (lat, $0) } } } }
    var sourcedTitle: Sourced<String> { Sourced(title, provenance["title"] ?? .curated) }
    var price: String? { PriceText.label(priceMinCents, priceMaxCents) }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return [title, subcategory ?? "", place?.name ?? "", place?.neighborhood ?? "", tags.joined(separator: " ")]
            .contains { $0.lowercased().contains(q) }
    }
}

/// Everything about one Experience, for the detail sheet.
struct ExperienceDetail: Decodable, Identifiable {
    struct Link: Decodable, Hashable { let kind: String; let url: URL }
    struct Occurrence: Decodable, Hashable { let startsAt: Date; let endsAt: Date?
        enum CodingKeys: String, CodingKey { case startsAt = "starts_at", endsAt = "ends_at" } }
    struct Hours: Decodable, Hashable { let day: Int; let open: String; let close: String }
    struct PlaceLink: Decodable {
        struct Place: Decodable { let name: String; let address: String?; let neighborhood: String?; let lat: Double?; let lng: Double? }
        let role: String
        let places: Place?
    }

    let id: UUID
    let title: String
    let intent: String?
    let description: String?
    let category: ExperienceCategory
    let kind: String
    let subcategory: String?
    let tags: [String]
    let goodFor: [String]
    let priceMinCents: Int?
    let priceMaxCents: Int?
    let durationMinMinutes: Int?
    let durationMaxMinutes: Int?
    let hours: [Hours]
    let provenance: [String: Provenance]
    let experiencePlaces: [PlaceLink]
    let experienceLinks: [Link]
    let experienceOccurrences: [Occurrence]

    enum CodingKeys: String, CodingKey {
        case id, title, intent, description, category, kind, subcategory, tags, hours, provenance
        case goodFor = "good_for", priceMinCents = "price_min_cents", priceMaxCents = "price_max_cents"
        case durationMinMinutes = "duration_min_minutes", durationMaxMinutes = "duration_max_minutes"
        case experiencePlaces = "experience_places", experienceLinks = "experience_links", experienceOccurrences = "experience_occurrences"
    }

    var place: PlaceLink.Place? { experiencePlaces.first { $0.role == "primary" }?.places }
    func sourced(_ field: String, _ value: String) -> Sourced<String> { Sourced(value, provenance[field] ?? .curated) }
    var upcoming: [Occurrence] { experienceOccurrences.filter { ($0.endsAt ?? $0.startsAt) >= Date() }.sorted { $0.startsAt < $1.startsAt } }
    var officialLinks: [Link] { experienceLinks.filter { $0.kind != "source" } }
    var sources: [Link] { experienceLinks.filter { $0.kind == "source" } }
}

enum PriceText {
    static func label(_ min: Int?, _ max: Int?) -> String? {
        guard let min else { return nil }
        if min == 0 && (max ?? 0) == 0 { return "Free" }
        let d = { (c: Int) in "$\(c / 100)" }
        if let max, max != min { return "\(d(min))–\(d(max))" }
        return d(min)
    }

    static func duration(_ min: Int?, _ max: Int?) -> String? {
        guard let min else { return nil }
        func f(_ m: Int) -> String {
            if m < 60 { return "\(m) min" }
            if m % 60 == 0 { return "\(m / 60) hr\(m == 60 ? "" : "s")" }
            if m % 30 == 0 { return "\(Double(m) / 60) hrs" }
            return "\(m / 60) hr \(m % 60) min"
        }
        if let max, max != min { return "\(f(min))–\(f(max))" }
        return f(min)
    }
}

extension AppModel {
    /// The whole published catalog for the user's city (a few hundred rows).
    func loadCatalog() async {
        guard let cityId = profile?.cityId ?? cities.first(where: { $0.status != .coming })?.id, catalog[cityId] == nil else { return }
        do {
            let rows: [CatalogItem] = try await supabase.from("experiences")
                .select("id, title, category, kind, subcategory, tags, price_min_cents, price_max_cents, provenance, experience_places(role, places(name, neighborhood, lat, lng))")
                .eq("city_id", value: cityId).eq("status", value: "published")
                .order("title")
                .execute().value
            catalog[cityId] = rows
        } catch {
            catalogError = "Couldn't load places. Check your connection."
        }
    }

    var cityCatalog: [CatalogItem] { profile?.cityId.flatMap { catalog[$0] } ?? [] }

    func loadStates() async {
        let rows: [UserExperienceState] = (try? await supabase.from("user_experiences")
            .select("experience_id, saved_at, interested_at, not_interested_at, done_at, rating, from_recommendation")
            .execute().value) ?? []
        states = Dictionary(rows.map { ($0.experienceId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func detail(_ id: UUID) async throws -> ExperienceDetail {
        try await supabase.from("experiences")
            .select("id, title, intent, description, category, kind, subcategory, tags, good_for, price_min_cents, price_max_cents, duration_min_minutes, duration_max_minutes, hours, provenance, experience_places(role, places(name, address, neighborhood, lat, lng)), experience_links(kind, url), experience_occurrences(starts_at, ends_at)")
            .eq("id", value: id)
            .single()
            .execute().value
    }

    /// Sends feedback and keeps the local state in step (the server's row wins).
    @discardableResult
    func send(_ feedback: Feedback) async throws -> UserExperienceState {
        let state = try await api.feedback(feedback)
        states[state.experienceId] = state
        return state
    }

    /// Records a capture (media stays on the device) and, with an Experience, marks it done so its pillar rises.
    func saveCapture(_ media: CapturedMedia, experienceId: UUID?) async throws {
        struct Row: Encodable {
            let experience_id: UUID?
            let kind: String
            let taken_at: Date
            let duration_seconds: Double?
            let device_media_id: String
        }
        try await supabase.from("captures").insert(Row(
            experience_id: experienceId, kind: media.kind.rawValue, taken_at: media.takenAt,
            duration_seconds: media.duration, device_media_id: media.url.lastPathComponent
        )).execute()
        if let experienceId, states[experienceId]?.isDone != true {
            try await send(Feedback(.done, on: experienceId))
        }
    }
}

