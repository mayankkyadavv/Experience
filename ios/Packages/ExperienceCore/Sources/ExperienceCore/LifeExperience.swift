import Foundation

// The personal Experience (ADR-013, brief §3-5): one object from want to memory. Mirrors the `experiences`
// table (migration 20261024000000_life_archive.sql); the catalog's rows are `Listing`s, not Experiences.

/// Where an Experience is in its life. The id never changes as it moves.
public enum ExperienceState: String, Codable, Sendable, CaseIterable {
    case want, planned
    case inProgress = "in_progress"
    case experienced, cancelled
}

/// Who may see it (brief §9). New things are always `.private`.
public enum Audience: String, Codable, Sendable, CaseIterable {
    case `private`, friends, `public`

    public var label: String {
        switch self {
        case .private: "Only you"
        case .friends: "Friends"
        case .public: "Public"
        }
    }
}

/// How precisely we know when it happened. Approximate stays approximate.
public enum TimePrecision: String, Codable, Sendable, CaseIterable {
    case exact, day, month, season, year, range, unknown
}

/// The brief's starting set (§13). Several can apply; they guide retrieval, they don't rank a life.
public enum LifeCategory: String, Codable, Sendable, CaseIterable {
    case food, nightlife, music
    case artsCulture = "arts_culture"
    case outdoors, travel, sports, learning, everyday, milestones

    public var label: String {
        switch self {
        case .food: "Food"
        case .nightlife: "Nightlife"
        case .music: "Music"
        case .artsCulture: "Art & Culture"
        case .outdoors: "Outdoors"
        case .travel: "Travel"
        case .sports: "Sports"
        case .learning: "Learning"
        case .everyday: "Everyday Life"
        case .milestones: "Milestones"
        }
    }
}

/// When it happened, in the timezone where it happened.
public struct ExperienceTime: Equatable, Sendable {
    public var start: Date?
    public var end: Date?
    public var precision: TimePrecision
    /// IANA zone where it happened; dates are shown there, not wherever the phone is now.
    public var timezone: String?

    public init(start: Date?, end: Date? = nil, precision: TimePrecision, timezone: String? = nil) {
        self.start = start
        self.end = end
        self.precision = start == nil ? .unknown : precision
        self.timezone = timezone
    }

    public static let unknown = ExperienceTime(start: nil, precision: .unknown)

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timezone.flatMap(TimeZone.init(identifier:)) ?? .current
        return c
    }

    /// The calendar year it belongs to (in its own timezone), or nil when undated.
    public var year: Int? { start.map { calendar.component(.year, from: $0) } }

    /// Honest, human: "Oct 18, 2026", "October 2026", "Summer 2021", "2019", "Jun 3 – 9, 2024", "Date unknown".
    /// `southern` flips the season names for places below the equator.
    public func label(southern: Bool = false, now: Date = Date()) -> String {
        guard let start else { return "Date unknown" }
        let cal = calendar
        func fmt(_ d: Date, _ style: Date.FormatStyle) -> String {
            var s = style
            s.timeZone = cal.timeZone
            return d.formatted(s)
        }
        switch precision {
        case .unknown:
            return "Date unknown"
        case .exact:
            let day = fmt(start, .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
            let from = fmt(start, .dateTime.hour().minute())
            guard let end else { return "\(day) · \(from)" }
            let sameDay = cal.isDate(start, inSameDayAs: end)
            let to = sameDay ? fmt(end, .dateTime.hour().minute()) : fmt(end, .dateTime.weekday(.abbreviated).hour().minute())
            return "\(day) · \(from)–\(to)"
        case .day:
            return fmt(start, .dateTime.month(.abbreviated).day().year())
        case .month:
            return fmt(start, .dateTime.month(.wide).year())
        case .season:
            return "\(Self.season(month: cal.component(.month, from: start), southern: southern)) \(cal.component(.year, from: start))"
        case .year:
            return "\(cal.component(.year, from: start))"
        case .range:
            guard let end else { return fmt(start, .dateTime.month(.abbreviated).day().year()) }
            let sameYear = cal.component(.year, from: start) == cal.component(.year, from: end)
            let sameMonth = sameYear && cal.component(.month, from: start) == cal.component(.month, from: end)
            if sameMonth {
                return "\(fmt(start, .dateTime.month(.abbreviated).day())) – \(cal.component(.day, from: end)), \(cal.component(.year, from: end))"
            }
            if sameYear {
                return "\(fmt(start, .dateTime.month(.abbreviated).day())) – \(fmt(end, .dateTime.month(.abbreviated).day().year()))"
            }
            return "\(fmt(start, .dateTime.month(.abbreviated).day().year())) – \(fmt(end, .dateTime.month(.abbreviated).day().year()))"
        }
    }

    /// A short label for cards: drops the year when it's this year ("Oct 18"), keeps approximate wording.
    public func shortLabel(southern: Bool = false, now: Date = Date()) -> String {
        guard let start else { return "Date unknown" }
        let cal = calendar
        let thisYear = cal.component(.year, from: start) == cal.component(.year, from: now)
        guard thisYear, precision == .day || precision == .exact else { return label(southern: southern, now: now) }
        var s = Date.FormatStyle.dateTime.month(.abbreviated).day()
        s.timeZone = cal.timeZone
        return start.formatted(s)
    }

    static func season(month: Int, southern: Bool) -> String {
        let north = switch month {
        case 12, 1, 2: "Winter"
        case 3, 4, 5: "Spring"
        case 6, 7, 8: "Summer"
        default: "Fall"
        }
        guard southern else { return north }
        return ["Winter": "Summer", "Summer": "Winter", "Spring": "Fall", "Fall": "Spring"][north]!
    }
}

