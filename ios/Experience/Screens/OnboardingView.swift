import ExperienceCore
import MapLibre
import SwiftUI

/// City → what you like → budget → who. A panel over the living map: picking a city flies there, each taste
/// lights up those places, single-choice steps advance on tap. Everything after the city is skippable (MVP.md).
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(MapScene.self) private var scene
    @State private var step = 0
    @State private var forward = true
    @State private var cityId: String?
    @State private var answers = OnboardingAnswers()
    @State private var saving = false
    @State private var error: String?

    private let steps = 4

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                header
                ZStack(alignment: .topLeading) {
                    content
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                }
                .padding(.horizontal, Theme.Space.xl)
                .padding(.top, Theme.Space.sm)
                .clipped()
                footer
            }
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.sheet, style: .continuous))
            .lift()
            .padding(8)
        }
        .animation(.spring(duration: 0.35, bounce: 0), value: step)
        .onAppear {
            cityId = cityId ?? model.cities.first { $0.status != .coming }?.id
            focusCity()
        }
        .onChange(of: answers.likes) { _, _ in lightUpLikes() }
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: Theme.Space.sm) {
            Button { go(step - 1) } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 44, height: 44)
            }
            .opacity(step > 0 ? 1 : 0)
            .disabled(step == 0)
            .accessibilityLabel("Back")
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.primary : Theme.soft).frame(width: i == step ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step + 1) of \(steps)")
            Spacer()
            Button("Skip") { Task { await finish() } }
                .font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .opacity(step > 0 ? 1 : 0)
                .disabled(step == 0)
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, Theme.Space.sm)
        .padding(.top, Theme.Space.sm)
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: Theme.Space.sm) {
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.error).frame(maxWidth: .infinity, alignment: .leading)
            }
            // Single-choice steps advance on tap; only the city and likes steps need a button.
            if step <= 1 {
                Button(step == 0 ? "Next" : (answers.likes.isEmpty ? "Not sure yet" : "Next")) { go(step + 1) }
                    .buttonStyle(step == 1 && answers.likes.isEmpty ? AnyButtonStyle(.secondary) : AnyButtonStyle(.primary))
                    .disabled(cityId == nil || model.cities.first { $0.id == cityId }?.status == .coming)
            }
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.top, Theme.Space.lg)
        .padding(.bottom, Theme.Space.lg)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: cityStep
        case 1: likesStep
        case 2: budgetStep
        default: whoStep
        }
    }

    private func title(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.display(30)).displayTracking(30).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.subheadline).foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Steps

    private var cityStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            title("Where do you live?", "Recommendations are for the city you're in.")
            VStack(spacing: Theme.Space.sm) {
                ForEach(model.cities) { city in
                    CityRow(city: city, selected: cityId == city.id) {
                        cityId = city.id
                        focusCity()
                    }
                }
            }
        }
    }

    private var likesStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            title("What are you into?", "Tap a few and watch your city light up.")
            FlowLayout(spacing: 8) {
                ForEach(TasteChip.all) { chip in
                    Chip(label: chip.label, group: chip.group, isOn: answers.likes.contains(chip.id)) {
                        if let i = answers.likes.firstIndex(of: chip.id) { answers.likes.remove(at: i) } else { answers.likes.append(chip.id) }
                    }
                }
            }
        }
    }

    private var budgetStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            title("Usual budget?", "Per person. You can change it every time you ask.")
            VStack(spacing: Theme.Space.sm) {
                ForEach(BudgetOption.all, id: \.label) { option in
                    OptionRow(label: option.label, selected: chosenBudget == option.label) {
                        answers.budget = option.value.map(String.init)
                        chosenBudget = option.label
                        advance()
                    }
                }
            }
        }
    }

    @State private var chosenBudget: String?

    private var whoStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            title("Who do you usually go with?", "It shapes what fits. You can change it every time.")
            VStack(spacing: Theme.Space.sm) {
                ForEach(WhoOption.all, id: \.value) { option in
                    OptionRow(label: option.label, selected: answers.usuallyWith == option.value.rawValue, busy: saving && answers.usuallyWith == option.value.rawValue) {
                        answers.usuallyWith = option.value.rawValue
                        Task { await finish() }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    // MARK: Flow

    private func go(_ next: Int) {
        guard (0..<steps).contains(next) else { return }
        forward = next > step
        error = nil
        step = next
        if next == 1 { Task { if let cityId { await model.loadPins(cityId: cityId) }; lightUpLikes() } }
        if next != 1 { scene.marks = [] }
        if next == 0 { focusCity() }
    }

    /// A short beat so the selection registers before the panel moves on.
    private func advance() {
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            go(step + 1)
        }
    }

    private func focusCity() {
        guard let city = model.cities.first(where: { $0.id == cityId }) else { return }
        scene.center = .init(latitude: city.centerLat, longitude: city.centerLng)
        scene.shot = .city
        scene.bottomInset = 430
    }

    /// Every catalog Experience matching a picked taste rises on the map in its category color.
    private func lightUpLikes() {
        guard let cityId else { return }
        let chips = answers.likes.compactMap { id in TasteChip.all.first { $0.id == id } }
        scene.marks = (model.pins[cityId] ?? [])
            .filter { pin in chips.contains { $0.matches(pin) } }
            .map { MapMark(id: $0.id, coordinate: .init(latitude: $0.lat, longitude: $0.lng), group: $0.category.group, height: 260, radius: 70) }
        scene.shot = scene.marks.isEmpty ? .city : .marks
    }

    private func finish() async {
        guard let cityId, !saving else { return }
        saving = true
        error = nil
        do {
            try await model.finishOnboarding(cityId: cityId, answers: answers)
            scene.marks = []
        } catch {
            self.error = "Couldn't save. Check your connection and try again."
        }
        saving = false
    }
}

/// Type-erased button style so the footer can switch between primary and secondary.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

private struct CityRow: View {
    let city: City
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name).font(.title(22)).displayTracking(22)
                    Text(city.status == .coming ? "Coming next" : city.status == .beta ? "Beta" : "Live").monoLabel()
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.primary : Theme.hairline)
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(Theme.text.opacity(city.status == .coming ? 0.55 : 1))
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.md + 2)
            .background(Theme.raised, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? Theme.primary : Theme.hairline, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(city.status == .coming ? "Coming next. You can look around, but recommendations aren't ready yet." : "")
        .sensoryFeedback(.selection, trigger: selected)
    }
}

