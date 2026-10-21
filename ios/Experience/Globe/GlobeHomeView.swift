import ExperienceCore
import SwiftUI

/// Home: your world. A colorful earth spinning in black space, your places glowing on it,
/// and a calm, finite look at your life below (brief §7: Recently · Want to Experience).
struct GlobeHomeView: View {
    let onOpenCity: () -> Void
    let onCapture: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Temporary: the founder compares both earths, then the loser is deleted.
    @AppStorage("globeStyle") private var style: GlobeStyle = .dots
    @State private var globe = GlobeController()
    @State private var shown = false
    @State private var detail: UUID?
    @State private var diving = false

    private var done: [(CatalogItem, UserExperienceState)] {
        model.cityCatalog.compactMap { item in model.states[item.id].flatMap { $0.isDone ? (item, $0) : nil } }
            .sorted { ($0.1.doneAt ?? .distantPast) > ($1.1.doneAt ?? .distantPast) }
    }

    private var wants: [(CatalogItem, UserExperienceState)] {
        model.cityCatalog.compactMap { item in model.states[item.id].flatMap { $0.isSaved && !$0.isDone ? (item, $0) : nil } }
            .sorted { ($0.1.savedAt ?? .distantPast) > ($1.1.savedAt ?? .distantPast) }
    }

    /// One beacon per city at world scale; it takes the color of the last thing you did there.
    private var beacons: [GlobeBeacon] {
        guard let city = model.city else { return [] }
        let color = done.first?.0.category.group.uiColor ?? UIColor(rgb: 0xFFB300)
        return [GlobeBeacon(id: city.id, lat: city.centerLat, lng: city.centerLng, color: color)]
    }

    var body: some View {
        ZStack {
            SpaceBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, Theme.Space.sm)
                GeometryReader { geo in
                    GlobeView(style: style, beacons: beacons, controller: globe, reduceMotion: reduceMotion) { _ in openCity() }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(shown ? 1 : 0.86)
                        .opacity(shown ? 1 : 0)
                        .accessibilityElement()
                        .accessibilityLabel("Your world. \(model.city.map { "\($0.name) is lit." } ?? "")")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { openCity() }
                }
                .overlay(alignment: .bottom) { stylePicker.padding(.bottom, Theme.Space.sm) }
                LifeSheet(done: done, wants: wants, cityName: model.city?.name, onOpen: { detail = $0 }, onCity: openCity, onCapture: onCapture)
                    .offset(y: shown ? 0 : 60)
                    .opacity(shown ? 1 : 0)
            }
            .opacity(diving ? 0 : 1)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            globe.release()
            diving = false
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 1.1, bounce: 0)) { shown = true }
        }
        .sheet(item: Binding(get: { detail.map(DetailID.init) }, set: { detail = $0?.id })) { target in
            ExperienceDetailView(id: target.id)
                .environment(\.colorScheme, .light)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(Theme.Radius.sheet)
                .presentationDragIndicator(.visible)
        }
    }

    private struct DetailID: Identifiable { let id: UUID }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Experiences")
                .font(.display(38))
                .displayTracking(38)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.mono)
                .textCase(.uppercase)
                .tracking(0.66)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Sign out", role: .destructive) { Task { await model.signOut() } }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Account")
            .padding(.trailing, Theme.Space.sm)
        }
    }

    private var subtitle: String {
        let date = Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        let count = done.count
        let life = count == 0 ? nil : "\(count) Experience\(count == 1 ? "" : "s")"
        return [date, life].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Style comparison (temporary)

    private var stylePicker: some View {
        HStack(spacing: 2) {
            ForEach(GlobeStyle.allCases) { s in
                Button {
                    withAnimation(Theme.Motion.micro) { style = s }
                } label: {
                    Text(s.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style == s ? .black : .white.opacity(0.75))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 30)
                        .background(style == s ? Color.white : .clear, in: .capsule)
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(style == s ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.white.opacity(0.10), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .accessibilityLabel("Earth style")
    }

    // MARK: Dive

    /// The earth turns your city to face you and rushes closer; then the city takes over.
    private func openCity() {
        guard let city = model.city, !diving else { return }
        globe.focus(lat: city.centerLat, lng: city.centerLng, zoom: true)
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.75))
            withAnimation(.easeIn(duration: reduceMotion ? 0.15 : 0.3)) { diving = true }
            try? await Task.sleep(for: .seconds(0.2))
            onOpenCity()
        }
    }
}

