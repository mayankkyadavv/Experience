import Foundation
import Testing
@testable import ExperienceCore

@Suite struct ProvenanceTests {
    @Test func estimatesAreLabelled() {
        #expect(Sourced("Restaurant", .estimated).display == "Restaurant (estimated)")
    }

    @Test(arguments: [Provenance.source, .lookup, .user, .curated])
    func otherProvenancesAreShownAsIs(_ p: Provenance) {
        #expect(Sourced("Joe's Pizza", p).display == "Joe's Pizza")
        #expect(!Sourced("Joe's Pizza", p).needsEstimateLabel)
    }
}

@Suite struct CategoryTests {
    /// The Swift enum must match the Postgres enum, or decoding a pick would fail at runtime.
    @Test func matchesTheDatabaseEnum() throws {
        let migrations = URL(filePath: #filePath)
            .deletingLastPathComponent().appending(path: "../../../../../supabase/migrations").standardized
        let files = try FileManager.default.contentsOfDirectory(at: migrations, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "sql" }
        let sql = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        let start = try #require(sql.range(of: "create type experience_category as enum ("))
        let end = try #require(sql[start.upperBound...].range(of: ");"))
        let values = sql[start.upperBound..<end.lowerBound]
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
        #expect(values == ExperienceCategory.allCases.map(\.rawValue))
    }

    @Test func groupsMatchTheDesignColors() {
        #expect(ExperienceCategory.comedy.group == .nightlife)
        #expect(ExperienceCategory.class.group == .activity)
        #expect(CategoryGroup.food.hex == 0xFF5A36)
        #expect(Set(ExperienceCategory.allCases.map(\.group)) == Set(CategoryGroup.allCases))
    }
}

@Suite struct WireFormatTests {
    @Test func constraintsAlwaysSendBudgetEvenWhenNil() throws {
        let c = RecommendationConstraints(when: .tonight, hours: 5, budget: nil, who: .group, groupSize: 4, mood: .somethingNew)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(c)) as? [String: Any])
        #expect(json["budget"] is NSNull)
        #expect(json["when"] as? String == "tonight")
        #expect(json["mood"] as? String == "something_new")
        #expect(json["groupSize"] as? Int == 4)
        #expect(json["location"] == nil)
    }

    @Test func decodesTheRecommendResponse() throws {
        let url = try #require(Bundle.module.url(forResource: "recommend-response", withExtension: "json", subdirectory: "Fixtures"))
        let response = try JSONDecoder().decode(RecommendationResponse.self, from: Data(contentsOf: url))
        #expect(response.picks.count == 2)
        let first = response.picks[0]
        #expect(first.experience.category == .attraction)
        #expect(first.facts.travelMinutes == 12)
        #expect(first.reasons.first == "You saved this on Sep 12")
        #expect(first.experience.sourced("price", "$45").provenance == .curated)
        #expect(first.experience.provenance["price_min_cents"] == .estimated)
        #expect(response.picks[1].experience.place == nil)
        #expect(response.picks[1].experience.sourcedTitle.display == "Stand-up comedy at Punch Line Philly")
    }
}

// MARK: - Client

final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map { stream in
            stream.open()
            defer { stream.close() }
            var data = Data()
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buf.deallocate() }
            while stream.hasBytesAvailable { let n = stream.read(buf, maxLength: 4096); if n <= 0 { break }; data.append(buf, count: n) }
            return data
        }
        let (status, data) = Self.handler!(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct ClientTests {
    func client(token: String? = "user-jwt") -> SupabaseFunctionsClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return SupabaseFunctionsClient(projectURL: URL(string: "https://abc.supabase.co")!, anonKey: "anon", session: URLSession(configuration: config)) { token }
    }
    let constraints = RecommendationConstraints(when: .tonight, hours: 5, budget: 75, who: .friends)

    @Test func sendsAnAuthenticatedPost() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"requestId":null,"picks":[]}"#.utf8)) }
        let response = try await client().recommend(constraints)
        #expect(response.picks.isEmpty)
        let req = try #require(StubProtocol.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString == "https://abc.supabase.co/functions/v1/recommend")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer user-jwt")
        #expect(req.value(forHTTPHeaderField: "apikey") == "anon")
        let sent = try #require(StubProtocol.lastBody)
        let body = try #require(JSONSerialization.jsonObject(with: sent) as? [String: Any])
        #expect(body["budget"] as? Int == 75)
    }

    @Test func surfacesTheServerMessage() async {
        StubProtocol.handler = { _ in (409, Data(#"{"error":"Pick a city first"}"#.utf8)) }
        await #expect(throws: APIError.server(status: 409, message: "Pick a city first")) { try await client().recommend(constraints) }
    }

    @Test func noTokenMeansSignedOut() async {
        StubProtocol.handler = { _ in (200, Data()) }
        await #expect(throws: APIError.notSignedIn) { try await client(token: nil).recommend(constraints) }
    }

    @Test func garbageIsABadResponse() async {
        StubProtocol.handler = { _ in (200, Data("not json".utf8)) }
        await #expect(throws: APIError.badResponse) { try await client().recommend(constraints) }
    }
}

/// Feedback calls share ClientTests' serialized stub.
extension ClientTests {
    var id: UUID { UUID(uuidString: "5a5a5a5a-0000-4000-8000-000000000001")! }

    @Test func postsToTheRPCWithPostgresArgumentNames() async throws {
        StubProtocol.handler = { _ in
            (200, Data(#"{"user_id":"00000000-0000-0000-0000-00000000000a","experience_id":"5a5a5a5a-0000-4000-8000-000000000001","saved_at":null,"interested_at":null,"not_interested_at":null,"done_at":"2026-10-19T18:33:12.123456+00:00","rating":3,"from_recommendation":null,"updated_at":"2026-10-19T18:33:12+00:00"}"#.utf8))
        }
        let state = try await client().feedback(.rate(3, on: id))
        #expect(state.rating == 3)
        #expect(state.isDone)
        #expect(!state.isSaved)
        let req = try #require(StubProtocol.lastRequest)
        #expect(req.url?.absoluteString == "https://abc.supabase.co/rest/v1/rpc/record_feedback")
        let sent = try #require(StubProtocol.lastBody)
        let body = try #require(JSONSerialization.jsonObject(with: sent) as? [String: Any])
        #expect(body["p_action"] as? String == "rate")
        #expect(body["p_rating"] as? Int == 3)
        #expect(body["p_experience_id"] as? String == id.uuidString)
        #expect(body["p_recommendation_id"] == nil)
    }

    @Test func surfacesPostgRESTErrorMessages() async {
        StubProtocol.handler = { _ in (400, Data(#"{"code":"22023","message":"Mark it done before rating it","details":null,"hint":null}"#.utf8)) }
        await #expect(throws: APIError.server(status: 400, message: "Mark it done before rating it")) {
            try await client().feedback(.rate(3, on: id))
        }
    }

    @Test func feedbackActionsMatchTheDatabase() throws {
        let sql = try String(contentsOf: URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../../supabase/migrations/20261020000000_feedback.sql").standardized, encoding: .utf8)
        for action in Feedback.Action.allCases {
            #expect(sql.contains("'\(action.rawValue)'"), "\(action.rawValue) missing from record_feedback")
        }
    }
}
