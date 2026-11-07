import CoreLocation
import ExperienceCore
import MapKit
import PhotosUI
import SwiftUI

/// The tray, opened: one draft at a time, suggested on this phone, kept with one tap.
/// From the camera's tray button, or a row on the globe's card.
struct TraySheet: View {
    @Environment(CaptureTray.self) private var tray
    @Environment(LifeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Called with the kept Experience's title.
    var onKept: (String) -> Void = { _ in }

    @State private var selection: UUID
    @State private var title = ""
    @State private var writing = false
    @State private var picks: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var importError: String?
    @State private var explaining = false
    @State private var editing = false
    @State private var makingCollection = false
    @State private var newCollection = ""
    @State private var kept = 0
    @FocusState private var wordsFocused: Bool

    init(draft: UUID, onKept: @escaping (String) -> Void = { _ in }) {
        _selection = State(initialValue: draft)
        self.onKept = onKept
    }

    private var draft: TrayDraft? { tray.draft(selection) ?? tray.latest }
    private var ordered: [TrayDraft] { tray.drafts.sorted { $0.start < $1.start } }

    var body: some View {
        Group {
            if let draft {
                content(draft)
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: kept)
    }

    private func content(_ draft: TrayDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                if ordered.count > 1 { switcher }
                header(draft)
                grid(draft)
                Text("Touch and hold a photo to move it to its own Experience or remove it.")
                    .font(.footnote).foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, Theme.Space.xs)
                extras(draft)
            }
            .padding(.horizontal, Theme.Space.lg + 4)
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { buttons(draft) }
        .background(Theme.surface)
        .onAppear { title = draft.sourcedTitle.value }
        .onChange(of: selection) { _, _ in
            title = self.draft?.sourcedTitle.value ?? ""
            writing = false
        }
        // A place found after the sheet opened renames an untouched title.
        .onChange(of: draft.suggestedTitle) { _, new in if draft.title == nil { title = new } }
        .onChange(of: picks) { _, items in Task { await importPicks(items, into: draft.id) } }
        .sheet(isPresented: $explaining) { HowWeGuessed(draft: tray.binding(draft.id)) }
        .fullScreenCover(isPresented: $editing) {
            DraftView(draft: tray.binding(draft.id), dismissLabel: "Done", onDismiss: { editing = false }) {
                editing = false
                keep(draft)
            }
        }
        // Edited on the draft screen: the title here follows.
        .onChange(of: editing) { _, open in if !open { title = self.draft?.sourcedTitle.value ?? "" } }
    }

    // MARK: Pieces

