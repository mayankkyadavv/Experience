import ExperienceCore
import SwiftUI

extension ExperienceCollection.Kind {
    var label: String {
        switch self {
        case .trip: "Trip"
        case .event: "Event"
        case .season: "Season"
        case .person: "Person"
        case .place: "Place"
        case .ritual: "Ritual"
        case .other: "Collection"
        }
    }

    var symbol: String {
        switch self {
        case .trip: "airplane"
        case .event: "sparkles"
        case .season: "leaf"
        case .person: "person.2"
        case .place: "mappin"
        case .ritual: "repeat"
        case .other: "square.stack"
        }
    }
}

extension LifeStore {
    /// "12 Experiences · June 2024" / "9 Experiences · 2023–25" / "1 Experience": counted from its members' own times.
    func summary(of c: ExperienceCollection) -> String {
        let members = members(of: c.id)
        let count = "\(members.count) Experience\(members.count == 1 ? "" : "s")"
        let years = members.compactMap(\.time.year)
        guard let lo = years.min(), let hi = years.max() else { return count }
        if lo != hi { return "\(count) · \(lo)–\(String(hi).suffix(2))" }
        let months = Set(members.compactMap { e -> Int? in
            guard let s = e.startsAt, [.exact, .day, .month].contains(e.timePrecision) else { return nil }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = e.timezone.flatMap(TimeZone.init(identifier:)) ?? .current
            return cal.component(.month, from: s)
        })
        if months.count == 1, let m = months.first {
            return "\(count) · \(Calendar.current.standaloneMonthSymbols[m - 1]) \(lo)"
        }
        return "\(count) · \(lo)"
    }

    /// Up to three covers from its members, for the fanned stack and mosaics.
    func covers(of c: ExperienceCollection) -> [MediaAsset] {
        var out: [MediaAsset] = []
        if let chosen = c.coverMediaId, let m = members(of: c.id).lazy.flatMap({ self.mediaFor($0.id) }).first(where: { $0.id == chosen }) {
            out.append(m)
        }
        for e in members(of: c.id) where out.count < 3 {
            if let m = cover(for: e.id), !out.contains(where: { $0.id == m.id }) { out.append(m) }
        }
        return out
    }
}

/// A collection on the shelf: its first three pictures fanned like prints in a hand.
struct CollectionStack: View {
    let collection: ExperienceCollection
    @Environment(LifeStore.self) private var store

    var body: some View {
        let covers = store.covers(of: collection)
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(covers.dropFirst().prefix(2).enumerated().reversed()), id: \.element.id) { i, m in
                    MediaThumb(asset: m, drift: false)
                        .frame(width: 124, height: 166)
                        .clipShape(.rect(cornerRadius: 18, style: .continuous))
                        .rotationEffect(.degrees(i == 0 ? -6 : 7))
                        .offset(x: i == 0 ? -4 : 4, y: -4)
                }
                if let front = covers.first {
                    MediaThumb(asset: front)
                        .frame(width: 128, height: 170)
                        .clipShape(.rect(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
                } else {
                    PaperStack(experiences: Array(store.members(of: collection.id).prefix(3)), kind: collection.kind)
                        .frame(width: 128, height: 170)
                }
            }
            .frame(width: 148, height: 186)
            Text(collection.title)
                .font(.title(17))
                .displayTracking(17)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Text(store.summary(of: collection))
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.55))
                .lineLimit(1)
        }
        .frame(width: 148, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title), \(store.summary(of: collection))")
    }
}

/// A collection inside a year (Arrange: Time): wide, one large picture and two small.
struct CollectionWideCard: View {
    let collection: ExperienceCollection
    @Environment(LifeStore.self) private var store

    var body: some View {
        let covers = store.covers(of: collection)
        if covers.isEmpty { paper } else { pictures(covers) }
    }

