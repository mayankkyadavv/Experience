import ExperienceCore
import SwiftUI

/// Discover (right of home): things you could do in your city, from the curated catalog, and what you've saved.
/// These are listings, not anyone's memories (brief §10); estimates stay labelled.
struct DiscoverPage: View {
    let onOpen: (UUID) -> Void

    @Environment(AppModel.self) private var model
    @State private var filter: ExploreFilter = .all

    private let filters: [ExploreFilter] = [.all] + CategoryGroup.allCases.map { .group($0) } + [.saved]

    private var items: [CatalogItem] {
        switch filter {
        case .all: model.cityCatalog
        case .group(let g): model.cityCatalog.filter { $0.category.group == g }
        case .saved: model.wanted.map(\.0)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.lg, pinnedViews: []) {
                PageHeader(title: "Discover", subtitle: model.city.map { "Things you could do in \($0.name)" })

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { f in
                            Chip(label: f.label, group: groupOf(f), isOn: filter == f) {
                                withAnimation(Theme.Motion.short) { filter = f }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.xl)
                }
                .scrollIndicators(.hidden)

                content
                    .padding(.horizontal, Theme.Space.xl)
            }
            .padding(.bottom, Theme.Space.xl)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder private var content: some View {
        if model.cityCatalog.isEmpty {
            if let error = model.catalogError {
                note(error, symbol: "exclamationmark.triangle")
            } else {
                HStack(spacing: Theme.Space.sm) {
                    ProgressView()
                    Text("Loading ideas…").font(.subheadline).foregroundStyle(Color.primary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        } else if items.isEmpty {
            note(filter == .saved ? "Nothing saved yet. Tap the bookmark on anything you'd like to do." : "Nothing here yet.", symbol: "bookmark")
        } else {
            ForEach(items) { item in
                Button { onOpen(item.id) } label: {
                    HomeRow(item: item,
                            detail: [item.place?.neighborhood, item.subcategory, item.price].compactMap { $0 }.joined(separator: " · "),
                            saved: model.states[item.id]?.isSaved == true)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func note(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(Color.primary.opacity(0.6))
            .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func groupOf(_ f: ExploreFilter) -> CategoryGroup? {
        if case .group(let g) = f { return g }
        return nil
    }
}