    /// More than one draft waiting: pick which by its time.
    private var switcher: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Space.sm) {
                ForEach(ordered) { d in
                    let on = d.id == draft?.id
                    Button {
                        withAnimation(Theme.Motion.micro) { selection = d.id }
                    } label: {
                        Text(d.start.formatted(.dateTime.hour().minute()))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(on ? Theme.onPrimary : Theme.text)
                            .padding(.horizontal, Theme.Space.md)
                            .frame(minHeight: 36)
                            .background(on ? Theme.primary : Theme.soft, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Draft from \(d.start.formatted(.dateTime.hour().minute())), \(d.countLabel)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func header(_ draft: TrayDraft) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("\(dayLabel(draft))'s draft · on this iPhone")
                    .font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Theme.textMuted)
                TextField(draft.suggestedTitle, text: $title, axis: .vertical)
                    .font(.display(28)).displayTracking(28)
                    .foregroundStyle(Theme.text)
                    .submitLabel(.done)
                    .onChange(of: title) { _, t in
                        let typed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                        let own = typed.isEmpty || typed == draft.suggestedTitle ? nil : typed
                        if own != draft.title { tray.update(draft.id) { $0.title = own } }
                    }
                    .accessibilityLabel("Title")
                Button { explaining = true } label: {
                    HStack(spacing: 0) {
                        Text(draft.timeLabel())
                        if let place = draft.sourcedPlace {
                            Text(" · ")
                            SourcedText(place)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows how this was suggested")
                if draft.sourcedTitle.needsEstimateLabel {
                    Text("Title suggested from the place and time (estimated)")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer(minLength: 0)
            Button { editing = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(Theme.soft, in: .circle)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Edit details")
        }
    }

    private func grid(_ draft: TrayDraft) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(draft.shots.sorted { $0.takenAt < $1.takenAt }) { shot in
                MediaThumb(asset: shot.asset, drift: false)
                    .frame(height: 150)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        if shot.id == draft.cover?.id { badge("COVER").padding(8) }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if shot.kind == .video, let d = shot.duration { badge(Self.duration(d)).padding(8) }
                    }
                    .contentShape(.rect)
                    .contextMenu {
                        if shot.id != draft.cover?.id {
                            Button("Use as cover", systemImage: "photo") { tray.update(draft.id) { $0.coverId = shot.id } }
                        }
                        if draft.shots.count > 1 {
                            Button("Make it its own Experience", systemImage: "rectangle.split.2x1") {
                                if let new = tray.split(shot.id) { withAnimation(Theme.Motion.short) { selection = new } }
                            }
                        }
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            withAnimation(Theme.Motion.short) { tray.remove(shot.id) }
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel(shot.kind == .video ? "Video" : "Photo")
                    .accessibilityValue(shot.id == draft.cover?.id ? "Cover" : "")
            }
            PhotosPicker(selection: $picks, maxSelectionCount: 30, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                VStack(spacing: 6) {
                    if importing { ProgressView() } else { Image(systemName: "plus").font(.system(size: 20, weight: .semibold)) }
                    Text("From Photos").font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Theme.soft)
            }
            .disabled(importing)
            .accessibilityLabel("Add from Photos")
        }
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if let importError { Text(importError).font(.caption).foregroundStyle(Theme.error).offset(y: 20) }
        }
    }

    private func extras(_ draft: TrayDraft) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            if writing || !draft.words.isEmpty {
                TextField("What do you want to remember?", text: Binding(
                    get: { tray.draft(draft.id)?.words ?? "" },
                    set: { w in tray.update(draft.id) { $0.words = w } }), axis: .vertical)
                    .lineLimit(2...6)
                    .focused($wordsFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            if makingCollection {
                HStack(spacing: Theme.Space.sm) {
                    TextField("Name it: Barcelona 2024, Sunday dinners…", text: $newCollection)
                        .submitLabel(.done)
                        .onSubmit { makeCollection(draft) }
                    Button("Add") { makeCollection(draft) }
                        .font(.subheadline.weight(.semibold))
                        .disabled(newCollection.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            HStack(spacing: Theme.Space.sm) {
                if !writing && draft.words.isEmpty {
                    DashedChip(label: "A few words…") {
                        writing = true
                        wordsFocused = true
                    }
                }
                collectionMenu(draft)
            }
        }
        .padding(.horizontal, Theme.Space.xs)
    }

    private func collectionMenu(_ draft: TrayDraft) -> some View {
        let chosen = draft.collection.flatMap { c in c.newTitle ?? store.allCollections.first { $0.id == c.collectionId }?.title }
        return Menu {
            if chosen != nil { Button("None") { tray.update(draft.id) { $0.collection = nil } } }
            ForEach(store.allCollections) { c in
                Button(c.title) { tray.update(draft.id) { $0.collection = CollectionChoice(collectionId: c.id) } }
            }
            Divider()
            Button("New collection…", systemImage: "plus") { makingCollection = true }
        } label: {
            DashedChip.label(chosen.map { "In \($0)" } ?? "Collection…", filled: chosen != nil)
        }
        .accessibilityLabel(chosen.map { "Collection: \($0)" } ?? "Add to a collection")
    }

    private func buttons(_ draft: TrayDraft) -> some View {
        HStack(spacing: 10) {
            Button("Keep shooting") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
                .buttonStyle(PressableStyle())
            Button { keep(draft) } label: {
                Label("Save privately", systemImage: "lock.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.primary, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .disabled(importing)
        }
        .padding(.horizontal, Theme.Space.lg + 4)
        .padding(.top, Theme.Space.md)
        .padding(.bottom, Theme.Space.sm)
        .background(Theme.surface)
    }

    // MARK: Actions

    private func keep(_ draft: TrayDraft) {
        let name = tray.draft(draft.id)?.sourcedTitle.value ?? draft.sourcedTitle.value
        guard tray.keep(draft.id, in: store) != nil else { return }
        kept += 1
        onKept(name)
        if let next = ordered.last {
            withAnimation(Theme.Motion.short) { selection = next.id }
        } else {
            dismiss()
        }
    }

    private func makeCollection(_ draft: TrayDraft) {
        let name = newCollection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        tray.update(draft.id) { $0.collection = CollectionChoice(collectionId: UUID(), newTitle: name, newKind: nil) }
        newCollection = ""
        makingCollection = false
    }

    private func importPicks(_ items: [PhotosPickerItem], into id: UUID) async {
        guard !items.isEmpty else { return }
        importing = true
        importError = nil
        let (added, failed) = await LifeMedia.importPicked(items)
        tray.add(added, to: id)
        picks = []
        importing = false
        if failed > 0 { importError = failed == 1 ? "One item couldn't be added." : "\(failed) items couldn't be added." }
    }

    private func dayLabel(_ draft: TrayDraft) -> String {
        if Calendar.current.isDateInToday(draft.start) {
            return Calendar.current.component(.hour, from: draft.start) >= 17 ? "Tonight" : "Today"
        }
        if Calendar.current.isDateInYesterday(draft.start) { return "Yesterday" }
        return draft.start.formatted(.dateTime.weekday(.wide))
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold)).monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(.black.opacity(0.55), in: .capsule)
    }

    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// An optional extra, offered with a dashed outline until it's used.
private struct DashedChip: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { Self.label(label, filled: false) }
            .buttonStyle(PressableStyle())
    }

    static func label(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .padding(.horizontal, Theme.Space.md)
            .frame(minHeight: 36)
            .background(filled ? Theme.soft : .clear, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(Theme.text.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
    }
}

// MARK: - How we guessed

/// Every suggestion, with where it came from. Fix the place here; fixed stays fixed.
struct HowWeGuessed: View {
    @Binding var draft: TrayDraft
    @Environment(\.dismiss) private var dismiss
    @State private var choosingPlace = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("How we guessed").font(.display(26)).displayTracking(26).foregroundStyle(Theme.text)
                    Text("These are suggestions until you keep them. Nothing here was sent anywhere but Apple Maps, for the names of places.")
                        .font(.subheadline).foregroundStyle(Theme.textMuted)
                }
                VStack(spacing: 0) {
                    row("Time") {
                        Text(draft.timeLabel()).font(.body.weight(.semibold))
                        Text(timeReason).font(.footnote).foregroundStyle(Theme.textMuted)
                    }
                    row("Place") { place }
                    row("Title") {
                        SourcedText(draft.sourcedTitle).font(.body.weight(.semibold))
                        Text(titleReason).font(.footnote).foregroundStyle(Theme.textMuted)
                    }
                    row("People") {
                        Text("We don't guess who was there.").font(.subheadline).foregroundStyle(Theme.textMuted)
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }

                HStack(spacing: Theme.Space.md) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.text)
                    Text("Worked out on this iPhone from your photos' time and location. Fix anything and it stays fixed.")
                        .font(.footnote).foregroundStyle(Theme.text.opacity(0.8))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.xl)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Looks right") { dismiss() }
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.Space.xl)
                .padding(.vertical, Theme.Space.sm)
                .background(Theme.surface)
        }
        .background(Theme.surface)
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $choosingPlace) { PlacePicker(draft: $draft) }
    }

    @ViewBuilder
    private var place: some View {
        if let p = draft.sourcedPlace {
            SourcedText(p).font(.body.weight(.semibold))
        } else {
            Text(draft.placeChosen ? "No place" : "Not known").font(.body.weight(.semibold))
        }
        Text(placeReason).font(.footnote).foregroundStyle(Theme.textMuted)
        let others = draft.nearby.filter { $0 != draft.place }.prefix(3)
        FlowLayout(spacing: 6) {
            ForEach(Array(others), id: \.self) { p in
                smallButton(p.name) { draft.place = p; draft.placeChosen = true }
            }
            smallButton("Somewhere else") { choosingPlace = true }
            if draft.sourcedPlace != nil { smallButton("No place") { draft.place = nil; draft.placeChosen = true } }
        }
        .padding(.top, 4)
    }

    private var timeReason: String {
        if draft.chosenTime != nil { return "You set this." }
        return draft.shots.count > 1 ? "From the first and last photo" : "From when you took it"
    }

    private var placeReason: String {
        if draft.placeChosen { return draft.place == nil ? "You said there isn't one." : "You chose this." }
        if draft.center == nil { return "These photos don't have a location. Pick the place yourself if you like." }
        if draft.place != nil {
            let others = draft.nearby.filter { $0 != draft.place }.count
            return "The photos were taken right by it (Apple Maps)." + (others > 0 ? " Other places are close too." : "")
        }
        if draft.area != nil { return "Nothing named right where the photos were, so just the neighborhood." }
        return "Looking up what's here…"
    }

    private var titleReason: String {
        switch draft.sourcedTitle.provenance {
        case .user: "You wrote this."
        case .estimated: "From the kind of place and the time of day. Change it on the draft."
        default: "From the day and time. Change it on the draft."
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.md) {
            Text(label).font(.subheadline).foregroundStyle(Theme.textMuted).frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) { content() }
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
            .buttonStyle(PressableStyle())
    }
}