    /// No pictures: the collection's Experiences as a row of small paper cards under its name.
    private var paper: some View {
        let members = store.members(of: collection.id)
        return VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(collection.title).font(.title(21)).displayTracking(21).foregroundStyle(Color.primary)
                Spacer()
                Text(collection.kind.label).font(.caption2.weight(.semibold)).foregroundStyle(Color.primary.opacity(0.55))
            }
            Text(store.summary(of: collection)).font(.caption).foregroundStyle(Color.primary.opacity(0.55))
            HStack(spacing: 8) {
                ForEach(members.prefix(3)) { e in
                    PaperStack(experiences: [e], kind: collection.kind).frame(height: 96)
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func pictures(_ covers: [MediaAsset]) -> some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 3) {
                cell(covers.first).frame(maxWidth: .infinity)
                if covers.count > 1 {
                    VStack(spacing: 3) {
                        cell(covers[1])
                        cell(covers.count > 2 ? covers[2] : nil)
                    }
                    .frame(width: 112)
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.title).font(.title(21)).displayTracking(21).foregroundStyle(.white)
                Text(store.summary(of: collection)).font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            .padding(16)
        }
        .frame(height: 180)
        .clipShape(.rect(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Text(collection.kind.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.black.opacity(0.45), in: .capsule)
                .padding(12)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func cell(_ m: MediaAsset?) -> some View {
        if let m { MediaThumb(asset: m) } else { Color.primary.opacity(0.1) }
    }
}

/// A collection with no pictures yet, drawn from its words: its Experiences' titles on fanned cards,
/// like notes kept together. Text-only lives deserve a cover too.
struct PaperStack: View {
    let experiences: [Experience]
    let kind: ExperienceCollection.Kind
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            ForEach(Array(experiences.enumerated().reversed()), id: \.element.id) { i, e in
                VStack(alignment: .leading, spacing: 6) {
                    Circle().fill(e.tint).frame(width: 7, height: 7)
                    Text(e.title)
                        .font(.title(15))
                        .displayTracking(15)
                        .foregroundStyle(Color.primary)
                        .lineLimit(5)
                    Spacer(minLength: 0)
                    Text(e.time.shortLabel(southern: e.isSouthern)).font(.caption2).foregroundStyle(Color.primary.opacity(0.5))
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(scheme == .dark ? Color(white: 0.09) : .white, in: .rect(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
                .rotationEffect(.degrees(i == 0 ? 0 : (i == 1 ? -6 : 7)))
                .offset(x: i == 0 ? 0 : (i == 1 ? -4 : 4), y: i == 0 ? 0 : -4)
                .shadow(color: .black.opacity(i == 0 ? (scheme == .dark ? 0.4 : 0.10) : 0), radius: 12, y: 8)
            }
            if experiences.isEmpty {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.08))
                Image(systemName: kind.symbol).font(.title2).foregroundStyle(Color.primary.opacity(0.4))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Shown on the shelf before any collection exists. An invitation, not an obligation.
struct StartCollectionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.25), lineWidth: 1.5).rotationEffect(.degrees(-8))
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.5).rotationEffect(.degrees(5))
                }
                .frame(width: 44, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a collection").font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                    Text("A trip, a season, a person, a ritual. Group Experiences however your life is shaped.")
                        .font(.footnote)
                        .foregroundStyle(Color.primary.opacity(0.55))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .buttonStyle(PressableStyle())
    }
}

/// One collection, opened: its name, its span, and its Experiences as a mosaic.
struct CollectionSheet: View {
    let collection: ExperienceCollection
    let onOpen: (Experience) -> Void
    @Environment(LifeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(collection.kind.label, systemImage: collection.kind.symbol)
                            .font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Color.primary.opacity(0.5))
                        Text(collection.title).font(.display(32)).displayTracking(32).foregroundStyle(Color.primary)
                        Text(store.summary(of: collection)).font(.subheadline).foregroundStyle(Color.primary.opacity(0.6))
                        Label(collection.visibility.label, systemImage: collection.visibility == .private ? "lock.fill" : "person.2.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.primary.opacity(0.55))
                            .padding(.top, 4)
                    }
                    let members = store.members(of: collection.id)
                    if members.isEmpty {
                        Text("Nothing here yet. When you add an Experience, you can put it in this collection.")
                            .font(.subheadline).foregroundStyle(Color.primary.opacity(0.55))
                    } else {
                        Mosaic(experiences: members, onOpen: onOpen)
                    }
                }
                .padding(Theme.Space.xl)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }
}
