import CoreTransferable
import ExperienceCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Add an Experience (brief §6): photos or videos, a few words, or nothing but a title. Everything but
/// something recognizable is optional. Saves on this phone first; the upload follows.
struct AddExperienceSheet: View {
    @Environment(LifeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum When: String, CaseIterable, Identifiable {
        case day, month, season, year, unsure
        var id: String { rawValue }
        var label: String {
            switch self {
            case .day: "A day"
            case .month: "A month"
            case .season: "A season"
            case .year: "A year"
            case .unsure: "Not sure"
            }
        }
    }

    @State private var lived = true
    @State private var title = ""
    @State private var words = ""
    @State private var place = ""
    @State private var when: When = .day
    @State private var date = Date()
    @State private var season = "Summer"
    @State private var dateFromPhotos = false
    @State private var categories: Set<LifeCategory> = []
    @State private var picks: [PhotosPickerItem] = []
    @State private var media: [PendingMedia] = []
    @State private var importing = false
    @State private var importError: String?
    @State private var collection: UUID?
    @State private var newCollection = ""
    @State private var makingCollection = false
    @FocusState private var titleFocused: Bool

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty || !media.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    Picker("Kind", selection: $lived) {
                        Text("I lived it").tag(true)
                        Text("I want to").tag(false)
                    }
                    .pickerStyle(.segmented)

                    mediaStrip

                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        TextField(lived ? "What was it?" : "What do you want to do?", text: $title, axis: .vertical)
                            .font(.title(26))
                            .displayTracking(26)
                            .focused($titleFocused)
                            .submitLabel(.done)
                        TextField(lived ? "A few words, if you like" : "A note for later", text: $words, axis: .vertical)
                            .font(.body)
                            .lineLimit(2...6)
                    }

                    if lived { whenSection }

