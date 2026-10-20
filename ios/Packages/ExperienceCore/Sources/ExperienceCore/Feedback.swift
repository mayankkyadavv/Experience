import Foundation

/// Interested · Not interested · Save · Did it · Rating (MVP.md). Wire format matches `record_feedback`.
public struct Feedback: Encodable, Equatable, Sendable {
    public enum Action: String, Encodable, Sendable, CaseIterable {
        case save, unsave, interested
        case notInterested = "not_interested"
        case done, undone, rate
    }

    public var experienceId: UUID
    public var action: Action
    /// 1 not for me · 2 good · 3 loved. Only with `.rate`, after `.done`.
    public var rating: Int?
    /// Set when the feedback is on a recommendation, so "Did it" counts toward the north star.
    public var recommendationId: UUID?

    public init(_ action: Action, on experienceId: UUID, rating: Int? = nil, recommendationId: UUID? = nil) {
        self.experienceId = experienceId
        self.action = action
        self.rating = rating
        self.recommendationId = recommendationId
    }

    public static func rate(_ rating: Int, on experienceId: UUID) -> Feedback {
        Feedback(.rate, on: experienceId, rating: rating)
    }

    enum CodingKeys: String, CodingKey {
        case experienceId = "p_experience_id", action = "p_action", rating = "p_rating", recommendationId = "p_recommendation_id"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(experienceId, forKey: .experienceId)
        try c.encode(action, forKey: .action)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(recommendationId, forKey: .recommendationId)
    }
}

/// A row of `user_experiences`: what this user has done with one Experience.
public struct UserExperienceState: Decodable, Equatable, Sendable {
    public var experienceId: UUID
    public var savedAt: Date?
    public var interestedAt: Date?
    public var notInterestedAt: Date?
    public var doneAt: Date?
    public var rating: Int?
    public var fromRecommendation: UUID?

    public var isSaved: Bool { savedAt != nil }
    public var isDone: Bool { doneAt != nil }

    enum CodingKeys: String, CodingKey {
        case experienceId = "experience_id", savedAt = "saved_at", interestedAt = "interested_at"
        case notInterestedAt = "not_interested_at", doneAt = "done_at", rating, fromRecommendation = "from_recommendation"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        experienceId = try c.decode(UUID.self, forKey: .experienceId)
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        fromRecommendation = try c.decodeIfPresent(UUID.self, forKey: .fromRecommendation)
        func date(_ key: CodingKeys) throws -> Date? {
            guard let s = try c.decodeIfPresent(String.self, forKey: key) else { return nil }
            guard let d = Self.parse(s) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Bad timestamp \(s)")
            }
            return d
        }
        savedAt = try date(.savedAt)
        interestedAt = try date(.interestedAt)
        notInterestedAt = try date(.notInterestedAt)
        doneAt = try date(.doneAt)
    }

    /// Postgres timestamptz as PostgREST sends it: "2026-10-19T18:33:12.123456+00:00".
    static func parse(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
