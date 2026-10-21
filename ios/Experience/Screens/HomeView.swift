import ExperienceCore
import SwiftUI

/// The city, one question, three answers. The ask button grows into the panel; the panel becomes the results.
struct HomeView: View {
    var onCamera: () -> Void = {}
    @Environment(AppModel.self) private var model
    @Environment(MapScene.self) private var scene
    @Environment(LocationProvider.self) private var location
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ns

    @State private var stage: Stage = .idle
    @State private var constraints = RecommendationConstraints(when: .tonight, hours: 3, budget: 50, who: .friends)
    @State private var response: RecommendationResponse?
    @State private var active: Int?
    @State private var drag: CGFloat = 0
    @State private var filter: ExploreFilter = .all
    @State private var query = ""
    @State private var detail: DetailTarget?
    @State private var doneBefore = 0
    @State private var toast: String?

    enum Stage: Equatable { case idle, asking, loading, results, explore, failed(String) }

    struct DetailTarget: Identifiable, Equatable { let id: UUID; var recommendationId: UUID? }

    /// Things you've done stand as pillars; height is how much you loved it (DESIGN.md).
    private var pillars: [MapMark] {
        model.cityCatalog.compactMap { item in
            guard let state = model.states[item.id], state.isDone, let c = item.coordinate else { return nil }
            let height: Double = switch state.rating { case 1: 90; case 2: 170; case 3: 260; default: 120 }
            return MapMark(id: item.id, coordinate: .init(latitude: c.lat, longitude: c.lng), group: item.category.group, height: height, radius: 34)
        }
    }

    private var savedDots: [MapMark] {
        model.cityCatalog.compactMap { item in
            guard let state = model.states[item.id], state.isSaved, !state.isDone, let c = item.coordinate else { return nil }
            return MapMark(id: item.id, coordinate: .init(latitude: c.lat, longitude: c.lng), group: item.category.group)
        }
    }

    private var exploreItems: [CatalogItem] {
        let filtered = model.cityCatalog.filter { item in
            let passes: Bool = switch filter {
            case .all: true
            case .group(let g): item.category.group == g
            case .saved: model.states[item.id]?.isSaved == true
            }
            return passes && item.matches(query)
        }
        // Closest first once we know where you are; otherwise alphabetical (the query's order).
        guard location.last != nil else { return filtered }
        func minutes(_ item: CatalogItem) -> Int { item.coordinate.flatMap { location.travelMinutes(to: $0.lat, $0.lng) } ?? .max }
        return filtered.sorted { (minutes($0), $0.title) < (minutes($1), $1.title) }
    }

