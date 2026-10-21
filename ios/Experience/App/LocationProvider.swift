import CoreLocation
import ExperienceCore
import Observation

/// When-in-use location, asked for in context (the first "Find 3 things"). Precise location stays on the device
/// except for the coordinate sent with a recommendation request (MVP.md privacy).
@MainActor @Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLLocation?, Never>] = []

    private(set) var status: CLAuthorizationStatus
    private(set) var last: CLLocation?

    var isAuthorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if isAuthorized { manager.startUpdatingLocation() }
    }

    /// A recent fix, asking permission the first time. Returns nil (never blocks long) when denied or slow.
    func current(maxAge: TimeInterval = 300) async -> CLLocation? {
        if let last, -last.timestamp.timeIntervalSinceNow < maxAge { return last }
        switch status {
        case .denied, .restricted: return nil
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: manager.startUpdatingLocation()
        }
        // Registered synchronously on the main actor, so a fix that lands right away can't be missed.
        return await withCheckedContinuation { c in
            waiters.append(c)
            Task {
                try? await Task.sleep(for: .seconds(6))
                resolve(last) // give up waiting; use whatever we have
            }
        }
    }

    var coordinate: Coordinate? { last.map { Coordinate(lat: $0.coordinate.latitude, lng: $0.coordinate.longitude) } }

    /// The same rough door-to-door estimate the recommender uses (walk under 1.2 km, otherwise drive/transit).
    func travelMinutes(to lat: Double, _ lng: Double) -> Int? {
        guard let last else { return nil }
        let km = last.distance(from: CLLocation(latitude: lat, longitude: lng)) / 1000
        return Int((km < 1.2 ? km / 5 * 60 : 6 + km / 20 * 60).rounded())
    }

    private func resolve(_ location: CLLocation?) {
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(returning: location) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            status = manager.authorizationStatus
            if isAuthorized { manager.startUpdatingLocation() } else if status != .notDetermined { resolve(nil) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            last = locations.last
            resolve(last)
            // One good fix is enough; keep the radio off until the next ask.
            if let accuracy = last?.horizontalAccuracy, accuracy >= 0, accuracy < 500 { manager.stopUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // "Location unknown" is temporary; the timeout in `current()` covers real failures.
        if (error as? CLError)?.code == .denied { Task { @MainActor in resolve(nil) } }
    }
}
