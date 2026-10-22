import SwiftUI

/// Light or dark, chosen on the You page. System follows the iPhone.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The two light backgrounds under comparison. Temporary: the founder picks one, then the other is deleted.
enum LightBackdrop: String, CaseIterable, Identifiable {
    case atlas, gallery
    var id: String { rawValue }
    var label: String { self == .atlas ? "Atlas" : "Gallery" }
}

/// Behind every home page: space at night; by day, a paper atlas or a gallery wall.
struct HomeBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage("lightBackdrop") private var light: LightBackdrop = .atlas

    var body: some View {
        if scheme == .dark {
            SpaceBackground()
        } else {
            switch light {
            case .atlas: AtlasBackground()
            case .gallery: GalleryBackground()
            }
        }
    }

    /// The flat color content fades into (under the island).
    static func base(_ scheme: ColorScheme, _ light: LightBackdrop) -> Color {
        if scheme == .dark { return SpaceBackground.color }
        return light == .atlas ? AtlasBackground.paper : GalleryBackground.bottom
    }
}

/// Warm paper with the faint graticule of a much larger globe behind yours, like the endpapers of an old atlas.
/// The grid tilts the way the earth does, so the lines seem to belong to it. Drawn once.
struct AtlasBackground: View {
    static let paper = Color(red: 0.965, green: 0.957, blue: 0.937) // #F6F4EF
    private static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)

    var body: some View {
        ZStack {
            Self.paper
            RadialGradient(colors: [.white.opacity(0.7), .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 420)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let r = size.height * 0.62
                let tilt = 0.38
                // Orthographic projection of the sphere tilted toward the viewer; only the facing side is drawn.
                func project(_ lat: Double, _ lng: Double) -> (CGPoint, Bool) {
                    let φ = lat * .pi / 180, λ = lng * .pi / 180
                    let x = cos(φ) * sin(λ), y = sin(φ), z = cos(φ) * cos(λ)
                    let y2 = y * cos(tilt) - z * sin(tilt), z2 = y * sin(tilt) + z * cos(tilt)
                    return (CGPoint(x: c.x + r * x, y: c.y - r * y2), z2 > 0)
                }
                func line(_ points: [(Double, Double)]) -> Path {
                    var path = Path(), drawing = false
                    for (lat, lng) in points {
                        let (p, visible) = project(lat, lng)
                        if visible { drawing ? path.addLine(to: p) : path.move(to: p); drawing = true } else { drawing = false }
                    }
                    return path
                }
                var grid = Path()
                for lng in stride(from: -180.0, to: 180, by: 15) {
                    grid.addPath(line(stride(from: -90.0, through: 90, by: 2).map { ($0, lng) }))
                }
                for lat in stride(from: -75.0, through: 75, by: 15) {
                    grid.addPath(line(stride(from: -180.0, through: 180, by: 2).map { (lat, $0) }))
                }
                ctx.stroke(grid, with: .color(Self.ink.opacity(0.07)), lineWidth: 0.6)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Self.ink.opacity(0.09)), lineWidth: 0.8)
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A gallery wall: white, a breath of warmth toward the floor, nothing else. The earth is the exhibit.
struct GalleryBackground: View {
    static let bottom = Color(red: 0.955, green: 0.952, blue: 0.945)

    var body: some View {
        LinearGradient(colors: [.white, Self.bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