// MARK: - Life sheet

/// The finite overview under the globe. Sections disappear when empty; nothing is invented.
private struct LifeSheet: View {
    let done: [(CatalogItem, UserExperienceState)]
    let wants: [(CatalogItem, UserExperienceState)]
    let cityName: String?
    let onOpen: (UUID) -> Void
    let onCity: () -> Void
    let onCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            if done.isEmpty && wants.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start with something you want to remember.")
                        .font(.title(22))
                        .displayTracking(22)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Capture a moment, or find something to do\(cityName.map { " in \($0)" } ?? "").")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                if !done.isEmpty { section("Recently", rows: Array(done.prefix(2)), wanted: false) }
                if !wants.isEmpty { section("Want to Experience", rows: Array(wants.prefix(2)), wanted: true) }
            }

            HStack(spacing: Theme.Space.md) {
                Button(action: onCity) {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2")
                        Text(cityName.map { "Explore \($0)" } ?? "Explore your city").lineLimit(1)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
                }
                .buttonStyle(PressableStyle())

                CaptureButton(action: onCapture)
            }
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.085).opacity(0.92), in: .rect(cornerRadius: Theme.Radius.sheet, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func section(_ title: String, rows: [(CatalogItem, UserExperienceState)], wanted: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title).font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(.white.opacity(0.5))
            ForEach(rows, id: \.0.id) { item, state in
                Button { onOpen(item.id) } label: {
                    HStack(spacing: Theme.Space.md) {
                        Circle()
                            .fill(item.category.group.color)
                            .frame(width: 10, height: 10)
                            .overlay { if wanted { Circle().fill(Color(white: 0.085)).frame(width: 4, height: 4) } }
                        VStack(alignment: .leading, spacing: 2) {
                            SourcedText(item.sourcedTitle)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if let detail = detail(item, state, wanted: wanted) {
                                Text(detail).font(.footnote).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func detail(_ item: CatalogItem, _ state: UserExperienceState, wanted: Bool) -> String? {
        let place = item.place?.neighborhood ?? item.place?.name
        let when = (wanted ? state.savedAt : state.doneAt).map { $0.formatted(.relative(presentation: .named)) }
        return [place, when.map { wanted ? "saved \($0)" : $0 }].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }
}

/// The + : a white disc inside a slowly turning ring of the category colors (Core Animation drives the turn).
private struct CaptureButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(AngularGradient(colors: CategoryGroup.allCases.map(\.color) + [CategoryGroup.allCases[0].color], center: .center), lineWidth: 3)
                    .rotationEffect(.degrees(turning ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 8).repeatForever(autoreverses: false), value: turning)
                Circle().fill(.white).padding(6)
                Image(systemName: "plus").font(.title2.weight(.bold)).foregroundStyle(.black)
            }
            .frame(width: 58, height: 58)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Add an Experience")
        .onAppear { turning = true }
    }
}

// MARK: - Space

/// Near-black with faint seeded stars. Drawn once; three star layers breathe at different rates
/// (opacity animations run in Core Animation, so the stars cost nothing per frame).
struct SpaceBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    private static let stars: [(x: Double, y: Double, r: Double, layer: Int)] = {
        var g = SeededGenerator(seed: 7)
        return (0..<160).map { i in (Double.random(in: 0...1, using: &g), Double.random(in: 0...1, using: &g), Double.random(in: 0.35...1.2, using: &g), i % 3) }
    }()

    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.012, blue: 0.03)
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
