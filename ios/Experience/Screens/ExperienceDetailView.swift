import ExperienceCore
import MapKit
import SwiftUI

/// Everything we know about one Experience, with every estimate labelled, plus the actions.
struct ExperienceDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let id: UUID
    var recommendationId: UUID?

    @State private var detail: ExperienceDetail?
    @State private var loadError = false
    @State private var actionError: String?
    @State private var rating: Int?

    private var state: UserExperienceState? { model.states[id] }

    var body: some View {
        ScrollView {
            Group {
                if let detail {
                    content(detail)
                } else if loadError {
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text("Couldn't load this").font(.title(22)).displayTracking(22)
                        Text("Check your connection and try again.").foregroundStyle(Theme.textMuted)
                        Button("Try again") { Task { await load() } }.buttonStyle(.primary).padding(.top, Theme.Space.sm)
                    }
                } else {
                    skeleton
                }
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surface)
        .task { await load() }
    }

    private func load() async {
        loadError = false
        do { detail = try await model.detail(id) } catch { loadError = true }
    }

    // MARK: Content

    @ViewBuilder private func content(_ d: ExperienceDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack(spacing: 6) {
                    Circle().fill(d.category.group.color).frame(width: 8, height: 8)
                    Text([d.category.group.label, d.subcategory].compactMap { $0 }.joined(separator: " · ")).monoLabel()
                }
                SourcedText(d.sourced("title", d.title))
                    .font(.display(28)).displayTracking(28)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let place = d.place {
                    Text([place.name, place.neighborhood].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Theme.textMuted)
                }
            }

            facts(d)
            actions

            if let description = d.description {
                SourcedText(d.sourced("description", description))
                    .font(.body).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !d.upcoming.isEmpty { dates(d) }
            if !d.hours.isEmpty { week(d) }
            if !d.officialLinks.isEmpty || d.place?.lat != nil { links(d) }
            if !d.sources.isEmpty { sources(d) }
        }
    }

    private func facts(_ d: ExperienceDetail) -> some View {
        var chips: [Sourced<String>] = []
        if let p = PriceText.label(d.priceMinCents, d.priceMaxCents) { chips.append(d.sourced("price_min_cents", p + (p == "Free" ? "" : " pp"))) }
        if let t = PriceText.duration(d.durationMinMinutes, d.durationMaxMinutes) { chips.append(d.sourced("duration_min_minutes", t)) }
        if let today = todayHours(d) { chips.append(d.sourced("hours", today)) }
        return FlowLayout(spacing: 6) {
            ForEach(chips.indices, id: \.self) { FactChip(text: chips[$0]) }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.sm) {
                toggle(state?.interestedAt != nil ? "We're in" : "Interested", on: state?.interestedAt != nil, tint: Theme.success) {
                    .init(.interested, on: id, recommendationId: recommendationId)
                }
                toggle("Not for us", on: state?.notInterestedAt != nil, tint: Theme.textMuted) {
                    .init(.notInterested, on: id, recommendationId: recommendationId)
                }
                Button {
                    Task { await send(.init(state?.isSaved == true ? .unsave : .save, on: id, recommendationId: recommendationId)) }
                } label: {
                    Image(systemName: state?.isSaved == true ? "bookmark.fill" : "bookmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 44)
                        .foregroundStyle(state?.isSaved == true ? CategoryGroup.activity.color : Theme.text)
                        .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button - 2, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(state?.isSaved == true ? "Saved" : "Save")
            }

            if state?.isDone == true {
                RatingRow(rating: state?.rating) { value in
                    Task { await send(.rate(value, on: id)) }
                }
                Button("Not done yet") { Task { await send(.init(.undone, on: id)) } }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
            } else {
                Button("Did it") { Task { await send(.init(.done, on: id, recommendationId: recommendationId)) } }
                    .buttonStyle(.secondary)
            }
            if let actionError { Text(actionError).font(.caption).foregroundStyle(Theme.error) }
        }
        .sensoryFeedback(.success, trigger: state?.isDone == true)
    }

    private func toggle(_ label: String, on: Bool, tint: Color, feedback: @escaping () -> Feedback) -> some View {
        Button { Task { await send(feedback()) } } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(on ? .white : Theme.text)
                .background(on ? tint : Theme.soft, in: .rect(cornerRadius: Theme.Radius.button - 2, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func send(_ feedback: Feedback) async {
        actionError = nil
        do {
            try await model.send(feedback)
        } catch {
            actionError = (error as? LocalizedError)?.errorDescription ?? "Didn't save. Check your connection."
        }
    }

    // MARK: Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title).monoLabel()
            content()
        }
        .padding(.top, Theme.Space.sm)
    }

    private func dates(_ d: ExperienceDetail) -> some View {
        section("Upcoming dates" + (d.provenance["occurrences"] == .estimated || d.provenance["dates"] == .estimated ? " (estimated)" : "")) {
            ForEach(d.upcoming.prefix(6), id: \.self) { o in
                HStack {
                    Text(o.startsAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.body.weight(.semibold))
                    Spacer()
                    Text(o.startsAt, format: .dateTime.hour().minute()).foregroundStyle(Theme.textMuted)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func week(_ d: ExperienceDetail) -> some View {
        section("Hours" + (d.provenance["hours"] == .estimated ? " (estimated)" : "")) {
            ForEach(Array(Self.weekOrder.enumerated()), id: \.offset) { _, day in
                let slots = d.hours.filter { $0.day == day }
                HStack {
                    Text(Self.dayNames[day]).font(.subheadline.weight(day == todayIndex ? .bold : .regular))
                    Spacer()
                    Text(slots.isEmpty ? "Closed" : slots.map { "\(Self.clock($0.open))–\(Self.clock($0.close))" }.joined(separator: ", "))
                        .font(.subheadline).foregroundStyle(slots.isEmpty ? Theme.textMuted : Theme.text)
                }
            }
        }
    }

    private func links(_ d: ExperienceDetail) -> some View {
        section("Go") {
            VStack(spacing: Theme.Space.sm) {
                if let place = d.place, let lat = place.lat, let lng = place.lng {
                    LinkRow(icon: "arrow.triangle.turn.up.right.diamond", title: "Directions", subtitle: place.address ?? place.name) {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: lat, longitude: lng)))
                        item.name = place.name
                        item.openInMaps()
                    }
                }
                ForEach(d.officialLinks, id: \.self) { link in
                    LinkRow(icon: Self.icon(link.kind), title: Self.label(link.kind), subtitle: link.url.host() ?? link.url.absoluteString) {
                        openURL(link.url)
                    }
                }
            }
        }
    }

    private func sources(_ d: ExperienceDetail) -> some View {
        section("Where this came from") {
            Text("Researched from these pages and not yet checked by us. Details can change.")
                .font(.footnote).foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(d.sources, id: \.self) { link in
                Button { openURL(link.url) } label: {
                    Text(link.url.host() ?? link.url.absoluteString)
                        .font(.footnote.weight(.semibold)).underline()
                        .foregroundStyle(Theme.text)
                }
            }
        }
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            RoundedRectangle(cornerRadius: 6).fill(Theme.soft).frame(width: 120, height: 12)
            RoundedRectangle(cornerRadius: 8).fill(Theme.soft).frame(height: 30)
            RoundedRectangle(cornerRadius: 8).fill(Theme.soft).frame(width: 200, height: 30)
            RoundedRectangle(cornerRadius: 8).fill(Theme.soft).frame(height: 80)
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading")
    }

    // MARK: Helpers

    private var cityZone: TimeZone { model.city.flatMap { TimeZone(identifier: $0.timezone) } ?? .current }
    private var todayIndex: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = cityZone
        return cal.component(.weekday, from: Date()) - 1 // 0 = Sunday, like the catalog
    }

    private func todayHours(_ d: ExperienceDetail) -> String? {
        guard !d.hours.isEmpty else { return nil }
        let slots = d.hours.filter { $0.day == todayIndex }
        guard let last = slots.last else { return "Closed today" }
        return "Open today till \(Self.clock(last.close))"
    }

    private static let weekOrder = [1, 2, 3, 4, 5, 6, 0]
    private static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// "17:30" → "5:30 PM"
    static func clock(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return hhmm }
        let h = parts[0] % 24, m = parts[1]
        let suffix = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == 0 ? "\(h12) \(suffix)" : String(format: "%d:%02d %@", h12, m, suffix)
    }

    static func label(_ kind: String) -> String {
        ["website": "Website", "tickets": "Tickets", "booking": "Book", "menu": "Menu", "instagram": "Instagram",
         "tiktok": "TikTok", "youtube": "YouTube"][kind] ?? "Link"
    }

    static func icon(_ kind: String) -> String {
        ["website": "globe", "tickets": "ticket", "booking": "calendar", "menu": "fork.knife", "instagram": "camera",
         "tiktok": "play.rectangle", "youtube": "play.rectangle"][kind] ?? "link"
    }
}

private struct LinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                Image(systemName: icon).font(.body.weight(.semibold)).frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.textMuted)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.Space.md)
            .frame(minHeight: 54)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Three honest choices (DESIGN.md "Rating"; the scale is still an open founder decision).
struct RatingRow: View {
    let rating: Int?
    let onRate: (Int) -> Void

    private let options: [(Int, String, String)] = [(1, "Not for me", "face.dashed"), (2, "It was good", "face.smiling"), (3, "Loved it", "heart.fill")]

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            ForEach(options, id: \.0) { value, label, icon in
                let on = rating == value
                Button { onRate(value) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: icon).font(.title2)
                        Text(label).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .foregroundStyle(Theme.text)
                    .background(on ? CategoryGroup.activity.color.opacity(0.22) : Theme.soft, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .strokeBorder(on ? CategoryGroup.activity.color : .clear, lineWidth: 2)
                    }
                    .rotationEffect(.degrees(on ? -2 : 0))
                    .scaleEffect(on ? 1.03 : 1)
                    .animation(.spring(duration: 0.35, bounce: 0), value: on)
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.success, trigger: rating)
    }
}