/// One person's Experience across its whole life.
public struct Experience: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var ownerId: UUID
    public var saveId: UUID?
    public var state: ExperienceState
    public var isDraft: Bool
    public var archivedAt: Date?
    public var visibility: Audience
    public var title: String
    public var description: String?
    public var categories: [String]
    public var startsAt: Date?
    public var endsAt: Date?
    public var timePrecision: TimePrecision
    public var timezone: String?
    public var placeName: String?
    public var placeLocality: String?
    public var placeLat: Double?
    public var placeLng: Double?
    public var cityId: String?
    public var listingId: UUID?
    public var inspiredBy: UUID?
    public var completedAt: Date?
    public var coverMediaId: UUID?
    public var provenance: [String: Provenance]
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, state, visibility, title, description, categories, timezone, provenance
        case ownerId = "owner_id", saveId = "save_id", isDraft = "is_draft", archivedAt = "archived_at"
        case startsAt = "starts_at", endsAt = "ends_at", timePrecision = "time_precision"
        case placeName = "place_name", placeLocality = "place_locality", placeLat = "place_lat", placeLng = "place_lng"
        case cityId = "city_id", listingId = "listing_id", inspiredBy = "inspired_by", completedAt = "completed_at"
        case coverMediaId = "cover_media_id", createdAt = "created_at", updatedAt = "updated_at"
    }

    public init(id: UUID, ownerId: UUID, saveId: UUID?, state: ExperienceState, isDraft: Bool, archivedAt: Date?,
                visibility: Audience, title: String, description: String?, categories: [String], startsAt: Date?,
                endsAt: Date?, timePrecision: TimePrecision, timezone: String?, placeName: String?, placeLocality: String?,
                placeLat: Double?, placeLng: Double?, cityId: String?, listingId: UUID?, inspiredBy: UUID?,
                completedAt: Date?, coverMediaId: UUID?, provenance: [String: Provenance], createdAt: Date, updatedAt: Date) {
        self.id = id; self.ownerId = ownerId; self.saveId = saveId; self.state = state; self.isDraft = isDraft
        self.archivedAt = archivedAt; self.visibility = visibility; self.title = title; self.description = description
        self.categories = categories; self.startsAt = startsAt; self.endsAt = endsAt; self.timePrecision = timePrecision
        self.timezone = timezone; self.placeName = placeName; self.placeLocality = placeLocality; self.placeLat = placeLat
        self.placeLng = placeLng; self.cityId = cityId; self.listingId = listingId; self.inspiredBy = inspiredBy
        self.completedAt = completedAt; self.coverMediaId = coverMediaId; self.provenance = provenance
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    public var time: ExperienceTime {
        ExperienceTime(start: startsAt, end: endsAt, precision: timePrecision, timezone: timezone)
    }

    /// Field provenance; anything not recorded was written by the person.
    public func provenance(of field: String) -> Provenance { provenance[field] ?? .user }
    public var sourcedTitle: Sourced<String> { Sourced(title, provenance(of: "title")) }
    public var lifeCategories: [LifeCategory] { categories.compactMap(LifeCategory.init(rawValue:)) }
    public var isSouthern: Bool { (placeLat ?? 0) < 0 }

    /// Counted in "N Experiences" (brief §5): confirmed lived, not a draft, not archived.
    public var counts: Bool { state == .experienced && !isDraft && archivedAt == nil }
}

