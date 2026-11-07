import ExperienceCore
import Photos
import PhotosUI
import SwiftUI

/// Bring in past Experiences from Photos: ask in context, choose albums, then keep what's right. Each album becomes a
/// collection, split on this phone into Experiences by day and place. They link to the photos where they already
/// are; nothing is copied, and everything is Private.
struct ImportFlow: View {
    /// Called when the person is done, with how many Experiences they kept.
    let onDone: (Int) -> Void

    @Environment(LifeStore.self) private var store
    @Environment(\.openURL) private var openURL

    enum Step { case start, albums, review }
    @State private var step: Step = .start
    @State private var status = PhotoLibrary.status
    @State private var albums: [PhotoLibrary.Album] = []
    @State private var chosen: Set<String> = []
    @State private var loadingAlbums = false
    /// Albums still to review, in order; the first is on screen.
    @State private var queue: [PhotoLibrary.Album] = []
    @State private var reviewTitle = ""
    @State private var reviewCollection: CollectionChoice?
    @State private var drafts: [TrayDraft] = []
    @State private var skipped: Set<UUID> = []
    @State private var grouping = false
    @State private var editing: EditTarget?
    @State private var picks: [PhotosPickerItem] = []
    @State private var kept = 0

    private struct EditTarget: Identifiable { let id: UUID }

    var body: some View {
        Group {
            switch step {
            case .start: start
            case .albums: albumList
            case .review: review
            }
        }
        .background(Theme.surface)
        .animation(Theme.Motion.short, value: step)
        .onChange(of: picks) { _, items in pickedYourself(items) }
        .fullScreenCover(item: $editing) { target in
            if let i = drafts.firstIndex(where: { $0.id == target.id }) {
                DraftView(draft: $drafts[i], dismissLabel: "Done", onDismiss: { editing = nil }) {
                    keepOne(target.id)
                    editing = nil
                }
            }
        }
    }

    // MARK: 1 · Ask in context

