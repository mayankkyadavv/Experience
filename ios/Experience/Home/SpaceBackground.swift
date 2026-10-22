import SwiftUI

// MARK: - Space

/// Near-black with faint seeded stars. Drawn once; three star layers breathe at different rates
/// (opacity animations run in Core Animation, so the stars cost nothing per frame).
struct SpaceBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    /// The black of space (#030308), also used where content fades into it.
    static let color = Color(red: 0.012, green: 0.012, blue: 0.03)

    private static let stars: [(x: Double, y: Double, r: Double, layer: Int)] = {
        var g = SeededGenerator(seed: 7)
        return (0..<160).map { i in (Double.random(in: 0...1, using: &g), Double.random(in: 0...1, using: &g), Double.random(in: 0.35...1.2, using: &g), i % 3) }
    }()

    var body: some View {
        ZStack {
            Self.color
            ForEach(0..<3, id: \.self) { layer in
                Canvas { ctx, size in
                    for s in Self.stars where s.layer == layer {
                        let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: s.r * 2, height: s.r * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55)))
                    }
                }
                .opacity(reduceMotion ? 0.8 : (breathe ? 1 : 0.35))
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.4 + Double(layer) * 1.3).repeatForever().delay(Double(layer) * 0.7), value: breathe)
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear { breathe = true }
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