    var body: some View {
        VStack(spacing: 0) {
            CityHeader(onExplore: openExplore, onCamera: onCamera)
            if let toast {
                Toast(text: toast)
                    .padding(.top, Theme.Space.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: Theme.Space.lg)
            panel
                .offset(y: max(0, drag))
                .padding(8)
        }
        .onAppear {
            applyOnboardingDefaults()
            scene.marks = []
            scene.shot = .city
            scene.bottomInset = 0
        }
        .task {
            await model.loadCatalog()
            doneBefore = model.states.values.filter(\.isDone).count
            refreshYourCity()
        }
        .onChange(of: model.states) { _, _ in refreshYourCity() }
        .onAppear { scene.showsUser = location.isAuthorized }
        .onChange(of: active) { _, i in focus(i) }
        .onChange(of: scene.tapped) { _, id in
            guard let id else { return }
            scene.tapped = nil
            let rec = stage == .results ? response?.requestId : nil
            if stage == .explore { highlight(id) }
            detail = DetailTarget(id: id, recommendationId: rec)
        }
        .onChange(of: filter) { _, _ in if stage == .explore { showExploreMarks() } }
        .onChange(of: query) { _, _ in if stage == .explore { showExploreMarks() } }
        .onChange(of: model.cityCatalog) { _, _ in if stage == .explore { showExploreMarks() } }
        .sheet(item: $detail, onDismiss: afterDetail) { target in
            ExperienceDetailView(id: target.id, recommendationId: target.recommendationId)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(Theme.Radius.sheet)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Panel

    @ViewBuilder private var panel: some View {
        if stage == .idle {
            VStack(spacing: Theme.Space.sm) {
                ExplorePill(count: model.cityCatalog.count, action: openExplore)
                AskButton { open() }
                    .matchedGeometryEffect(id: "panel", in: ns)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                grabber
                switch stage {
                case .asking:
                    AskForm(constraints: $constraints, onFind: { Task { await ask() } }, onClose: close)
                        .transition(.opacity)
                case .loading:
                    LoadingLine(when: constraints.when)
                        .padding(.horizontal, Theme.Space.xl)
                        .padding(.top, Theme.Space.lg)
                        .padding(.bottom, Theme.Space.xl + 4)
                        .transition(.opacity)
                case .results:
                    ResultsContent(response: response, constraints: constraints, active: $active, onChange: open, onClose: close,
                                   onOpen: { pick in detail = DetailTarget(id: pick.id, recommendationId: response?.requestId) })
                        .transition(.opacity)
                case .explore:
                    ExploreContent(items: exploreItems, filter: $filter, query: $query, onSelect: { item in
                        if item.coordinate != nil { highlight(item.id) }
                        detail = DetailTarget(id: item.id)
                    }, onClose: close)
                    .transition(.opacity)
                case .failed(let message):
                    MessageContent(title: "Couldn't get recommendations", message: message,
                                   action: ("Try again", { Task { await ask() } }), onClose: close)
                        .transition(.opacity)
                case .idle:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                    .fill(Theme.surface)
                    .matchedGeometryEffect(id: "panel", in: ns)
                    .lift()
            }
            .simultaneousGesture(dismissDrag)
        }
    }

    private var grabber: some View {
        Capsule().fill(Theme.hairline).frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .accessibilityHidden(true)
    }

    /// Drag the panel down to put it away (vertical drags only, so the cards still swipe).
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                drag = value.translation.height
            }
            .onEnded { value in
                let vertical = abs(value.translation.height) > abs(value.translation.width)
                let flung = value.predictedEndTranslation.height > 260
                withAnimation(Theme.Motion.short) { drag = 0 }
                if vertical, value.translation.height > 110 || flung { close() }
            }
    }

    // MARK: Flow

    private func open() {
        withAnimation(.spring(duration: 0.42, bounce: 0)) { stage = .asking }
        scene.marks = []
        scene.shot = .city
        scene.bottomInset = 0
    }

    private func close() {
        withAnimation(.spring(duration: 0.42, bounce: 0)) {
            stage = .idle
            active = nil
        }
        scene.marks = pillars
        scene.shot = .city
        scene.bottomInset = 0
    }

    /// Dots everywhere; pillars on the home view (other stages use the marks for picks or the catalog).
    private func refreshYourCity() {
        scene.dots = savedDots
        if stage == .idle { scene.marks = pillars }
    }

    private func afterDetail() {
        if stage == .explore { showExploreMarks() }
        let done = model.states.values.filter(\.isDone).count
        if done > doneBefore {
            if stage != .idle { close() }
            show(toast: done == 1 ? "Added to your \(model.city?.name ?? "city"). Your first thing done." : "Added to your \(model.city?.name ?? "city"). \(done) things done.")
        }
        doneBefore = done
    }

    private func show(toast text: String) {
        withAnimation(Theme.Motion.short) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(Theme.Motion.short) { if toast == text { toast = nil } }
        }
    }

    private func openExplore() {
        withAnimation(.spring(duration: 0.42, bounce: 0)) { stage = .explore }
        scene.bottomInset = 470
        showExploreMarks()
    }

    /// Every filtered catalog item with a place stands on the map in its color.
    private func showExploreMarks(selected: UUID? = nil) {
        scene.marks = exploreItems.compactMap { item in
            guard let c = item.coordinate else { return nil }
            return MapMark(id: item.id, coordinate: .init(latitude: c.lat, longitude: c.lng), group: item.category.group,
                           height: item.id == selected ? 320 : 140, radius: 42)
        }
        scene.shot = selected.map { .focus($0) } ?? .marks
    }

    private func highlight(_ id: UUID) { showExploreMarks(selected: id) }

    private func applyOnboardingDefaults() {
        guard let answers = model.profile?.onboarding else { return }
        if let who = answers.usuallyWith.flatMap(RecommendationConstraints.Who.init(rawValue:)) { constraints.who = who }
        constraints.budget = answers.budget.flatMap(Int.init)
    }

    private func ask() async {
        withAnimation(.spring(duration: 0.38, bounce: 0)) { stage = .loading; active = nil }
        scene.bottomInset = 160
        let started = Date()
        // First time: the system asks for location here, where the reason is obvious.
        if let here = await location.current() {
            constraints.location = Coordinate(lat: here.coordinate.latitude, lng: here.coordinate.longitude)
            scene.showsUser = true
        }
        do {
            let r = try await model.api.recommend(constraints)
            // One beat of the status line so results never flash in.
            let wait = 0.6 - Date().timeIntervalSince(started)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            response = r
            scene.marks = marks(for: r, active: nil)
            scene.shot = .marks
            scene.bottomInset = r.picks.isEmpty ? 260 : 470
            withAnimation(.spring(duration: 0.45, bounce: 0)) { stage = .results }
            if !r.picks.isEmpty {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
                if stage == .results { active = 0 }
            }
        } catch {
            scene.bottomInset = 260
            withAnimation(.spring(duration: 0.38, bounce: 0)) {
                stage = .failed((error as? LocalizedError)?.errorDescription ?? "Something went wrong on our side. Try again in a moment.")
            }
        }
    }

    /// The camera follows the card in view; its beacon stands taller.
    private func focus(_ index: Int?) {
        guard let response, stage == .results else { return }
        scene.marks = marks(for: response, active: index)
        if let index, response.picks.indices.contains(index), scene.marks.contains(where: { $0.id == response.picks[index].id }) {
            scene.shot = .focus(response.picks[index].id)
        } else {
            scene.shot = .marks
        }
    }

    private func marks(for response: RecommendationResponse, active: Int?) -> [MapMark] {
        response.picks.enumerated().compactMap { i, pick in
            guard let lat = pick.experience.place?.lat, let lng = pick.experience.place?.lng else { return nil }
            return MapMark(id: pick.id, coordinate: .init(latitude: lat, longitude: lng), group: pick.experience.category.group,
                           height: active == i ? 260 : 110)
        }
    }
}

// MARK: - Header

/// The one translucent layer (DESIGN.md): city name over the map.
private struct CityHeader: View {
    @Environment(AppModel.self) private var model
    let onExplore: () -> Void
    let onCamera: () -> Void

