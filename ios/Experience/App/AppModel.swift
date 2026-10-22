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
    /// What a visitor sees (brief §8). All optional; the You page invites filling them in.
    var displayName: String? = nil
    var username: String? = nil
    var bio: String? = nil
    /// A demo account (tools/demo/seed.ts). The app labels it "Sample profile" so it's never mistaken for a life.
    var isSample: Bool = false

    enum CodingKeys: String, CodingKey {
        case userId = "user_id", cityId = "city_id", onboarding, onboardedAt = "onboarded_at"
        case displayName = "display_name", username, bio, isSample = "is_sample"
    }

    init(userId: UUID, cityId: String?, onboarding: OnboardingAnswers, onboardedAt: Date? = nil) {
        self.userId = userId; self.cityId = cityId; self.onboarding = onboarding; self.onboardedAt = onboardedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(UUID.self, forKey: .userId)
        cityId = try c.decodeIfPresent(String.self, forKey: .cityId)
        onboarding = try c.decodeIfPresent(OnboardingAnswers.self, forKey: .onboarding) ?? .init()
        onboardedAt = try c.decodeIfPresent(Date.self, forKey: .onboardedAt)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        isSample = try c.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
    }

    /// Writes only the columns onboarding owns; `is_sample` is set by the demo tool, never by the app.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(cityId, forKey: .cityId)
        try c.encode(onboarding, forKey: .onboarding)
        try c.encode(onboardedAt, forKey: .onboardedAt)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(username, forKey: .username)
        try c.encode(bio, forKey: .bio)
    }
}

/// Why a profile edit was refused, in words for the person.
struct ProfileEditError: LocalizedError {
    let errorDescription: String?
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

    #if LOCAL_BACKEND
    /// Local Docker stack only: switch to the sample profile (tools/demo/seed.ts), and back to this install's account.
    func useSampleProfile() async {
        try? await supabase.auth.signOut()
        phase = .signedOut
        do {
            try await supabase.auth.signIn(email: "sample@experiences.local", password: "experiences-sample-profile")
            await loadProfile()
        } catch {
            authError = "No sample profile yet. Run `docker compose run --rm tools deno task demo`."
        }
    }

    func useMyAccount() async {
        try? await supabase.auth.signOut()
        phase = .signedOut
        await signInLocal()
    }

    var isUsingSampleProfile: Bool { profile?.isSample == true }
    #endif

    #if !LOCAL_BACKEND
    var isUsingSampleProfile: Bool { false }
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
            let listing_places: [Link]
        }
        let rows: [Row] = (try? await supabase.from("listings")
            .select("id, category, tags, listing_places(role, places(lat, lng))")
            .eq("city_id", value: cityId).eq("status", value: "published")
            .execute().value) ?? []
        pins[cityId] = rows.compactMap { r in
            guard let p = r.listing_places.first(where: { $0.role == "primary" })?.places, let lat = p.lat, let lng = p.lng else { return nil }
            return CatalogPin(id: r.id, category: r.category, tags: r.tags, lat: lat, lng: lng)
        }
    }

    /// Saves the city and answers; `skipped` keeps defaults but still needs a city.
    func finishOnboarding(cityId: String, answers: OnboardingAnswers) async throws {
        let userId = try await supabase.auth.session.user.id
        var updated = profile ?? Profile(userId: userId, cityId: nil, onboarding: .init())
        updated.cityId = cityId
        updated.onboarding = answers
        updated.onboardedAt = Date()
        try await supabase.from("profiles").upsert(updated).execute()
        profile = updated
        phase = .ready
    }

    // MARK: Profile basics

    /// Saves name, username and bio. Empty strings clear a field. The server checks the rules too (lengths, username shape).
    func updateProfile(displayName: String, username: String, bio: String) async throws {
        guard var updated = profile else { return }
        func clean(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        updated.displayName = clean(displayName)
        updated.username = clean(username)?.lowercased()
        updated.bio = clean(bio)
        struct Row: Encodable {
            let display_name: String?, username: String?, bio: String?
            // Send nulls explicitly so clearing a field clears it.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(display_name, forKey: .display_name)
                try c.encode(username, forKey: .username)
                try c.encode(bio, forKey: .bio)
            }
            enum CodingKeys: CodingKey { case display_name, username, bio }
        }
        do {
            try await supabase.from("profiles")
                .update(Row(display_name: updated.displayName, username: updated.username, bio: updated.bio))
                .eq("user_id", value: updated.userId)
                .execute()
        } catch let error as PostgrestError where error.code == "23505" {
            throw ProfileEditError(errorDescription: "That username is taken. Try another.")
        } catch {
            throw ProfileEditError(errorDescription: "Couldn't save. Check your connection and try again; your changes are still here.")
        }
        profile = updated
    }
}
