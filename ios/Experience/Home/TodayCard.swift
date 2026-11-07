import ExperienceCore
import SwiftUI

/// On the globe, when shots are waiting (C): what the day's photos look like as Experiences, grouped by time
/// and place. Keep the ones that are right, or leave them for later. Nothing is kept without a tap.
struct TodayCard: View {
    @Environment(CaptureTray.self) private var tray
    @Environment(LifeStore.self) private var store
    let onOpen: (UUID) -> Void

    @State private var skipped: Set<UUID> = []
    @State private var kept = 0

    private var drafts: [TrayDraft] { tray.drafts.sorted { $0.start < $1.start } }
    private var keeping: [TrayDraft] { drafts.filter { !skipped.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title(21)).displayTracking(21).foregroundStyle(Theme.text)
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.textMuted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 10) {
                ForEach(drafts.prefix(3)) { row($0) }
                if drafts.count > 3 {
                    Text("And \(drafts.count - 3) more in the tray").font(.footnote).foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(spacing: 10) {
                Button("Later") { withAnimation(Theme.Motion.short) { tray.snooze() } }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
                    .buttonStyle(PressableStyle())
                    .accessibilityHint("Hides this until you take more photos")
                Button(action: keepChosen) {
                    Text(keeping.count == 1 ? "Keep it privately" : "Keep \(keeping.count) privately")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.primary.opacity(keeping.isEmpty ? 0.3 : 1),
                                    in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .disabled(keeping.isEmpty)
            }
        }
        .padding(20)
        .background(Theme.raised, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 20, y: 10)
        .sensoryFeedback(.success, trigger: kept)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's captures")
    }

    private var dayPhrase: String {
        guard let first = drafts.first?.start else { return "Today" }
        let cal = Calendar.current
        if cal.isDateInToday(first) { return "Today" }
        if cal.isDateInYesterday(first) { return "Since yesterday" }
        return "Since \(first.formatted(.dateTime.weekday(.wide)))"
    }

    private var title: String {
        let n = drafts.count
        let word = n < 11 ? ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"][max(n, 1) - 1] : "\(n)"
        let placed = drafts.allSatisfy { $0.sourcedPlace != nil }
        if n == 1 { return placed ? "\(dayPhrase), in one place" : "\(dayPhrase), one draft" }
        return placed ? "\(dayPhrase), in \(word) places" : "\(dayPhrase), \(word) drafts"
    }

    private var subtitle: String {
        let photos = drafts.reduce(0) { $0 + $1.photos }, videos = drafts.reduce(0) { $0 + $1.videos }
        let what = TrayDraft.countLabel(photos: photos, videos: videos)
        return drafts.count == 1
            ? "\(what). Keep it as an Experience, or leave it for later."
            : "\(what), grouped by time and place. Keep them as Experiences, or leave them for later."
    }

    private func row(_ draft: TrayDraft) -> some View {
        let on = !skipped.contains(draft.id)
        return HStack(spacing: Theme.Space.md) {
            Button { onOpen(draft.id) } label: {
                HStack(spacing: Theme.Space.md) {
                    Group {
                        if let cover = draft.cover { MediaThumb(asset: cover.asset, drift: false) } else { Theme.soft }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(.rect(cornerRadius: Theme.Radius.control, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        SourcedText(draft.sourcedTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(2)
                        HStack(spacing: 0) {
                            Text("\(draft.start.formatted(.dateTime.hour().minute())) · \(draft.countLabel.lowercased())")
                            if let place = draft.sourcedPlace, draft.place == nil {
                                // The title already names a place; an area adds where it was.
                                Text(" · ")
                                SourcedText(place)
                            }
                        }
                        .font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens the draft")

            Button {
                withAnimation(Theme.Motion.micro) { if on { skipped.insert(draft.id) } else { skipped.remove(draft.id) } }
            } label: {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(on ? Theme.primary : Theme.textMuted)
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Keep \(draft.sourcedTitle.value)")
            .accessibilityAddTraits(on ? .isSelected : [])
        }
    }

    private func keepChosen() {
        for d in keeping { tray.keep(d.id, in: store) }
        skipped = []
        kept += 1
    }
}