struct OptionRow: View {
    let label: String
    let selected: Bool
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label).font(.body.weight(.semibold))
                Spacer()
                if busy {
                    ProgressView()
                } else if selected {
                    Image(systemName: "checkmark").font(.body.weight(.bold)).transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.Space.lg)
            .frame(minHeight: 50)
            .background(selected ? Theme.soft : Theme.raised, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(selected ? Theme.primary : Theme.hairline, lineWidth: selected ? 2 : 1)
            }
            .animation(Theme.Motion.micro, value: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Options (keys and categories match supabase/functions/recommend/core.ts LIKE_CHIPS)

struct TasteChip: Identifiable {
    let id: String
    let label: String
    let group: CategoryGroup
    let categories: [ExperienceCategory]
    /// Tags that also count (e.g. "Something weird" has no category of its own).
    var tags: [String] = []

    func matches(_ pin: CatalogPin) -> Bool {
        categories.contains(pin.category) || !Set(tags).isDisjoint(with: pin.tags)
    }

    static let all: [TasteChip] = [
        .init(id: "food", label: "Food spots", group: .food, categories: [.food, .cafe]),
        .init(id: "live_music", label: "Live music", group: .nightlife, categories: [.music]),
        .init(id: "comedy", label: "Comedy", group: .nightlife, categories: [.comedy]),
        .init(id: "museums", label: "Museums", group: .culture, categories: [.artsCulture, .attraction]),
        .init(id: "classes", label: "Classes", group: .activity, categories: [.class]),
        .init(id: "outdoors", label: "Outdoors", group: .outdoors, categories: [.outdoors, .active]),
        .init(id: "bars", label: "Bars", group: .nightlife, categories: [.bar, .nightlife]),
        .init(id: "games", label: "Games & arcades", group: .activity, categories: [.games]),
        .init(id: "markets", label: "Markets", group: .food, categories: [.market, .shopping]),
        .init(id: "weird", label: "Something weird", group: .other, categories: [], tags: ["unusual", "weird", "quirky", "offbeat"]),
        .init(id: "sports", label: "Sports", group: .outdoors, categories: [.sports, .active]),
        .init(id: "dessert", label: "Dessert", group: .food, categories: [.dessert]),
    ]
}

struct BudgetOption {
    let label: String
    /// Dollars per person; nil = no preference, 0 = free only.
    let value: Int?

    static let all: [BudgetOption] = [
        .init(label: "Free", value: 0), .init(label: "Under $25", value: 25), .init(label: "Under $50", value: 50),
        .init(label: "Under $100", value: 100), .init(label: "No preference", value: nil),
    ]
}

struct WhoOption {
    let label: String
    let short: String
    let value: RecommendationConstraints.Who

    static let all: [WhoOption] = [
        .init(label: "Just me", short: "Solo", value: .solo), .init(label: "My partner", short: "Partner", value: .date),
        .init(label: "Friends", short: "Friends", value: .friends), .init(label: "A big group", short: "Group", value: .group),
        .init(label: "Family", short: "Family", value: .family),
    ]
}
