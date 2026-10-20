import Foundation

public protocol ExperienceAPI: Sendable {
    func recommend(_ constraints: RecommendationConstraints) async throws -> RecommendationResponse
    func feedback(_ feedback: Feedback) async throws -> UserExperienceState
}

public enum APIError: Error, Equatable, LocalizedError {
    case notSignedIn
    /// The server's own message, e.g. "Pick a city first".
    case server(status: Int, message: String)
    case badResponse

    public var errorDescription: String? {
        switch self {
        case .notSignedIn: "You're signed out. Sign in again to continue."
        case .server(_, let message): message
        case .badResponse: "Something went wrong on our side. Try again in a moment."
        }
    }
}

/// Calls Supabase Edge Functions with the user's access token (ADR-002).
public struct SupabaseFunctionsClient: ExperienceAPI {
    public typealias TokenProvider = @Sendable () async throws -> String?

    let projectURL: URL
    let anonKey: String
    let accessToken: TokenProvider
    let session: URLSession

    public init(projectURL: URL, anonKey: String, session: URLSession = .shared, accessToken: @escaping TokenProvider) {
        self.projectURL = projectURL
        self.anonKey = anonKey
        self.session = session
        self.accessToken = accessToken
    }

    public func recommend(_ constraints: RecommendationConstraints) async throws -> RecommendationResponse {
        try await call("functions/v1/recommend", body: constraints)
    }

    /// `record_feedback` in `supabase/migrations` (one call updates the state and logs the event).
    public func feedback(_ feedback: Feedback) async throws -> UserExperienceState {
        try await call("rest/v1/rpc/record_feedback", body: feedback)
    }

    func call<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        guard let token = try await accessToken() else { throw APIError.notSignedIn }
        var request = URLRequest(url: projectURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        switch http.statusCode {
        case 200..<300:
            do { return try JSONDecoder().decode(Response.self, from: data) } catch { throw APIError.badResponse }
        case 401:
            throw APIError.notSignedIn
        default:
            // Edge Functions send {"error": ...}; PostgREST sends {"message": ...}.
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = (body?["error"] as? String) ?? (body?["message"] as? String)
            throw APIError.server(status: http.statusCode, message: message ?? "Something went wrong on our side. Try again in a moment.")
        }
    }
}
