import ExperienceCore
import SwiftUI

/// Loading → three cards (or empty / error) over the map. The active card drives the camera.
/// Three cards (or the empty state) inside the home panel. The card in view drives the camera.
struct ResultsContent: View {
    let response: RecommendationResponse?
    let constraints: RecommendationConstraints
    @Binding var active: Int?
    let onChange: () -> Void
    let onClose: () -> Void
    let onOpen: (Pick) -> Void

    var body: some View {
        if let response, !response.picks.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Text(heading(response.picks.count)).monoLabel()
                    Spacer()
                    Button("Change", action: onChange)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .frame(minHeight: 44)
                    CloseButton(action: onClose)
                }
                .padding(.leading, Theme.Space.xl)
                .padding(.trailing, Theme.Space.sm)
                Carousel(response: response, active: $active, onOpen: onOpen)
            }
            .padding(.bottom, Theme.Space.lg)
        } else {
            MessageContent(title: "Nothing fits that right now",
                           message: "Try a longer time, another day, or no budget limit.",
                           action: ("Change answers", onChange), onClose: onClose)
        }
    }

    private func heading(_ count: Int) -> String {
        let when: String = switch constraints.when {
        case .now: "right now"
        case .tonight: "tonight"
        case .tomorrow: "tomorrow"
        case .weekend: "this weekend"
        }
        return "\(count == 1 ? "1 thing" : "\(count) things") for \(when)"
    }
}

struct MessageContent: View {
    let title: String
    let message: String
    let action: (String, () -> Void)
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title(22)).displayTracking(22).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                CloseButton(action: onClose)
            }
            Text(message).font(.body).foregroundStyle(Theme.textMuted).fixedSize(horizontal: false, vertical: true)
            Button(action.0, action: action.1).buttonStyle(.primary).padding(.top, Theme.Space.sm)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.xl)
    }
}

// MARK: - Loading

