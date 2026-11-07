import CoreLocation
import ExperienceCore
import PhotosUI
import SwiftUI

/// The one draft screen, whatever the way in: a tray draft from the camera, photos picked from the library, just
/// words, or something to do one day. Suggestions are labelled until the person keeps them; Save keeps it privately.
struct DraftView: View {
    @Binding var draft: TrayDraft
    /// "Cancel" for a new draft (it's thrown away); "Done" for a tray draft, whose edits are already kept in the tray.
    var dismissLabel = "Cancel"
    let onDismiss: () -> Void
    let onSave: () -> Void

    @Environment(LifeStore.self) private var store
    @State private var title = ""
    @State private var editingTime = false
    @State private var choosingPlace = false
    @State private var explaining = false
    @State private var showingKinds = false
    @State private var makingCollection = false
    @State private var newCollection = ""
    @State private var picks: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var importError: String?
    @FocusState private var titleFocused: Bool

    private var hasMedia: Bool { !draft.shots.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if hasMedia { hero } else { plainTop }
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    titleBlock
                    if !hasMedia { wordsInline }
                    rows
                    if hasMedia { wordsBox }
                }
                .padding(.horizontal, Theme.Space.xl)
                .padding(.top, hasMedia ? 18 : Theme.Space.sm)
                .padding(.bottom, Theme.Space.xxl)
            }
        }
        .ignoresSafeArea(edges: hasMedia ? .top : [])
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        .background(Theme.surface)
        .onAppear {
            title = draft.sourcedTitle.value
            if !hasMedia {
                titleFocused = true
                editingTime = draft.lived
            }
        }
        // A place found after the screen opened renames an untouched title.
        .onChange(of: draft.suggestedTitle) { _, new in if draft.title == nil { title = new } }
        .onChange(of: picks) { _, items in Task { await importPicks(items) } }
        .task(id: draft.center?.coordinate.latitude) { await suggest() }
        .sheet(isPresented: $choosingPlace) { PlacePicker(draft: $draft) }
        .sheet(isPresented: $explaining) { HowWeGuessed(draft: $draft) }
    }

    // MARK: Top

    /// With photos: the cover big, the rest in a strip to pick the cover from, and + for more.
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let cover = draft.cover {
                MediaThumb(asset: cover.asset, drift: false).frame(height: 330).clipped()
            }
            LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack {
                HStack {
                    Button(dismissLabel, action: onDismiss)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Space.lg)
                        .frame(minHeight: 40)
                        .background(.black.opacity(0.35), in: .capsule)
                        .buttonStyle(PressableStyle())
                    Spacer()
                    Label("Draft · on this iPhone", systemImage: "lock.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(.black.opacity(0.35), in: .capsule)
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.top, 56)
                Spacer()
            }
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(draft.shots.sorted { $0.takenAt < $1.takenAt }) { shot in
                        let isCover = shot.id == draft.cover?.id
                        Button { draft.coverId = shot.id } label: {
                            MediaThumb(asset: shot.asset, drift: false)
                                .frame(width: 46, height: 46)
                                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(.white, lineWidth: isCover ? 2 : 0)
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button("Remove", systemImage: "trash", role: .destructive) { remove(shot) }
                        }
                        .accessibilityLabel(shot.kind == .video ? "Video" : "Photo")
                        .accessibilityValue(isCover ? "Cover" : "")
                        .accessibilityHint("Makes it the cover")
                    }
                    addMediaButton {
                        Image(systemName: importing ? "hourglass" : "plus")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Theme.text)
                            .frame(width: 46, height: 46)
                            .background(.white.opacity(0.85), in: .rect(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 14)
        }
        .frame(height: 330)
        .background(Color.black)
    }

    /// Without photos: a plain bar, with a way to add some.
    private var plainTop: some View {
        HStack {
            Button(dismissLabel, action: onDismiss)
                .font(.body)
                .foregroundStyle(Theme.text)
                .frame(minHeight: 44)
            Spacer()
            Text(draft.lived ? "New Experience" : "Want to do")
                .font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Theme.textMuted)
            Spacer()
            addMediaButton {
                Image(systemName: importing ? "hourglass" : "photo.badge.plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(Theme.soft, in: .circle)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.md)
        .padding(.bottom, Theme.Space.lg)
    }

    private func addMediaButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        PhotosPicker(selection: $picks, maxSelectionCount: 30, matching: .any(of: [.images, .videos]), photoLibrary: .shared(), label: label)
            .disabled(importing)
            .accessibilityLabel("Add photos or videos")
    }

    // MARK: Title and words

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            TextField(draft.lived ? "What was it?" : "What do you want to do?", text: $title, axis: .vertical)
                .font(.display(hasMedia ? 30 : 34)).displayTracking(hasMedia ? 30 : 34)
                .foregroundStyle(Theme.text)
                .focused($titleFocused)
                .submitLabel(.done)
                .onChange(of: title) { _, t in
                    let typed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    let own = typed.isEmpty || typed == draft.suggestedTitle ? nil : t
                    if own != draft.title { draft.title = own }
                }
            if hasMedia {
                Button { explaining = true } label: {
                    Text(draft.sourcedTitle.needsEstimateLabel ? "Title suggested from the place and time (estimated)" : "How we guessed")
                        .font(.footnote).foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows how this was suggested")
            }
            if let importError { Text(importError).font(.footnote).foregroundStyle(Theme.error) }
        }
    }

    private var wordsInline: some View {
        TextField(draft.lived ? "A few words, if you like" : "A note for later", text: $draft.words, axis: .vertical)
            .font(.system(size: 18))
            .lineSpacing(4)
            .lineLimit(2...10)
            .foregroundStyle(Theme.text)
    }

    private var wordsBox: some View {
        TextField("What do you want to remember?", text: $draft.words, axis: .vertical)
            .lineLimit(2...8)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    // MARK: Rows

    private var rows: some View {
        VStack(spacing: 0) {
            if draft.lived {
                row("When", value: Text(draft.timeLabel()), muted: false, expanded: editingTime) {
                    withAnimation(Theme.Motion.short) { editingTime.toggle() }
                }
                if editingTime {
                    TimeEditor(draft: $draft)
                        .padding(.bottom, Theme.Space.md)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            row("Where", value: placeText, muted: draft.sourcedPlace == nil, expanded: false) { choosingPlace = true }
            collectionRow
            row("Kind", value: kindText, muted: draft.categories.isEmpty, expanded: showingKinds) {
                withAnimation(Theme.Motion.short) { showingKinds.toggle() }
            }
            if showingKinds {
                FlowLayout(spacing: Theme.Space.sm) {
                    ForEach(LifeCategory.allCases, id: \.self) { c in
                        Chip(label: c.label, group: c.group, isOn: draft.categories.contains(c)) {
                            var now = draft.categories
                            if let i = now.firstIndex(of: c) { now.remove(at: i) } else { now.append(c) }
                            draft.chosenCategories = now
                        }
                    }
                }
                .padding(.vertical, Theme.Space.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private var placeText: Text {
        guard let p = draft.sourcedPlace else { return Text(draft.lived ? "Add a place" : "Anywhere, for now") }
        let name = Text(p.value)
        return p.needsEstimateLabel ? name + Text(" (estimated)").fontWeight(.regular).foregroundStyle(Theme.textMuted) : name
    }

    private var kindText: Text {
        let list = draft.categories
        guard !list.isEmpty else { return Text("Optional") }
        let names = Text(list.map(\.label).joined(separator: ", "))
        return draft.chosenCategories == nil ? names + Text(" (estimated)").fontWeight(.regular).foregroundStyle(Theme.textMuted) : names
    }

    private var collectionRow: some View {
        let chosen = draft.collection.flatMap { c in c.newTitle ?? store.allCollections.first { $0.id == c.collectionId }?.title }
        return VStack(spacing: 0) {
            Menu {
                if chosen != nil { Button("None") { draft.collection = nil } }
                ForEach(store.allCollections) { c in
                    Button(c.title) { draft.collection = CollectionChoice(collectionId: c.id) }
                }
                Divider()
                Button("New collection…", systemImage: "plus") { makingCollection = true }
            } label: {
                rowLabel("In", value: Text(chosen ?? "No collection"), muted: chosen == nil, expanded: false)
            }
            .accessibilityLabel(chosen.map { "Collection: \($0)" } ?? "Collection")
            if makingCollection {
                HStack(spacing: Theme.Space.sm) {
                    TextField("Name it: Barcelona 2024, Sunday dinners…", text: $newCollection)
                        .submitLabel(.done)
                        .onSubmit(makeCollection)
                    Button("Add", action: makeCollection)
                        .font(.subheadline.weight(.semibold))
                        .disabled(newCollection.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
                .padding(.vertical, Theme.Space.sm)
            }
        }
    }

    private func row(_ label: String, value: Text, muted: Bool, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(label, value: value, muted: muted, expanded: expanded) }
            .buttonStyle(.plain)
    }

    private func rowLabel(_ label: String, value: Text, muted: Bool, expanded: Bool) -> some View {
        HStack(spacing: Theme.Space.md) {
            Text(label).font(.subheadline).foregroundStyle(Theme.textMuted).frame(width: 60, alignment: .leading)
            value
                .font(.body.weight(muted ? .regular : .semibold))
                .foregroundStyle(muted ? Theme.textMuted : Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textMuted)
                .rotationEffect(.degrees(expanded ? 180 : 0))
        }
        .frame(minHeight: 52)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    // MARK: Save

    private var saveBar: some View {
        VStack(spacing: 8) {
            Text("Only you can see this. You can share it later.")
                .font(.footnote).foregroundStyle(Theme.textMuted)
            Button(action: onSave) {
                Label("Save privately", systemImage: "lock.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.primary.opacity(draft.canSave && !importing ? 1 : 0.3),
                                in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .disabled(!draft.canSave || importing)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.top, Theme.Space.md)
        .padding(.bottom, Theme.Space.sm)
        .background(Theme.surface)
    }

    // MARK: Actions

    private func makeCollection() {
        let name = newCollection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        draft.collection = CollectionChoice(collectionId: UUID(), newTitle: name, newKind: nil)
        newCollection = ""
        makingCollection = false
    }

    private func remove(_ shot: TrayShot) {
        withAnimation(Theme.Motion.short) {
            draft.shots.removeAll { $0.id == shot.id }
            if draft.coverId == shot.id { draft.coverId = nil }
        }
        shot.discardFile()
    }

    private func importPicks(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        importing = true
        importError = nil
        let (added, failed) = await LifeMedia.importPicked(items)
        let wasEmpty = draft.shots.isEmpty
        withAnimation(Theme.Motion.short) { draft.shots += added.map { TrayShot(picked: $0, takenAt: draft.shots.last?.takenAt ?? Date()) } }
        // Photos without a date can't say when; leave the time to the person.
        if wasEmpty, !added.isEmpty, added.allSatisfy({ $0.takenAt == nil }), draft.chosenTime == nil { draft.chosenTime = .unknown }
        // Picked photos with their own dates speak for themselves, unless the person already said when.
        if wasEmpty, added.contains(where: { $0.takenAt != nil }), draft.chosenTime?.precision == .day,
           draft.chosenTime?.start.map(Calendar.current.isDateInToday) == true {
            draft.chosenTime = nil
        }
        picks = []
        importing = false
        if failed > 0 { importError = failed == 1 ? "One item couldn't be added." : "\(failed) items couldn't be added." }
    }

    /// Picked photos with a location get the same suggestions as the camera's.
    private func suggest() async {
        guard !draft.placeChosen, draft.nearby.isEmpty, let center = draft.center else { return }
        let found = await PlaceLookup.around(center)
        guard !draft.placeChosen else { return }
        draft.place = found.closest
        draft.nearby = found.nearby
        draft.area = found.area
    }
}

// MARK: - When

/// Today, yesterday, a day, something approximate, or not sure. With photos, their own time is the first choice.
private struct TimeEditor: View {
    @Binding var draft: TrayDraft

    enum Choice: Hashable { case photos, today, yesterday, day, approximate, unsure }
    enum Rough: String, CaseIterable, Identifiable {
        case month = "A month", season = "A season", year = "A year"
        var id: String { rawValue }
    }

    @State private var rough: Rough = .month
    @State private var pickedDay = Date()
    @State private var season = "Summer"
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())

    private var choice: Choice {
        guard let c = draft.chosenTime else { return draft.shots.isEmpty ? .unsure : .photos }
        guard let s = c.start else { return .unsure }
        switch c.precision {
        case .day:
            if Calendar.current.isDateInToday(s) { return .today }
            if Calendar.current.isDateInYesterday(s) { return .yesterday }
            return .day
        case .month, .season, .year: return .approximate
        default: return .day
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            FlowLayout(spacing: Theme.Space.sm) {
                if !draft.shots.isEmpty { option("From the photos", .photos) { draft.chosenTime = nil } }
                option("Today", .today) { draft.chosenTime = .day(Date()) }
                option("Yesterday", .yesterday) {
                    draft.chosenTime = .day(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
                }
                option("Another day", .day) { draft.chosenTime = .day(pickedDay) }
                option("A month, a season…", .approximate) { applyRough() }
                option("Not sure", .unsure) { draft.chosenTime = .unknown }
            }
            switch choice {
            case .day:
                DatePicker("Day", selection: $pickedDay, in: ...Date(), displayedComponents: .date)
                    .onChange(of: pickedDay) { _, d in draft.chosenTime = .day(d) }
            case .approximate:
                Picker("How exact", selection: $rough) { ForEach(Rough.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: rough) { _, _ in applyRough() }
                HStack {
                    switch rough {
                    case .month:
                        Picker("Month", selection: $month) {
                            ForEach(1...12, id: \.self) { Text(Calendar.current.monthSymbols[$0 - 1]).tag($0) }
                        }
                    case .season:
                        Picker("Season", selection: $season) {
                            ForEach(["Winter", "Spring", "Summer", "Fall"], id: \.self) { Text($0) }
                        }
                    case .year:
                        EmptyView()
                    }
                    Picker("Year", selection: $year) {
                        ForEach((1940...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                }
                .onChange(of: month) { _, _ in applyRough() }
                .onChange(of: season) { _, _ in applyRough() }
                .onChange(of: year) { _, _ in applyRough() }
            case .unsure:
                Text("It'll live under “Date unknown”. You can add a date any time.")
                    .font(.footnote).foregroundStyle(Theme.textMuted)
            default:
                EmptyView()
            }
        }
        .padding(.top, Theme.Space.xs)
        .onAppear {
            if let c = draft.chosenTime, let s = c.start {
                pickedDay = s
                year = Calendar.current.component(.year, from: s)
                month = Calendar.current.component(.month, from: s)
                rough = c.precision == .year ? .year : c.precision == .season ? .season : .month
            }
        }
    }

    private func applyRough() {
        switch rough {
        case .month: draft.chosenTime = .month(year, month)
        case .season: draft.chosenTime = .season(season, year)
        case .year: draft.chosenTime = .year(year)
        }
    }

    private func option(_ label: String, _ value: Choice, action: @escaping () -> Void) -> some View {
        let on = choice == value
        return Button {
            withAnimation(Theme.Motion.micro) { action() }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(on ? Theme.onPrimary : Theme.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(on ? Theme.primary : Theme.soft, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Where

/// Close-by places first (when the photos have a location), then search. A place that isn't on the map can just be typed.
struct PlacePicker: View {
    @Binding var draft: TrayDraft
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [DraftPlace] = []
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Theme.Space.sm) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
                        TextField("Search places", text: $query)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .focused($focused)
                    }
                }
                let typed = query.trimmingCharacters(in: .whitespaces)
                if !typed.isEmpty {
                    Section {
                        ForEach(results, id: \.self) { place($0) }
                        Button {
                            choose(DraftPlace(name: typed))
                        } label: {
                            Label("Use “\(typed)”", systemImage: "text.cursor").foregroundStyle(Theme.text)
                        }
                    }
                } else if !draft.nearby.isEmpty {
                    Section("Close to where the photos were taken") {
                        ForEach(draft.nearby, id: \.self) { place($0) }
                    }
                }
                if draft.sourcedPlace != nil {
                    Section {
                        Button("No place", role: .destructive) { choose(nil) }
                    }
                }
            }
            .navigationTitle(draft.lived ? "Where was it?" : "Where?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard q.count > 1 else { results = []; return }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                results = await PlaceLookup.search(q, near: draft.center)
            }
            .onAppear { focused = draft.nearby.isEmpty }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.sheet)
    }

    private func place(_ p: DraftPlace) -> some View {
        Button { choose(p) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                if let l = p.locality { Text(l).font(.footnote).foregroundStyle(Theme.textMuted) }
            }
        }
    }

    private func choose(_ p: DraftPlace?) {
        draft.place = p
        draft.placeChosen = true
        dismiss()
    }
}
