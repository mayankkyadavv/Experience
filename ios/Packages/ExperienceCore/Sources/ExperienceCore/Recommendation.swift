import Foundation

/// The "What should we do?" inputs. Wire format matches `supabase/functions/recommend/index.ts`.
public struct RecommendationConstraints: Equatable, Sendable {
    public enum When: String, Codable, Sendable, CaseIterable { case now, tonight, tomorrow, weekend }
    public enum Who: String, Codable, Sendable, CaseIterable { case solo, date, friends, group, family }
    public enum Mood: String, Codable, Sendable, CaseIterable {
        case chill, active, food, creative, nightlife, outdoors
        case somethingNew = "something_new"
        case surprise
    }

    public var when: When
    public var hours: Double
    /// Dollars per person. `0` = free only, `nil` = no preference.
    public var budget: Int?
    public var who: Who
    public var groupSize: Int?
    public var mood: Mood?
    public var location: Coordinate?

    public init(when: When, hours: Double, budget: Int?, who: Who, groupSize: Int? = nil, mood: Mood? = nil, location: Coordinate? = nil) {
        self.when = when
        self.hours = hours
        self.budget = budget
        self.who = who
        self.groupSize = groupSize
        self.mood = mood
        self.location = location
    }
}

extension RecommendationConstraints: Encodable {
    enum CodingKeys: String, CodingKey { case when, hours, budget, who, groupSize, mood, location }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(when, forKey: .when)
        try c.encode(hours, forKey: .hours)
        try c.encode(budget, forKey: .budget) // explicit null = "no preference"; the server requires the key
        try c.encode(who, forKey: .who)
        try c.encodeIfPresent(groupSize, forKey: .groupSize)
        try c.encodeIfPresent(mood, forKey: .mood)
        try c.encodeIfPresent(location, forKey: .location)
    }
}

public struct Coordinate: Codable, Equatable, Sendable {
    public var lat: Double
    public var lng: Double
    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

public struct RecommendationResponse: Decodable, Equatable, Sendable {
    public var requestId: UUID?
    public var picks: [Pick]
}

public struct Pick: Decodable, Equatable, Sendable, Identifiable {
    public var experience: PickedExperience
    public var score: Double
    /// Built only from data we hold ("You saved this on Sep 12"); safe to show as is.
    public var reasons: [String]
    public var facts: Facts

    public var id: UUID { experience.id }

    public struct Facts: Decodable, Equatable, Sendable {
        public var price: String?
        public var duration: String?
        /// A rough door-to-door estimate; render as "~N min".
        public var travelMinutes: Int?
        public var openUntil: String?
    }
}

public struct PickedExperience: Decodable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var category: ExperienceCategory
    public var imageUrl: URL?
    public var provenance: [String: Provenance]
    public var place: Place?

    public struct Place: Decodable, Equatable, Sendable {
        public var name: String
        public var neighborhood: String?
        public var lat: Double?
        public var lng: Double?
    }

    /// Catalog fields default to `curated` when the provenance map doesn't name them (ADR-009).
    public func sourced(_ field: String, _ value: String) -> Sourced<String> {
        Sourced(value, provenance[field] ?? .curated)
    }

    public var sourcedTitle: Sourced<String> { sourced("title", title) }
}