                    field("Where", systemImage: "mappin") {
                        TextField("Optional", text: $place)
                    }

                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        sectionLabel("Kind of thing")
                        FlowLayout(spacing: 8) {
                            ForEach(LifeCategory.allCases, id: \.self) { c in
                                Chip(label: c.label, group: c.group, isOn: categories.contains(c)) {
                                    if categories.contains(c) { categories.remove(c) } else { categories.insert(c) }
                                }
                            }
                        }
                    }

                    collectionSection
                }
                .padding(Theme.Space.xl)
                .padding(.bottom, 90)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(lived ? "Add an Experience" : "Want to Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: picks) { _, items in Task { await importPicks(items) } }
            .onAppear { titleFocused = true }
        }
    }

    // MARK: Media

    private var mediaStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $picks, maxSelectionCount: 30, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                    VStack(spacing: 6) {
                        Image(systemName: importing ? "hourglass" : "photo.on.rectangle.angled").font(.title2)
                        Text(media.isEmpty ? "Photos or videos" : "Add more").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .frame(width: 104, height: 128)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    }
                }
                .accessibilityLabel("Add photos or videos")
                ForEach(media, id: \.clientId) { m in
                    MediaThumb(asset: MediaAsset(id: m.clientId, experienceId: m.clientId, clientId: m.clientId, kind: m.kind, position: 0,
                                                 caption: nil, altText: nil, takenAt: m.takenAt, durationSeconds: m.duration, width: m.width,
                                                 height: m.height, originalPath: nil, thumbPath: nil, deviceFile: m.fileName, status: .onDevice),
                               drift: false)
                        .frame(width: 96, height: 128)
                        .clipShape(.rect(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button { media.removeAll { $0.clientId == m.clientId } } label: {
                                Image(systemName: "xmark.circle.fill").font(.title3).symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.5))
                            }
                            .padding(4)
                            .accessibilityLabel("Remove")
                        }
                }
            }
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottomLeading) {
            if let importError {
                Text(importError).font(.caption).foregroundStyle(Theme.error).offset(y: 22)
            }
        }
    }

    /// Copies each picked file into the app's originals, untouched, and reads when it was taken.
    private func importPicks(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        importing = true
        importError = nil
        var failed = 0
        for item in items {
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let clientId = UUID()
            do {
                let url: URL
                if isVideo {
                    guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { failed += 1; continue }
                    url = movie.url
                } else {
                    guard let data = try await item.loadTransferable(type: Data.self) else { failed += 1; continue }
                    let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                    url = LifeFiles.original("\(clientId.uuidString.lowercased()).\(ext)")
                    try data.write(to: url, options: .atomic)
                }
                let facts = await LifeMedia.facts(of: url, kind: isVideo ? .video : .photo)
                media.append(PendingMedia(clientId: clientId, kind: facts.kind, fileName: url.lastPathComponent, takenAt: facts.takenAt,
                                          duration: facts.duration, width: facts.width, height: facts.height, contentType: facts.contentType))
            } catch {
                failed += 1
            }
        }
        picks = []
        importing = false
        if failed > 0 { importError = failed == 1 ? "One item couldn't be added." : "\(failed) items couldn't be added." }
        // Propose the day from the photos themselves, marked as coming from them; the person can change it.
        if let earliest = media.compactMap(\.takenAt).min(), lived, !dateFromPhotos || when == .day {
            date = earliest
            when = .day
            dateFromPhotos = true
        }
    }

    // MARK: When

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            sectionLabel("When")
            Picker("Precision", selection: $when) {
                ForEach(When.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: when) { _, _ in dateFromPhotos = false }
            Group {
                switch when {
                case .day:
                    DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                case .month:
                    DatePicker("Month", selection: $date, in: ...Date(), displayedComponents: .date)
                    Text("Only the month and year are kept.").font(.caption).foregroundStyle(Color.primary.opacity(0.5))
                case .season:
                    HStack {
                        Picker("Season", selection: $season) {
                            ForEach(["Winter", "Spring", "Summer", "Fall"], id: \.self) { Text($0) }
                        }
                        Picker("Year", selection: yearBinding) {
                            ForEach((1940...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                case .year:
                    Picker("Year", selection: yearBinding) {
                        ForEach((1940...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                case .unsure:
                    Text("It'll live under “Date unknown”. You can add a date any time.")
                        .font(.footnote).foregroundStyle(Color.primary.opacity(0.55))
                }
            }
            .font(.body)
            if dateFromPhotos, when == .day {
                Label("From your photos", systemImage: "photo").font(.caption).foregroundStyle(Color.primary.opacity(0.5))
            }
        }
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { Calendar.current.component(.year, from: date) },
                set: { y in date = Calendar.current.date(from: DateComponents(year: y, month: Calendar.current.component(.month, from: date), day: 1)) ?? date })
    }

    /// The draft's time: approximate stays approximate ("Summer 2021" is June 1 to August 31, precision season).
    private func time() -> (start: Date?, end: Date?, precision: TimePrecision) {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        switch when {
        case .unsure:
            return (nil, nil, .unknown)
        case .day:
            return (cal.startOfDay(for: date), nil, .day)
        case .month:
            let start = cal.date(from: DateComponents(year: y, month: cal.component(.month, from: date), day: 1))!
            return (start, cal.date(byAdding: DateComponents(month: 1, second: -1), to: start), .month)
        case .year:
            let start = cal.date(from: DateComponents(year: y, month: 1, day: 1))!
            return (start, cal.date(byAdding: DateComponents(year: 1, second: -1), to: start), .year)
        case .season:
            let first = ["Winter": 12, "Spring": 3, "Summer": 6, "Fall": 9][season]!
            let start = cal.date(from: DateComponents(year: first == 12 ? y - 1 : y, month: first, day: 1))!
            return (start, cal.date(byAdding: DateComponents(month: 3, second: -1), to: start), .season)
        }
    }

    // MARK: Collection

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            sectionLabel("Collection")
            Menu {
                Button("None") { collection = nil; makingCollection = false }
                ForEach(store.allCollections) { c in
                    Button(c.title) { collection = c.id; makingCollection = false }
                }
                Divider()
                Button("New collection…", systemImage: "plus") { collection = nil; makingCollection = true }
            } label: {
                HStack {
                    Image(systemName: "square.stack")
                    Text(makingCollection ? "New collection" : store.allCollections.first { $0.id == collection }?.title ?? "None")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .font(.body)
                .foregroundStyle(Color.primary)
                .padding(.horizontal, Theme.Space.md)
                .frame(minHeight: 48)
                .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            if makingCollection {
                TextField("Name it: Barcelona 2024, Sunday dinners…", text: $newCollection)
                    .padding(.horizontal, Theme.Space.md)
                    .frame(minHeight: 48)
                    .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            }
        }
    }

    // MARK: Save

    private var saveBar: some View {
        VStack(spacing: 6) {
            Button(action: save) {
                Label("Save privately", systemImage: "lock.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.primary.opacity(canSave ? 1 : 0.3), in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .disabled(!canSave || importing)
            Text("Only you can see it. You can share it later.")
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.5))
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.md)
        .background(.bar)
    }

    private func save() {
        let t = lived ? time() : (start: nil, end: nil, precision: TimePrecision.unknown)
        var provenance: [String: Provenance] = [:]
        if t.start != nil { provenance["time"] = dateFromPhotos && when == .day ? .source : .user }
        var name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            // A neutral, editable title when only media was given (brief §5). It names the day, nothing more.
            name = t.start.map { ExperienceTime(start: $0, precision: t.precision, timezone: TimeZone.current.identifier).label() } ?? "A moment"
            provenance["title"] = t.start != nil && dateFromPhotos ? .source : .user
        }
        let trimmedWords = words.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = ExperienceDraft(title: name, description: trimmedWords.isEmpty ? nil : trimmedWords,
                                    state: lived ? .experienced : .want, startsAt: t.start, endsAt: t.end, precision: t.precision,
                                    timezone: t.start == nil ? nil : TimeZone.current.identifier,
                                    placeName: trimmedPlace.isEmpty ? nil : trimmedPlace,
                                    categories: categories.map(\.rawValue).sorted(), provenance: provenance)
        let newName = newCollection.trimmingCharacters(in: .whitespacesAndNewlines)
        let choice: CollectionChoice? = if makingCollection, !newName.isEmpty {
            CollectionChoice(collectionId: UUID(), newTitle: newName, newKind: nil)
        } else {
            collection.map { CollectionChoice(collectionId: $0) }
        }
        store.save(draft, media: media, collection: choice)
        dismiss()
    }

    // MARK: Bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Color.primary.opacity(0.5))
    }

    private func field<Content: View>(_ label: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            sectionLabel(label)
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: systemImage).foregroundStyle(Color.primary.opacity(0.5))
                content()
            }
            .padding(.horizontal, Theme.Space.md)
            .frame(minHeight: 48)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
        }
    }
}

extension CollectionChoice {
    init(collectionId: UUID) { self.init(collectionId: collectionId, newTitle: nil, newKind: nil) }
}

/// A picked video, copied into the app's originals as soon as the picker hands it over.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = LifeFiles.original("\(UUID().uuidString.lowercased()).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}
