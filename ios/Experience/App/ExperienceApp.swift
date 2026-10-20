import SwiftUI

@main
struct ExperienceApp: App {
    @State private var model = AppModel()
    @State private var scene = MapScene()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(scene)
        }
    }
}

/// One living city behind every screen; screens are panels over it.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(MapScene.self) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var introDone = false

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            CityMapView(scene: scene)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if !introDone {
                Wordmark()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                Group {
                    switch model.phase {
                    case .launching: Color.clear
                    case .signedOut: WelcomeView()
                    case .onboarding: OnboardingView()
                    case .ready: HomeView()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.short, value: model.phase)
        .tint(Theme.primary)
        .task { await model.start() }
        .task { await runIntro() }
        .onChange(of: model.city) { _, city in
            if let city { scene.center = .init(latitude: city.centerLat, longitude: city.centerLng) }
        }
    }

    /// Flat city from above → the camera tilts in and the buildings rise → the first panel slides up.
    private func runIntro() async {
        // Wait (briefly) for tiles and the session; never block the app on a slow network.
        for _ in 0..<60 where !(scene.ready && model.phase != .launching) {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if let city = model.city { scene.center = .init(latitude: city.centerLat, longitude: city.centerLng) }
        let returning = model.phase == .ready
        scene.flight = reduceMotion ? 0 : (returning ? 1.4 : 2.2)
        scene.shot = .city
        try? await Task.sleep(for: .seconds(reduceMotion ? 0 : (returning ? 0.7 : 1.3)))
        withAnimation(Theme.Motion.medium) { introDone = true }
        scene.flight = 1.1
    }
}

/// The name over the flat city while it loads and rises.
private struct Wordmark: View {
    @State private var shown = false

    var body: some View {
        Text("Experience")
            .font(.display(46))
            .displayTracking(46)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Theme.surface.opacity(0.75), in: .capsule)
            .blur(radius: shown ? 0 : 8)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.96)
            .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0)) { shown = true } }
            .accessibilityAddTraits(.isHeader)
    }
}
