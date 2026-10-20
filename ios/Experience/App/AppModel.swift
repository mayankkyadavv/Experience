import ExperienceCore
import Foundation
import Observation
import Supabase

struct City: Codable, Identifiable, Equatable {
    enum Status: String, Codable { case coming, beta, live }
    let id: String
    let name: String
    let status: Status
    let timezone: String
    let centerLat: Double
    let centerLng: Double

    enum CodingKeys: String, CodingKey { case id, name, status, timezone, centerLat = "center_lat", centerLng = "center_lng" }
}

/// `profiles.onboarding`: seeds the taste profile (MVP.md). Every answer is optional.
struct OnboardingAnswers: Codable, Equatable {
    var likes: [String] = []
    /// Dollars per person as a string ("0", "25", "50", "100"); nil = no preference.
    var budget: String?
    var usuallyWith: String?

    enum CodingKeys: String, CodingKey { case likes, budget, usuallyWith = "usually_with" }
}

/// A published catalog Experience with a place, for lighting up the map (onboarding preview).
struct CatalogPin: Identifiable, Equatable {
    let id: UUID
    let category: ExperienceCategory
    let tags: [String]
    let lat: Double
    let lng: Double
}

struct Profile: Codable, Equatable {
    let userId: UUID
    var cityId: String?
    var onboarding: OnboardingAnswers
    var onboardedAt: Date?

    enum CodingKeys: String, CodingKey { case userId = "user_id", cityId = "city_id", onboarding, onboardedAt = "onboarded_at" }
}

@MainActor @Observable
final class AppModel {
    enum Phase: Equatable { case launching, signedOut, onboarding, ready }

    private(set) var phase: Phase = .launching
    private(set) var profile: Profile?
    private(set) var cities: [City] = []
    private(set) var pins: [String: [CatalogPin]] = [:]
    var catalog: [String: [CatalogItem]] = [:]
    var catalogError: String?
    /// The signed-in user's saved / interested / done state per Experience.
    var states: [UUID: UserExperienceState] = [:]
    var authError: String?

    let supabase: SupabaseClient
    let api: ExperienceAPI

    var city: City? { cities.first { $0.id == profile?.cityId } }

    init() {
        let url = URL(string: Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? "")!
        let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""
        let supabase = SupabaseClient(supabaseURL: url, supabaseKey: key)
        self.supabase = supabase
        // Only the app refreshes tokens (R4); `session` refreshes when it has expired.
        api = SupabaseFunctionsClient(projectURL: url, anonKey: key) {
            try? await supabase.auth.session.accessToken
        }
    }

    func start() async {
        #if LOCAL_BACKEND
        // UI tests launch with -freshStart to begin signed out with a new local account.
        if ProcessInfo.processInfo.arguments.contains("-freshStart") {
            try? await supabase.auth.signOut()
            UserDefaults.standard.removeObject(forKey: "localEmail")
            UserDefaults.standard.removeObject(forKey: "localPassword")
        }
        #endif
        guard (try? await supabase.auth.session) != nil else {
            phase = .signedOut
            return
        }
        await loadProfile()
    }

    // MARK: Sign in

    func signInWithApple(idToken: String, nonce: String) async {
        do {
            try await supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
            await loadProfile()
        } catch {
            authError = "Sign in didn't finish. Try again."
        }
    }

    #if LOCAL_BACKEND
    /// Local Docker stack only: one email/password account per install (GoTrue auto-confirms).
    func signInLocal() async {
        let defaults = UserDefaults.standard
        let email = defaults.string(forKey: "localEmail") ?? "dev-\(UUID().uuidString.prefix(8).lowercased())@local.test"
        let password = defaults.string(forKey: "localPassword") ?? UUID().uuidString
        do {
            if defaults.string(forKey: "localEmail") == nil {
                try await supabase.auth.signUp(email: email, password: password)
                defaults.set(email, forKey: "localEmail")
                defaults.set(password, forKey: "localPassword")
            } else {
                try await supabase.auth.signIn(email: email, password: password)
            }
            await loadProfile()
        } catch {
            authError = "Couldn't reach the local backend. Is `docker compose up -d` running?"
        }
    }
    #endif

    func signOut() async {
        try? await supabase.auth.signOut()
        profile = nil
        phase = .signedOut
    }

    // MARK: Profile

    private func loadProfile() async {
        do {
            async let cities: [City] = supabase.from("cities").select("id, name, status, timezone, center_lat, center_lng").order("status", ascending: false).execute().value
            let userId = try await supabase.auth.session.user.id
            let rows: [Profile] = try await supabase.from("profiles").select().eq("user_id", value: userId).execute().value
            self.cities = try await cities
            profile = rows.first ?? Profile(userId: userId, cityId: nil, onboarding: .init())
            phase = profile?.cityId == nil ? .onboarding : .ready
        } catch {
            authError = "Couldn't load your profile. Check your connection and try again."
            phase = .signedOut
        }
    }

    /// Published catalog Experiences with coordinates in a city (RLS: readable when signed in).
    func loadPins(cityId: String) async {
        guard pins[cityId] == nil else { return }
        struct Row: Decodable {
            struct Link: Decodable { struct P: Decodable { let lat: Double?; let lng: Double? }; let role: String; let places: P? }
            let id: UUID
            let category: ExperienceCategory
            let tags: [String]
            let experience_places: [Link]
        }
        let rows: [Row] = (try? await supabase.from("experiences")
            .select("id, category, tags, experience_places(role, places(lat, lng))")
            .eq("city_id", value: cityId).eq("status", value: "published")
            .execute().value) ?? []
        pins[cityId] = rows.compactMap { r in
            guard let p = r.experience_places.first(where: { $0.role == "primary" })?.places, let lat = p.lat, let lng = p.lng else { return nil }
            return CatalogPin(id: r.id, category: r.category, tags: r.tags, lat: lat, lng: lng)
        }
    }

    /// Saves the city and answers; `skipped` keeps defaults but still needs a city.
    func finishOnboarding(cityId: String, answers: OnboardingAnswers) async throws {
        let userId = try await supabase.auth.session.user.id
        let updated = Profile(userId: userId, cityId: cityId, onboarding: answers, onboardedAt: Date())
        try await supabase.from("profiles").upsert(updated).execute()
        profile = updated
        phase = .ready
    }
}