extension Collection where Element == Experience {
    /// The headline count: confirmed Experienced objects, once per id.
    public var experiencedCount: Int { Set(filter(\.counts).map(\.id)).count }
}

/// A group of Experiences the person made: a trip, a festival, a season, a person, a ritual.
/// It references Experiences; it never copies them. (Named to avoid Swift's `Collection`.)
public struct ExperienceCollection: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case trip, event, season, person, place, ritual, other
    }

    public var id: UUID
    public var ownerId: UUID
    public var title: String
    public var description: String?
    public var kind: Kind
    public var visibility: Audience
    public var coverMediaId: UUID?
    public var createdAt: Date

    public init(id: UUID, ownerId: UUID, title: String, description: String?, kind: Kind, visibility: Audience,
                coverMediaId: UUID?, createdAt: Date) {
        self.id = id; self.ownerId = ownerId; self.title = title; self.description = description; self.kind = kind
        self.visibility = visibility; self.coverMediaId = coverMediaId; self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, kind, visibility
        case ownerId = "owner_id", coverMediaId = "cover_media_id", createdAt = "created_at"
    }
}

/// Which Experiences sit in which collection, in the person's order.
public struct CollectionItem: Codable, Equatable, Sendable {
    public var collectionId: UUID
    public var experienceId: UUID
    public var position: Int

    enum CodingKeys: String, CodingKey {
        case position
        case collectionId = "collection_id", experienceId = "experience_id"
    }
}

/// A photo or video on an Experience. The original lives in private storage once uploaded;
/// until then it is on the phone (`deviceFile`).
public struct MediaAsset: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case photo, video }
    public enum Status: String, Codable, Sendable {
        case onDevice = "on_device", uploading, ready, failed
    }

    public var id: UUID
    public var experienceId: UUID
    public var clientId: UUID
    public var kind: Kind
    public var position: Int
    public var caption: String?
    public var altText: String?
    public var takenAt: Date?
    public var durationSeconds: Double?
    public var width: Int?
    public var height: Int?
    public var originalPath: String?
    public var thumbPath: String?
    public var deviceFile: String?
    public var status: Status

    enum CodingKeys: String, CodingKey {
        case id, kind, position, caption, width, height, status
        case experienceId = "experience_id", clientId = "client_id", altText = "alt_text", takenAt = "taken_at"
        case durationSeconds = "duration_seconds", originalPath = "original_path", thumbPath = "thumb_path"
        case deviceFile = "device_file"
    }

    public init(id: UUID, experienceId: UUID, clientId: UUID, kind: Kind, position: Int, caption: String?, altText: String?,
                takenAt: Date?, durationSeconds: Double?, width: Int?, height: Int?, originalPath: String?, thumbPath: String?,
                deviceFile: String?, status: Status) {
        self.id = id; self.experienceId = experienceId; self.clientId = clientId; self.kind = kind; self.position = position
        self.caption = caption; self.altText = altText; self.takenAt = takenAt; self.durationSeconds = durationSeconds
        self.width = width; self.height = height; self.originalPath = originalPath; self.thumbPath = thumbPath
        self.deviceFile = deviceFile; self.status = status
    }

    /// Width over height when known (cards keep their shape while media loads).
    public var aspect: Double? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
}
