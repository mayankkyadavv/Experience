import Foundation

public protocol ExperienceAPI: Sendable {
    func recommend(_ constraints: RecommendationConstraints) async throws -> RecommendationResponse
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
        try await call("recommend", body: constraints)
    }

    func call<Body: Encodable, Response: Decodable>(_ function: String, body: Body) async throws -> Response {
        guard let token = try await accessToken() else { throw APIError.notSignedIn }
        var request = URLRequest(url: projectURL.appending(path: "functions/v1/\(function)"))
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
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError.server(status: http.statusCode, message: message ?? "Something went wrong on our side. Try again in a moment.")
        }
    }
}
