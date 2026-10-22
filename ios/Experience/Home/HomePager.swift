import ExperienceCore
import SwiftUI

/// Home: three pages over one backdrop (space at night, paper or a gallery wall by day). You (left) · your world (center, where the app opens) · Discover (right).
/// Swipe between them, or tap their icons on the island at the bottom. Capture has no entry here for now (founder, 2026-10-21).
struct HomePager: View {
    let onOpenCity: () -> Void

    enum Page: Hashable { case you, world, discover }

    @Environment(AppModel.self) private var model
    @Environment(LifeStore.self) private var life
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: Page? = .world
    @State private var shown = false
    @State private var diving = false
    @State private var detail: UUID?

    var body: some View {
        ZStack {
            HomeBackdrop()

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ProfilePage(onOpen: { detail = $0 })
                        .containerRelativeFrame(.horizontal)
                        .id(Page.you)
                    WorldPage(isActive: page == .world, onOpenCity: openCity)
                        .containerRelativeFrame(.horizontal)
                        .id(Page.world)
                    DiscoverPage(onOpen: { detail = $0 })
                        .containerRelativeFrame(.horizontal)
                        .id(Page.discover)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .defaultScrollAnchor(.center)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HomeIsland(page: page ?? .world, go: go)
                    .offset(y: shown ? 0 : 40)
                    .opacity(shown ? 1 : 0)
            }
            .opacity(diving ? 0 : 1)
        }
        .onAppear {
            diving = false
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.9, bounce: 0)) { shown = true }
        }
        .sheet(item: Binding(get: { detail.map(DetailID.init) }, set: { detail = $0?.id }), onDismiss: { Task { await life.load() } }) { target in
            ExperienceDetailView(id: target.id)
                .environment(\.colorScheme, .light)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(Theme.Radius.sheet)
                .presentationDragIndicator(.visible)
        }
    }

    private struct DetailID: Identifiable { let id: UUID }

    private func go(_ target: Page) {
        withAnimation(reduceMotion ? nil : Theme.Motion.short) { page = target }
    }

    /// The world page turns your city to face you and rushes in; then the city takes over.
    private func openCity(_ globe: GlobeController) {
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

// MARK: - Island

/// A floating island at the bottom with one evenly spaced icon per page: You · your world · Discover.
/// A soft light sits under the current page's icon and slides as you swipe or tap.
private struct HomeIsland: View {
    let page: HomePager.Page
    let go: (HomePager.Page) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @AppStorage("lightBackdrop") private var backdrop: LightBackdrop = .atlas
    @Namespace private var light

    private static let items: [(page: HomePager.Page, symbol: String, label: String)] = [
        (.you, "person.crop.circle", "You"),
        (.world, "globe.americas", "Your world"),
        (.discover, "sparkles", "Discover"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.items, id: \.page) { item in
                let on = page == item.page
                Button { go(item.page) } label: {
                    Image(systemName: item.symbol)
                        .font(.title3.weight(on ? .semibold : .regular))
                        .foregroundStyle(Color.primary.opacity(on ? 1 : 0.5))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background {
                            if on {
                                Capsule()
                                    .fill(Color.primary.opacity(0.14))
                                    .matchedGeometryEffect(id: "light", in: light)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(6)
        .frame(width: 236)
        .background(.ultraThinMaterial, in: .capsule)
        .background(Color.primary.opacity(0.04), in: .capsule)
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
        .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.10), radius: 20, y: 10)
        .animation(reduceMotion ? nil : Theme.Motion.short, value: page)
        .sensoryFeedback(.selection, trigger: page)
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.xs)
        .background {
            // Lists fade into the background under the island instead of running into it.
            let base = HomeBackdrop.base(scheme, backdrop)
            LinearGradient(stops: [.init(color: base.opacity(0), location: 0),
                                   .init(color: base.opacity(0.92), location: 0.45),
                                   .init(color: base, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -Theme.Space.xl)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Shared

/// The page title, in the same place on every page so swiping feels like one surface.
struct PageHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.display(38))
                .displayTracking(38)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.mono)
                    .textCase(.uppercase)
                    .tracking(0.66)
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.sm)
        .padding(.horizontal, Theme.Space.xl)
    }
}

extension AppModel {
    /// Confirmed Experienced, newest first. Only these count (brief §5).
    var experienced: [(CatalogItem, UserExperienceState)] {
        cityCatalog.compactMap { item in states[item.id].flatMap { $0.isDone ? (item, $0) : nil } }
            .sorted { ($0.1.doneAt ?? .distantPast) > ($1.1.doneAt ?? .distantPast) }
    }

    /// Saved and not yet done, newest first.
    var wanted: [(CatalogItem, UserExperienceState)] {
        cityCatalog.compactMap { item in states[item.id].flatMap { $0.isSaved && !$0.isDone ? (item, $0) : nil } }
            .sorted { ($0.1.savedAt ?? .distantPast) > ($1.1.savedAt ?? .distantPast) }
    }
}
