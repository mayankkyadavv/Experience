import ExperienceCore
import SwiftUI

/// You (left of home): your profile, laid out exactly as a visitor would see it (brief §8), direction A
/// "Shelf & mosaic" (DESIGN.md): who you are and your counts, a shelf of collections, then your Experiences
/// as a living mosaic. **Arrange** regroups the same Experiences by time, place or kind. **Preview as public**
/// shows only what a visitor may see; today, with everything private, that's your name and nothing else.
struct ProfilePage: View {
    /// Opens a listing from Discover-style rows elsewhere; kept for the home pager's detail sheet.
    let onOpen: (UUID) -> Void

    enum Tab: Hashable { case experienced, wanted }
    enum Arrangement: String, CaseIterable, Identifiable {
        case collections, time, places, kind
        var id: String { rawValue }
        var label: String {
            switch self {
            case .collections: "Collections"
            case .time: "Time"
            case .places: "Places"
            case .kind: "Kind"
            }
        }
        var detail: String {
            switch self {
            case .collections: "Your groups first, then everything"
            case .time: "Year by year, newest first"
            case .places: "Place by place; no place last"
            case .kind: "Food, music, outdoors, everyday…"
            }
        }
        var symbol: String {
            switch self {
            case .collections: "square.stack"
            case .time: "clock"
            case .places: "mappin.and.ellipse"
            case .kind: "square.grid.2x2"
            }
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(LifeStore.self) private var store
    @State private var asPublic = false
    @State private var tab: Tab = .experienced
    @AppStorage("profileArrangement") private var arrangement: Arrangement = .collections
    @State private var editing = false
    @State private var settings = false
    @State private var adding = false
    @State private var openExperience: Experience?
    @State private var openCollection: ExperienceCollection?

    private var lived: [Experience] { asPublic ? store.experienced.filter { $0.visibility == .public } : store.experienced }
    private var wants: [Experience] { asPublic ? [] : store.wants }
    private var shelf: [ExperienceCollection] { asPublic ? store.allCollections.filter { $0.visibility == .public } : store.allCollections }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                topBar
                identity
                stats
                actions
                if tab == .experienced, arrangement == .collections { shelfSection }
                tabs
                content
            }
            .padding(.bottom, Theme.Space.xl)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.load() }
        .sheet(isPresented: $editing) { EditProfileSheet() }
        .sheet(isPresented: $settings) { SettingsSheet() }
        .sheet(isPresented: $adding) { AddExperienceSheet() }
        .sheet(item: $openExperience) { LifeExperienceView(experience: $0) }
        .sheet(item: $openCollection) { c in CollectionSheet(collection: c) { e in openCollection = nil; openExperience = e } }
        .animation(Theme.Motion.short, value: asPublic)
        .animation(Theme.Motion.short, value: arrangement)
    }

    // MARK: Top

    @ViewBuilder private var topBar: some View {
        if asPublic {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "eye")
                Text("This is what others see").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Done") { asPublic = false }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, Theme.Space.lg)
            .background(Color.primary.opacity(0.07), in: .capsule)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.sm)
        } else {
            HStack {
                iconButton("plus", label: "Add an Experience") { adding = true }
                Spacer()
                iconButton("gearshape", label: "Settings") { settings = true }
            }
            .padding(.horizontal, Theme.Space.sm)
            .padding(.top, Theme.Space.xs)
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.primary.opacity(0.75))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private var identity: some View {
        let p = model.profile
        let name = p?.displayName
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Avatar(name: name ?? p?.username)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name ?? (asPublic ? "No name yet" : "Add your name"))
                        .font(.display(26))
                        .displayTracking(26)
                        .foregroundStyle(name == nil ? Color.primary.opacity(0.4) : Color.primary)
                        .accessibilityAddTraits(.isHeader)
                    let line = [p?.username.map { "@\($0)" }, model.city?.name].compactMap { $0 }
                    if !line.isEmpty {
                        Text(line.joined(separator: " · ")).font(.subheadline).foregroundStyle(Color.primary.opacity(0.55))
                    }
                }
                Spacer(minLength: 0)
            }
            if let bio = p?.bio {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if p?.isSample == true {
                // Sample data is always labelled (brief §19): this is a demo, not anyone's life.
                Label("Sample profile", systemImage: "sparkles.rectangle.stack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 26)
                    .background(Color.primary.opacity(0.08), in: .capsule)
                    .accessibilityLabel("Sample profile: placeholder Experiences for showing the app")
            }
        }
        .padding(.horizontal, Theme.Space.xl)
    }

    /// Owner: full counts. Public preview: only what's public (brief §8 count disclosure).
    @ViewBuilder private var stats: some View {
        HStack(spacing: Theme.Space.xl) {
            if asPublic {
                stat(lived.count, "public Experience\(lived.count == 1 ? "" : "s")")
            } else {
                stat(store.experiencedCount, store.experiencedCount == 1 ? "Experience" : "Experiences")
                stat(store.cityCount, store.cityCount == 1 ? "City" : "Cities")
                stat(store.wants.count, "Want")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.xl)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(value)").font(.title(19)).foregroundStyle(Color.primary).contentTransition(.numericText())
            Text(label).font(.footnote).foregroundStyle(Color.primary.opacity(0.6))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var actions: some View {
        if !asPublic {
            HStack(spacing: Theme.Space.sm) {
                pill("Edit profile") { editing = true }
                pill("Preview as public") { asPublic = true }
            }
            .padding(.horizontal, Theme.Space.xl)
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Collections shelf

    @ViewBuilder private var shelfSection: some View {
        if !shelf.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                sectionLabel("Collections").padding(.horizontal, Theme.Space.xl)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(shelf) { c in
                            Button { openCollection = c } label: { CollectionStack(collection: c) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.top, 6)
                }
                .scrollIndicators(.hidden)
            }
        } else if !asPublic, !store.experienced.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                sectionLabel("Collections")
                StartCollectionCard { adding = true }
            }
            .padding(.horizontal, Theme.Space.xl)
        }
    }

    // MARK: Tabs and arrangement

    private var tabs: some View {
        HStack(spacing: Theme.Space.xl) {
            tabButton("Experienced", .experienced)
            if !asPublic { tabButton("Want to Experience", .wanted) }
            Spacer(minLength: 0)
            if tab == .experienced { arrangeMenu }
        }
        .padding(.horizontal, Theme.Space.xl)
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        Button { withAnimation(Theme.Motion.short) { tab = value } } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(tab == value ? 1 : 0.45))
                Capsule().fill(Color.primary.opacity(tab == value ? 1 : 0)).frame(height: 2)
            }
            .fixedSize()
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }

    private var arrangeMenu: some View {
        Menu {
            Picker("Arrange by", selection: $arrangement) {
                ForEach(Arrangement.allCases) { a in
                    Label { Text(a.label); Text(a.detail) } icon: { Image(systemName: a.symbol) }.tag(a)
                }
            }
        } label: {
            // One icon that names the current arrangement; the year or place headings below make it plain.
            Image(systemName: arrangement == .collections ? "line.3.horizontal.decrease" : arrangement.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(arrangement == .collections ? Color.primary : Theme.onPrimary)
                .frame(width: 44, height: 44)
                .background(arrangement == .collections ? Color.primary.opacity(0.08) : Color.primary, in: .circle)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10)))
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel("Arrange: \(arrangement.label)")
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if asPublic && lived.isEmpty {
            VStack(spacing: Theme.Space.sm) {
                Image(systemName: "lock").font(.title3)
                Text("Nothing shared yet").font(.headline)
                Text("Your Experiences are private until you choose to share one.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color.primary.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.xxl)
            .padding(.horizontal, Theme.Space.xl)
        } else if tab == .wanted {
            if wants.isEmpty {
                empty("Keep a place for someday.", "Save something from Discover, or add an idea of your own.", action: "Add an idea")
            } else {
                Mosaic(experiences: wants) { openExperience = $0 }.padding(.horizontal, Theme.Space.xl)
            }
        } else if lived.isEmpty {
            if !store.loaded && store.pending.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 160)
            } else {
                empty("Start with something you want to remember.", "A few photos, a short thought, or just a title is enough.", action: "Add an Experience")
            }
        } else {
            switch arrangement {
            case .collections:
                Mosaic(experiences: lived) { openExperience = $0 }.padding(.horizontal, Theme.Space.xl)
            case .time:
                timeSections
            case .places:
                sections(groupedBy: { $0.placeName ?? $0.placeLocality }, missing: "No place")
            case .kind:
                sections(groupedBy: { $0.lifeCategories.first?.label }, missing: "Unsorted")
            }
        }
        if let error = store.loadError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.footnote).foregroundStyle(Color.primary.opacity(0.6))
                .padding(.horizontal, Theme.Space.xl)
        }
    }

    /// Year by year, newest first; a collection appears in the year its first Experience happened; undated last.
    private var timeSections: some View {
        let years = Dictionary(grouping: lived, by: { $0.time.year })
        let ordered = years.keys.compactMap { $0 }.sorted(by: >)
        return VStack(alignment: .leading, spacing: Theme.Space.xxl) {
            ForEach(ordered, id: \.self) { year in
                let list = years[year] ?? []
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    yearHeader(String(year), count: list.count)
                    ForEach(shelf.filter { c in store.members(of: c.id).compactMap(\.time.year).min() == year }) { c in
                        Button { openCollection = c } label: { CollectionWideCard(collection: c) }.buttonStyle(PressableStyle())
                    }
                    Mosaic(experiences: list) { openExperience = $0 }
                }
                .padding(.horizontal, Theme.Space.xl)
            }
            if let undated = years[nil], !undated.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    yearHeader("Date unknown", count: undated.count, small: true)
                    Mosaic(experiences: undated) { openExperience = $0 }
                }
                .padding(.horizontal, Theme.Space.xl)
            }
        }
    }

    private func sections(groupedBy key: @escaping (Experience) -> String?, missing: String) -> some View {
        let groups = Dictionary(grouping: lived, by: key)
        let named = groups.keys.compactMap { $0 }.sorted { (groups[$0]?.count ?? 0, $1) > (groups[$1]?.count ?? 0, $0) }
        return VStack(alignment: .leading, spacing: Theme.Space.xxl) {
            ForEach(named, id: \.self) { name in
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    yearHeader(name, count: groups[name]?.count ?? 0, small: true)
                    Mosaic(experiences: groups[name] ?? []) { openExperience = $0 }
                }
            }
            if let rest = groups[nil], !rest.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    yearHeader(missing, count: rest.count, small: true)
                    Mosaic(experiences: rest) { openExperience = $0 }
                }
            }
        }
        .padding(.horizontal, Theme.Space.xl)
    }

    private func yearHeader(_ title: String, count: Int, small: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.display(small ? 26 : 40))
                .displayTracking(small ? 26 : 40)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
            Text("\(count) Experience\(count == 1 ? "" : "s")").font(.footnote).foregroundStyle(Color.primary.opacity(0.55))
        }
    }

    private func empty(_ title: String, _ detail: String, action: String) -> some View {
        VStack(spacing: Theme.Space.md) {
            Text(title).font(.title(21)).displayTracking(21).foregroundStyle(Color.primary).multilineTextAlignment(.center)
            Text(detail).font(.subheadline).foregroundStyle(Color.primary.opacity(0.55)).multilineTextAlignment(.center)
            Button { adding = true } label: {
                Label(action, systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, Theme.Space.xl)
                    .frame(minHeight: 48)
                    .background(Theme.primary, in: .capsule)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, Theme.Space.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xxl)
        .padding(.horizontal, Theme.Space.xl)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Color.primary.opacity(0.5))
    }
}

// MARK: - Avatar

/// Initials on a soft disc until photos can be uploaded; a person symbol when there's no name.
private struct Avatar: View {
    let name: String?

    private var initials: String {
        let parts = (name ?? "").split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.primary.opacity(0.08))
            Circle().strokeBorder(Color.primary.opacity(0.10))
            if initials.isEmpty {
                Image(systemName: "person.fill").font(.system(size: 26)).foregroundStyle(Color.primary.opacity(0.35))
            } else {
                Text(initials).font(.display(24)).displayTracking(24).foregroundStyle(Color.primary)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}

// MARK: - Row

/// One listing in a home list (Discover): category dot, title (estimates labelled), one line of detail.
struct HomeRow: View {
    let item: CatalogItem
    let detail: String
    var saved = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Circle().fill(item.category.group.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                SourcedText(item.sourcedTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(Color.primary.opacity(0.55)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if saved {
                Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Color.primary.opacity(0.7))
                    .accessibilityLabel("Saved")
            }
        }
        .frame(minHeight: 52)
        .contentShape(.rect)
    }
}
