import ExperienceCore
import SwiftUI

/// Filters for Explore: the six color groups plus the user's saved list.
enum ExploreFilter: Hashable {
    case all, group(CategoryGroup), saved

    var label: String {
        switch self {
        case .all: "All"
        case .group(let g): g.label
        case .saved: "Saved"
        }
    }
}

/// The whole city catalog in the home panel: filter chips, search, and a list that mirrors the map.
struct ExploreContent: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationProvider.self) private var location
    let items: [CatalogItem]
    @Binding var filter: ExploreFilter
    @Binding var query: String
    let onSelect: (CatalogItem) -> Void
    let onClose: () -> Void

    private let filters: [ExploreFilter] = [.all] + CategoryGroup.allCases.map { .group($0) } + [.saved]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explore \(model.city?.name ?? "")").font(.display(24)).displayTracking(24).foregroundStyle(Theme.text)
                    Text(countLabel).monoLabel()
                }
                Spacer()
                CloseButton(action: onClose)
            }
            .padding(.leading, Theme.Space.xl)
            .padding(.trailing, Theme.Space.sm)

            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
                TextField("Search places, neighborhoods, vibes", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted) }
                        .accessibilityLabel("Clear search")
                }
            }
            .font(.body)
            .padding(.horizontal, Theme.Space.md)
            .frame(minHeight: 44)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            .padding(.horizontal, Theme.Space.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { f in
                        Chip(label: f.label, group: groupOf(f), isOn: filter == f) {
                            withAnimation(Theme.Motion.short) { filter = f }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.xl)
            }

            list
        }
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.md)
    }

    private var countLabel: String {
        if model.cityCatalog.isEmpty { return model.catalogError ?? "Loading…" }
        return items.count == 1 ? "1 thing" : "\(items.count) things"
    }

    private func groupOf(_ f: ExploreFilter) -> CategoryGroup? {
        if case .group(let g) = f { return g }
        return nil
    }

    @ViewBuilder private var list: some View {
        if items.isEmpty && !model.cityCatalog.isEmpty {
            Text(filter == .saved ? "Nothing saved yet. Tap the bookmark on anything you'd like to do." : "Nothing matches. Try another word or filter.")
                .font(.subheadline).foregroundStyle(Theme.textMuted)
                .padding(.horizontal, Theme.Space.xl)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        Button { onSelect(item) } label: {
                            ExploreRow(item: item, saved: model.states[item.id]?.isSaved == true,
                                       minutes: item.coordinate.flatMap { location.travelMinutes(to: $0.lat, $0.lng) })
                        }
                            .buttonStyle(PressableStyle())
                        Divider().overlay(Theme.hairline).padding(.leading, Theme.Space.xl + 18)
                    }
                }
            }
            .frame(height: 280)
            .scrollDismissesKeyboard(.immediately)
        }
    }
}

private struct ExploreRow: View {
    let item: CatalogItem
    let saved: Bool
    /// Rough travel estimate from the user's location; labelled as an estimate.
    let minutes: Int?

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Circle().fill(item.category.group.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                SourcedText(item.sourcedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text([minutes.map { "~\($0) min (estimated)" }, item.place?.neighborhood, item.subcategory, item.price].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
            if saved { Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(CategoryGroup.activity.color) }
            if item.coordinate == nil {
                Image(systemName: "mappin.slash").font(.caption).foregroundStyle(Theme.textMuted)
                    .accessibilityLabel("No fixed place")
            }
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