    private var summary: String {
        let done = model.states.values.filter(\.isDone).count
        let saved = model.states.values.filter { $0.isSaved && !$0.isDone }.count
        var parts: [String] = []
        if model.city?.status == .beta { parts.append("Beta") }
        if done > 0 { parts.append("\(done) done") }
        if saved > 0 { parts.append("\(saved) saved") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center) {
            Button(action: onCamera) {
                Image(systemName: "camera")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Camera")
            VStack(alignment: .leading, spacing: 2) {
                Text(model.city?.name ?? "Your city")
                    .font(.title(24))
                    .displayTracking(24)
                    .foregroundStyle(Theme.text)
                if !summary.isEmpty { Text(summary).monoLabel().contentTransition(.numericText()) }
            }
            Spacer()
            Button(action: onExplore) {
                Image(systemName: "map")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Explore the city")
            Menu {
                Button("Sign out", role: .destructive) { Task { await model.signOut() } }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Account")
        }
        .padding(.leading, Theme.Space.xs)
        .padding(.trailing, Theme.Space.sm)
        .padding(.vertical, Theme.Space.sm)
        .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .liftSmall()
        .padding(.horizontal, 8)
    }
}

// MARK: - Ask button

/// Ink block, Bricolage "What should we do?" over two lines, arrow right (DESIGN.md).
private struct AskButton: View {
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(alignment: .bottom) {
                Text("What should\nwe do?")
                    .font(.display(32))
                    .displayTracking(32)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Theme.Space.lg)
                Image(systemName: "arrow.right")
                    .font(.title2.weight(.bold))
                    .padding(.bottom, 6)
            }
            .foregroundStyle(Theme.onPrimary)
            .padding(Theme.Space.xl)
            .frame(maxWidth: .infinity)
            .background(Theme.primary, in: .rect(cornerRadius: Theme.Radius.sheet, style: .continuous))
            .lift()
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("What should we do?")
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
    }
}

/// A quiet way into the whole catalog, above the big question.
private struct ExplorePill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                HStack(spacing: -3) {
                    ForEach(CategoryGroup.allCases, id: \.self) { g in
                        Circle().fill(g.color).frame(width: 9, height: 9).overlay(Circle().stroke(Theme.surface, lineWidth: 1.5))
                    }
                }
                Text(count > 0 ? "Explore \(count) things nearby" : "Explore the city")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.Space.lg)
            .frame(minHeight: 40)
            .background(.regularMaterial, in: .capsule)
            .liftSmall()
        }
        .buttonStyle(PressableStyle())
    }
}

/// "Added to your Philadelphia": a pillar icon rising next to the message.
private struct Toast: View {
    let text: String
    @State private var risen = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(CategoryGroup.culture.color)
                .frame(width: 12, height: risen ? 30 : 4)
                .frame(height: 30, alignment: .bottom)
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.md)
        .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
        .lift()
        .padding(.horizontal, 8)
        .onAppear { withAnimation(.spring(duration: 0.9, bounce: 0).delay(0.2)) { risen = true } }
        .sensoryFeedback(.success, trigger: risen)
        .accessibilityElement(children: .combine)
    }
}
