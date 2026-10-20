import ExperienceCore
import SwiftUI

/// The four questions plus an optional mood, on one screen (MVP.md "Minimal constraints").
struct AskForm: View {
    @Binding var constraints: RecommendationConstraints
    let onFind: () -> Void
    let onClose: () -> Void

    private static let durations: [(Double, String)] = [(1, "1 hr"), (2, "2 hrs"), (3, "3 hrs"), (5, "5+ hrs")]
    private static let budgets: [(Int, String)] = [(0, "Free"), (25, "$25"), (50, "$50"), (100, "$100"), (-1, "Any")]
    private static let moods: [(RecommendationConstraints.Mood, String)] = [
        (.chill, "Chill"), (.active, "Active"), (.food, "Food"), (.creative, "Creative"), (.nightlife, "Nightlife"),
        (.outdoors, "Outdoors"), (.somethingNew, "Something new"), (.surprise, "Surprise me"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("What should we do?")
                    .font(.display(26))
                    .displayTracking(26)
                    .foregroundStyle(Theme.text)
                Spacer()
                CloseButton(action: onClose)
            }

            row("When?") {
                Segmented(options: [(.now, "Now"), (.tonight, "Tonight"), (.tomorrow, "Tomorrow"), (.weekend, "Weekend")],
                          selection: $constraints.when)
            }
            row("How long?") {
                Segmented(options: Self.durations, selection: $constraints.hours)
            }
            row("Budget per person?") {
                Segmented(options: Self.budgets, selection: Binding(
                    get: { constraints.budget ?? -1 },
                    set: { constraints.budget = $0 < 0 ? nil : $0 }
                ))
            }
            row("Who's going?") {
                Segmented(options: WhoOption.all.map { ($0.value, $0.short) }, selection: Binding(
                    get: { constraints.who },
                    set: { constraints.who = $0; constraints.groupSize = $0 == .group ? 4 : nil }
                ))
            }
            row("Mood") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.moods, id: \.0) { mood, label in
                            Chip(label: label, isOn: constraints.mood == mood) {
                                constraints.mood = constraints.mood == mood ? nil : mood
                            }
                        }
                    }
                }
                .scrollClipDisabled()
            }

            Button("Find 3 things", action: onFind)
                .buttonStyle(.primary)
                .padding(.top, Theme.Space.xs)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.lg)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
            content()
        }
    }
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.text)
                .frame(width: 32, height: 32)
                .background(Theme.soft, in: .circle)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("Close")
    }
}
