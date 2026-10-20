import ExperienceCore
import SwiftUI
import UIKit

/// DESIGN.md tokens. White and ink carry the chrome; the six category hues are the only color.
enum Theme {
    static let surface = dynamic(0xFFFFFF, 0x0B0B0C)
    static let raised = dynamic(0xFFFFFF, 0x161618)
    static let soft = dynamic(0xF4F4F2, 0x1F1F22)
    static let text = dynamic(0x0A0A0B, 0xF5F5F4)
    static let textMuted = dynamic(0x6A6E75, 0x9A9EA6)
    static let hairline = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.10) : UIColor(rgb: 0x0A0A0B, alpha: 0.08) })
    /// Primary buttons: ink on light, white on dark.
    static let primary = dynamic(0x0A0A0B, 0xF5F5F4)
    static let onPrimary = dynamic(0xFFFFFF, 0x0A0A0B)
    static let success = Color(uiColor: UIColor(rgb: 0x1FAF5B))
    static let error = Color(uiColor: UIColor(rgb: 0xE5383B))

    enum Radius {
        static let chip: CGFloat = 8, control: CGFloat = 13, button: CGFloat = 16, card: CGFloat = 28, sheet: CGFloat = 34
    }

    enum Space {
        static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 12, lg: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32
    }

    enum Motion {
        static let micro = Animation.spring(duration: 0.2, bounce: 0)
        static let short = Animation.spring(duration: 0.4, bounce: 0)
        static let medium = Animation.spring(duration: 0.7, bounce: 0)
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension CategoryGroup {
    /// Identical in light and dark mode (DESIGN.md).
    var uiColor: UIColor { UIColor(rgb: hex) }
    var color: Color { Color(uiColor: uiColor) }
}

// MARK: - Type

extension Font {
    /// Bricolage Grotesque 800, the voice (DESIGN.md). Scales with Dynamic Type relative to `style`.
    static func display(_ size: CGFloat = 30, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("BricolageGrotesque-96ptExtraBold_ExtraBold", size: size, relativeTo: style)
    }

    static func title(_ size: CGFloat = 21) -> Font { display(size, relativeTo: .title2) }

    /// SF Mono uppercase metadata ("DID IT · FRIDAY NIGHT"). Apply `.textCase(.uppercase)` and `.tracking(0.66)`.
    static let mono = Font.system(.caption2, design: .monospaced).weight(.medium)
}

extension View {
    /// Display tracking: -0.04em.
    func displayTracking(_ size: CGFloat = 30) -> some View { tracking(-0.04 * size) }

    func monoLabel() -> some View {
        font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Theme.textMuted)
    }

    /// `lift`: sheets and cards. Shadows always have a y-offset.
    func lift() -> some View { shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 12) }
    func liftSmall() -> some View { shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2) }
}