    private var start: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CloseButton { onDone(kept) }
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.md)

            ZStack {
                printCard(-9, x: -95, y: 20, colors: [Color(uiColor: UIColor(rgb: 0x9FC29A)), Color(uiColor: UIColor(rgb: 0x3E6B44))])
                printCard(8, x: 95, y: 10, colors: [Color(uiColor: UIColor(rgb: 0xB8C9D9)), Color(uiColor: UIColor(rgb: 0x4F6378))])
                printCard(0, x: 0, y: -10, colors: [Color(uiColor: UIColor(rgb: 0xE8B07A)), Color(uiColor: UIColor(rgb: 0x8A4E2A))], big: true)
            }
            .frame(height: 230)
            .padding(.top, Theme.Space.lg)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text("Bring in your past").font(.display(32)).displayTracking(32).foregroundStyle(Theme.text)
                Text("We'll look through your photos on this iPhone and suggest past Experiences, grouped by day and place. You choose what to keep. Everything stays Private.")
                    .font(.body).foregroundStyle(Theme.text.opacity(0.8)).lineSpacing(3)
                if status == .denied || status == .restricted {
                    Text("Photos access is off for Experiences. Turn it on in Settings to bring in your past.")
                        .font(.subheadline).foregroundStyle(Theme.error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.xl)

            Spacer(minLength: Theme.Space.lg)

            VStack(spacing: 10) {
                if status == .denied || status == .restricted {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.primary)
                } else {
                    Button(action: openAlbums) {
                        if loadingAlbums { ProgressView().tint(Theme.onPrimary) } else { Text("Start with my albums") }
                    }
                    .buttonStyle(.primary)
                    .disabled(loadingAlbums)
                    PhotosPicker(selection: $picks, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                        Text("Pick photos myself")
                            .font(.subheadline.weight(.semibold))
                            .underline()
                            .foregroundStyle(Theme.text)
                            .frame(minHeight: 44)
                    }
                }
                Text("iPhone asks for access next. Your photos stay in your library; Experiences point to them. Change access anytime in Settings.")
                    .font(.caption).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.lg)
        }
    }

    private func printCard(_ angle: Double, x: CGFloat, y: CGFloat, colors: [Color], big: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: big ? 130 : 120, height: big ? 165 : 150)
            .shadow(color: .black.opacity(big ? 0.2 : 0.15), radius: big ? 20 : 15, y: big ? 20 : 16)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
    }

    private func openAlbums() {
        Task {
            loadingAlbums = true
            if PhotoLibrary.status == .notDetermined { status = await PhotoLibrary.requestAccess() } else { status = PhotoLibrary.status }
            if PhotoLibrary.canRead {
                #if LOCAL_BACKEND && targetEnvironment(simulator)
                await PhotoLibrary.seedTestAlbum()
                #endif
                albums = await Task.detached { PhotoLibrary.albums() }.value
                step = .albums
            }
            loadingAlbums = false
        }
    }

    /// Photos chosen one by one: grouped the same way, into no collection.
    private func pickedYourself(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let ids = items.compactMap(\.itemIdentifier)
        picks = []
        Task {
            if PhotoLibrary.status == .notDetermined { status = await PhotoLibrary.requestAccess() }
            guard PhotoLibrary.canRead else { status = PhotoLibrary.status; return }
            queue = []
            await beginReview(title: "Your picks", assets: PhotoLibrary.assets(ids), collection: nil)
        }
    }

    // MARK: 2 · Your albums

    private var albumList: some View {
        VStack(spacing: 0) {
            HStack {
                Button(chosen.count == albums.count && !albums.isEmpty ? "Select none" : "Select all") {
                    chosen = chosen.count == albums.count ? [] : Set(albums.map(\.id))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
                .frame(minHeight: 44)
                Spacer()
                CloseButton { onDone(kept) }
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.md)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your albums").font(.display(30)).displayTracking(30).foregroundStyle(Theme.text)
                        Text("Each album becomes a collection. We split it into Experiences by day and place.")
                            .font(.subheadline).foregroundStyle(Theme.textMuted)
                        if status == .limited {
                            Text("Experiences can see only the photos you've shared with it. Change that in Settings.")
                                .font(.footnote).foregroundStyle(Theme.textMuted)
                        }
                    }
                    if albums.isEmpty {
                        Text("No albums here yet. Pick photos yourself instead, or make an album in Photos.")
                            .font(.body).foregroundStyle(Theme.textMuted)
                            .padding(.top, Theme.Space.xl)
                    }
                    VStack(spacing: 10) {
                        ForEach(albums) { album in albumRow(album) }
                    }
                }
                .padding(.horizontal, Theme.Space.xl)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, Theme.Space.xl)
            }

            VStack(spacing: 8) {
                Text("Grouped on this iPhone. Place names come from Apple Maps.")
                    .font(.footnote).foregroundStyle(Theme.textMuted)
                Button(chosen.count == 1 ? "Group 1 album" : "Group \(chosen.count) albums") {
                    queue = albums.filter { chosen.contains($0.id) }
                    Task { await nextAlbum() }
                }
                .buttonStyle(.primary)
                .disabled(chosen.isEmpty)
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.md)
            .padding(.bottom, Theme.Space.sm)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
    }

    private func albumRow(_ album: PhotoLibrary.Album) -> some View {
        let on = chosen.contains(album.id)
        return Button {
            if on { chosen.remove(album.id) } else { chosen.insert(album.id) }
        } label: {
            HStack(spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(album.title).font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    Text("\(album.count) \(album.count == 1 ? "item" : "items")\(Self.span(album).map { " · \($0)" } ?? "")")
                        .font(.footnote).foregroundStyle(Theme.textMuted)
                    Text("About \(album.estimate) \(album.estimate == 1 ? "Experience" : "Experiences") (estimated)")
                        .font(.footnote).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(on ? Theme.primary : Theme.textMuted)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(Theme.Space.lg)
            .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? Theme.primary : Theme.hairline, lineWidth: on ? 1.5 : 1))
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }

    /// "Apr 2024", or "2023 – 2025" for an album that spans years.
    static func span(_ album: PhotoLibrary.Album) -> String? {
        guard let first = album.first, let last = album.last else { return nil }
        let cal = Calendar.current
        if cal.component(.year, from: first) != cal.component(.year, from: last) {
            return "\(cal.component(.year, from: first)) – \(cal.component(.year, from: last))"
        }
        if cal.component(.month, from: first) != cal.component(.month, from: last) {
            return "\(first.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
        }
        return first.formatted(.dateTime.month(.abbreviated).year())
    }

    // MARK: 3 · Keep what's right

    private func nextAlbum() async {
        guard let album = queue.first else { onDone(kept); return }
        let existing = store.allCollections.first { $0.title.caseInsensitiveCompare(album.title) == .orderedSame }
        let collection = existing.map { CollectionChoice(collectionId: $0.id) }
            ?? CollectionChoice(collectionId: UUID(), newTitle: album.title, newKind: nil)
        await beginReview(title: album.title, assets: PhotoLibrary.assets(inAlbum: album.id), collection: collection)
    }

    private func beginReview(title: String, assets: [PHAsset], collection: CollectionChoice?) async {
        reviewTitle = title
        reviewCollection = collection
        skipped = []
        grouping = true
        step = .review
        let shots = PhotoLibrary.shots(assets, skipping: store.linkedRefs)
        drafts = PhotoLibrary.group(shots).map { var d = $0; d.collection = collection; return d }
        grouping = false
        await lookUpPlaces()
    }

    /// One place lookup at a time, so Apple Maps isn't flooded; rows fill in as answers arrive.
    private func lookUpPlaces() async {
        for id in drafts.map(\.id) {
            guard let d = drafts.first(where: { $0.id == id }), !d.placeChosen, let center = d.center else { continue }
            let found = await PlaceLookup.around(center)
            guard let i = drafts.firstIndex(where: { $0.id == id }), !drafts[i].placeChosen else { continue }
            drafts[i].place = found.closest
            drafts[i].nearby = found.nearby
            drafts[i].area = found.area
            try? await Task.sleep(for: .milliseconds(250))
            guard step == .review else { return }
        }
    }

    private var keeping: [TrayDraft] { drafts.filter { !skipped.contains($0.id) } }

    private var review: some View {
        VStack(spacing: 0) {
            HStack {
                Text(reviewCollection == nil ? reviewTitle : "\(reviewTitle) · collection")
                    .font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Theme.textMuted).lineLimit(1)
                Spacer()
                Button("Later") { onDone(kept) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .frame(minHeight: 44)
            }
            .padding(.leading, Theme.Space.xl)
            .padding(.trailing, Theme.Space.lg)
            .padding(.top, Theme.Space.md)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline).font(.display(30)).displayTracking(30).foregroundStyle(Theme.text)
                        Text(drafts.isEmpty ? "Everything here is already in your Experiences." : "Untick what isn't one. Tap one to rename it or fix the details.")
                            .font(.subheadline).foregroundStyle(Theme.textMuted)
                    }
                    .padding(.horizontal, Theme.Space.sm)
                    .padding(.bottom, Theme.Space.md)

                    ForEach(days, id: \.day) { day in
                        Text(dayLabel(day.drafts))
                            .font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, Theme.Space.sm)
                            .padding(.top, 6)
                        ForEach(day.drafts) { reviewRow($0) }
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.bottom, Theme.Space.xl)
            }
            .overlay { if grouping { ProgressView("Grouping on this iPhone…") } }

            VStack(spacing: 8) {
                Text(footnote).font(.footnote).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
                Button(action: keepAll) {
                    Text(keepLabel)
                }
                .buttonStyle(.primary)
                .disabled(grouping)
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.md)
            .padding(.bottom, Theme.Space.sm)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
        .sensoryFeedback(.success, trigger: kept)
    }

    private var headline: String {
        if grouping { return "Grouping…" }
        switch drafts.count {
        case 0: return "Nothing new here"
        case 1: return "One Experience found"
        default: return "\(drafts.count) Experiences found"
        }
    }

    private var footnote: String {
        let where_ = reviewCollection == nil ? "" : ", in \(reviewTitle)"
        return "They'll be Private\(where_). Photos stay in your library; nothing is copied."
    }

    private var keepLabel: String {
        if drafts.isEmpty || keeping.isEmpty { return queue.count > 1 ? "Next album" : "Done" }
        return keeping.count == 1 ? "Keep 1 Experience" : "Keep \(keeping.count) Experiences"
    }

    private var days: [(day: Date, drafts: [TrayDraft])] {
        let byDay = Dictionary(grouping: drafts) { Calendar.current.startOfDay(for: $0.start) }
        return byDay.keys.sorted().map { ($0, byDay[$0]!.sorted { $0.start < $1.start }) }
    }

    private func dayLabel(_ list: [TrayDraft]) -> String {
        guard let first = list.first else { return "" }
        let date = first.start.formatted(.dateTime.weekday(.abbreviated).month(.wide).day().year())
        return first.area.map { "\(date) · \($0)" } ?? date
    }

    private func reviewRow(_ draft: TrayDraft) -> some View {
        let on = !skipped.contains(draft.id)
        return HStack(spacing: Theme.Space.md) {
            Button { editing = EditTarget(id: draft.id) } label: {
                HStack(spacing: Theme.Space.md) {
                    collage(draft)
                    VStack(alignment: .leading, spacing: 3) {
                        SourcedText(draft.sourcedTitle).font(.body.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(2)
                        HStack(spacing: 0) {
                            Text(draft.partOfDay)
                            // A title that already names the place gets the neighborhood here instead.
                            if let place = draft.sourcedTitle.value.contains(draft.place?.name ?? "\u{0}")
                                ? draft.area.map({ Sourced($0, Provenance.estimated) }) : draft.sourcedPlace {
                                Text(" · ")
                                SourcedText(place)
                            }
                        }
                        .font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
                        Text(draft.countLabel).font(.footnote).foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens it to rename or fix")

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
        .padding(10)
        .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
        .opacity(on ? 1 : 0.55)
    }

    /// One picture, or four squares with a count for the rest.
    private func collage(_ draft: TrayDraft) -> some View {
        let shots = Array(draft.shots.prefix(4))
        return Group {
            if shots.count < 4 {
                if let cover = draft.cover { MediaThumb(asset: cover.asset, drift: false) } else { Theme.soft }
            } else {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow {
                        MediaThumb(asset: shots[0].asset, drift: false)
                        MediaThumb(asset: shots[1].asset, drift: false)
                    }
                    GridRow {
                        MediaThumb(asset: shots[2].asset, drift: false)
                        if draft.shots.count > 4 {
                            ZStack {
                                Theme.primary
                                Text("+\(draft.shots.count - 3)").font(.caption.weight(.bold)).foregroundStyle(Theme.onPrimary)
                            }
                        } else {
                            MediaThumb(asset: shots[3].asset, drift: false)
                        }
                    }
                }
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(.rect(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    // MARK: Keeping

    private func keepOne(_ id: UUID) {
        guard let i = drafts.firstIndex(where: { $0.id == id }), let saving = drafts[i].saving() else { return }
        store.save(saving.draft, media: saving.media, collection: saving.collection)
        drafts.remove(at: i)
        kept += 1
    }

    private func keepAll() {
        for d in keeping {
            guard let saving = d.saving() else { continue }
            store.save(saving.draft, media: saving.media, collection: saving.collection)
            kept += 1
        }
        drafts = []
        if !queue.isEmpty { queue.removeFirst() }
        if queue.isEmpty { onDone(kept) } else { Task { await nextAlbum() } }
    }
}
