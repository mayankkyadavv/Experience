import ExperienceCore
import MapLibre
import Observation
import UIKit

/// A colored hexagonal prism on the map (DESIGN.md "Map marks"): a pick beacon, a taste preview, or a pillar.
struct MapMark: Equatable, Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let group: CategoryGroup
    /// Target height in meters; the map springs toward it.
    var height: Double = 110
    var radius: Double = 34

    static func == (a: MapMark, b: MapMark) -> Bool {
        a.id == b.id && a.group == b.group && a.height == b.height && a.radius == b.radius
            && a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
    }
}

/// The one city map behind every screen. Screens describe what the camera should show; the map animates there.
@MainActor @Observable
final class MapScene {
    enum Shot: Equatable {
        /// Flat, top-down, zoomed out: buildings are below their rise threshold.
        case intro
        /// The city in 3D, orbiting.
        case city
        /// Fit every mark (taste preview, results overview).
        case marks
        /// Close on one mark.
        case focus(UUID)
    }

    var center = CLLocationCoordinate2D(latitude: 39.9524, longitude: -75.1636)
    var shot: Shot = .intro
    var marks: [MapMark] = []
    /// Saved Experiences: flat category dots with a white ring (DESIGN.md), shown on every screen.
    var dots: [MapMark] = []
    var orbit = true
    /// Space covered by bottom panels; the camera frames content above it.
    var bottomInset: CGFloat = 0
    /// Seconds for the next camera move (0 = cut).
    var flight: TimeInterval = 1.2
    /// Show the blue "you are here" dot (only once location is authorized).
    var showsUser = false
    /// The mark the user tapped last (screens react with `onChange`).
    var tapped: UUID?

    /// Set by the map once its style (and buildings) are ready.
    private(set) var ready = false

    func markReady() { ready = true }
}
