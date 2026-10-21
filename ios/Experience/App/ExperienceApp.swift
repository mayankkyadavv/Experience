import SwiftUI

@main
struct ExperienceApp: App {
    @State private var model = AppModel()
    @State private var scene = MapScene()
    @State private var location = LocationProvider()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(scene)
                .environment(location)
        }
    }
}

/// One living city behind every screen; screens are panels over it. Home is the globe (your world) above it.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(MapScene.self) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var introDone = false
    /// Home is the globe; the city is one dive away.
    @State private var showingCity = false
    @State private var capturing = false
    @State private var camera = CameraModel()

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            CityMapView(scene: scene)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if model.phase == .ready && !showingCity {
                GlobeHomeView(
                    onOpenCity: { withAnimation(.easeOut(duration: 0.35)) { showingCity = true } },
                    onCapture: { capturing = true }
                )
                .transition(.opacity)
            } else if model.phase == .launching || !introDone {
                LaunchCurtain()
                    .transition(.opacity)
            } else {
                Group {
                    switch model.phase {
                    case .launching: Color.clear
                    case .signedOut: WelcomeView()
                    case .onboarding: OnboardingView()
                    case .ready:
                        HomeView(onHome: { withAnimation(.easeInOut(duration: 0.45)) { showingCity = false } })
                            .transition(.opacity)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.short, value: model.phase)
        .tint(Theme.primary)
        .fullScreenCover(isPresented: $capturing) {
            CaptureFlow(camera: camera, onClose: { capturing = false })
        }
        .task { await model.start() }
        .task(id: model.phase) {
            guard model.phase == .ready else { return }
            await model.loadCatalog()
            await model.loadStates()
        }
        .task { await runIntro() }
        .onChange(of: model.city) { _, city in
            if let city { scene.center = .init(latitude: city.centerLat, longitude: city.centerLng) }
        }
        .onChange(of: showingCity) { _, city in
            // Arrive from above: the city tilts in under the dive.
            guard city else { return }
            scene.flight = 0
            scene.shot = .intro
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                scene.flight = reduceMotion ? 0 : 1.8
                scene.shot = .city
            }
        }
    }

    /// Black space with the name → (signed in) the globe, or (new) the flat city tilts in and the first panel slides up.
    private func runIntro() async {
        // Wait (briefly) for tiles and the session; never block the app on a slow network.
        for _ in 0..<60 where model.phase == .launching || (model.phase != .ready && !scene.ready) {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if let city = model.city { scene.center = .init(latitude: city.centerLat, longitude: city.centerLng) }
        if model.phase == .ready {
            withAnimation(Theme.Motion.medium) { introDone = true }
            return
        }
        scene.flight = reduceMotion ? 0 : 2.2
        scene.shot = .city
        try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.6))
        withAnimation(.easeInOut(duration: 0.8)) { introDone = true }
        scene.flight = 1.1
    }
}

/// Launch: black space and the name at the top, where home keeps it.
private struct LaunchCurtain: View {
    @State private var shown = false

    var body: some View {
        ZStack(alignment: .top) {
            SpaceBackground()
            Text("Experiences")
                .font(.display(38))
                .displayTracking(38)
                .foregroundStyle(.white)
                .padding(.top, Theme.Space.sm)
                .blur(radius: shown ? 0 : 8)
                .opacity(shown ? 1 : 0)
                .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0)) { shown = true } }
                .accessibilityAddTraits(.isHeader)
        }
    }
}