/// Status lines that morph while we look (DESIGN.md "Find 3 things").
struct LoadingLine: View {
    let when: RecommendationConstraints.When
    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lines: [String] {
        let w = when == .now ? "right now" : when == .weekend ? "this weekend" : when.rawValue
        return ["Checking what's open \(w)…", "Matching what you like…", "Picking three…"]
    }

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            ProgressView()
            Text(lines[index])
                .font(.title(20))
                .displayTracking(20)
                .foregroundStyle(Theme.text)
                .id(index)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .task {
            while !Task.isCancelled, index < lines.count - 1 {
                try? await Task.sleep(for: .seconds(0.4))
                withAnimation(Theme.Motion.short) { index += 1 }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cards

private struct Carousel: View {
    let response: RecommendationResponse
    @Binding var active: Int?
    let onOpen: (Pick) -> Void
    @State private var risen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Theme.Space.md) {
                ForEach(Array(response.picks.enumerated()), id: \.element.id) { i, pick in
                    RecommendationCard(number: i + 1, pick: pick, requestId: response.requestId, onOpen: { onOpen(pick) })
                        .id(i)
                        .offset(y: risen ? 0 : 60)
                        .opacity(risen ? 1 : 0)
                        .animation(.spring(duration: 0.55, bounce: 0).delay(reduceMotion ? 0 : Double(i) * 0.07), value: risen)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, Theme.Space.lg, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $active)
        .fixedSize(horizontal: false, vertical: true) // hug the cards so the map stays visible above
        .sensoryFeedback(.impact(weight: .light), trigger: active)
        .onAppear { risen = true }
    }
}

struct RecommendationCard: View {
    @Environment(AppModel.self) private var model
    let number: Int
    let pick: Pick
    let requestId: UUID?
    let onOpen: () -> Void

    @State private var interested = false
    @State private var notForUs = false
    @State private var saved = false
    @State private var error: String?

    private var experience: PickedExperience { pick.experience }

    private var facts: [Sourced<String>] {
        var out: [Sourced<String>] = []
        if let p = pick.facts.price { out.append(experience.sourced("price_min_cents", p)) }
        if let d = pick.facts.duration { out.append(experience.sourced("duration_min_minutes", d)) }
        // Travel time is our own rough estimate.
        if let t = pick.facts.travelMinutes { out.append(Sourced("~\(t) min away", .estimated)) }
        if let o = pick.facts.openUntil { out.append(experience.sourced("hours", o)) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .contentShape(.rect)
                .onTapGesture(perform: onOpen)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Details for \(experience.title)")
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SourcedText(experience.sourcedTitle)
                    .font(.title(20))
                    .displayTracking(20)
                    .foregroundStyle(Theme.text)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let place = experience.place {
                    Text([place.name, place.neighborhood].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                }
                FlowLayout(spacing: 6) {
                    ForEach(facts.indices, id: \.self) { FactChip(text: facts[$0]) }
                }
                .padding(.top, 2)
                if !pick.reasons.isEmpty {
                    Text(pick.reasons.joined(separator: ". "))
                        .font(.footnote)
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(Theme.error)
                }
                actions
            }
            .padding(Theme.Space.lg)
        }
        .frame(width: 262)
        .background(Theme.raised, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.hairline) }
        .opacity(notForUs ? 0.45 : 1)
        .animation(Theme.Motion.short, value: notForUs)
    }

    private var photo: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let url = experience.imageUrl {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Theme.soft }
                } else {
                    // No photo yet: a quiet block in the category color, never a stock image.
                    experience.category.group.color.opacity(0.08)
                        .overlay { Circle().fill(experience.category.group.color).frame(width: 10, height: 10) }
                }
            }
            .frame(height: experience.imageUrl == nil ? 88 : 128)
            .frame(maxWidth: .infinity)
            .clipped()

            HStack(spacing: 6) {
                Text("\(number)").font(.footnote.weight(.bold)).monospacedDigit()
                    .frame(width: 24, height: 24)
                    .background(Theme.primary, in: .circle)
                    .foregroundStyle(Theme.onPrimary)
                HStack(spacing: 5) {
                    Circle().fill(experience.category.group.color).frame(width: 7, height: 7)
                    Text(experience.category.group.label).font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(.regularMaterial, in: .capsule)
            }
            .padding(Theme.Space.md)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.card, topTrailingRadius: Theme.Radius.card, style: .continuous))
    }

    private var actions: some View {
        HStack(spacing: Theme.Space.sm) {
            Button {
                toggle(&interested, on: .interested, off: nil)
                if interested { notForUs = false }
            } label: {
                Label(interested ? "We're in" : "Interested", systemImage: interested ? "checkmark" : "hand.thumbsup")
                    .labelStyle(.titleOnly)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(interested ? .white : Theme.onPrimary)
                    .background(interested ? Theme.success : Theme.primary, in: .rect(cornerRadius: Theme.Radius.button - 2, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .sensoryFeedback(.success, trigger: interested) { _, new in new }

            Button {
                toggle(&notForUs, on: .notInterested, off: nil)
                if notForUs { interested = false }
            } label: {
                Text("Not for us")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Theme.text)
                    .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button - 2, style: .continuous))
            }
            .buttonStyle(PressableStyle())

            Button {
                toggle(&saved, on: .save, off: .unsave)
            } label: {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(saved ? CategoryGroup.activity.color : Theme.text)
                    .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button - 2, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(saved ? "Saved" : "Save")
        }
    }

    /// Optimistic: flip now, send, flip back with a message if the server says no.
    private func toggle(_ flag: inout Bool, on: Feedback.Action, off: Feedback.Action?) {
        let wasOn = flag
        if wasOn, off == nil { return } // Interested / Not for us stay set until the other is chosen
        withAnimation(Theme.Motion.short) { flag.toggle() }
        error = nil
        let action = wasOn ? off! : on
        let id = experience.id, rec = requestId
        Task {
            do {
                try await model.send(Feedback(action, on: id, recommendationId: rec))
            } catch {
                withAnimation(Theme.Motion.short) { revert(action) }
                self.error = "Didn't save. Check your connection."
            }
        }
    }

    private func revert(_ action: Feedback.Action) {
        switch action {
        case .interested: interested = false
        case .notInterested: notForUs = false
        case .save: saved = false
        case .unsave: saved = true
        default: break
        }
    }
}
