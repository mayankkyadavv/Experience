import ExperienceCore
import SwiftUI

extension LifeCategory {
    /// The six design hues (DESIGN.md), reused so a life and a city speak the same color language.
    var group: CategoryGroup {
        switch self {
        case .food: .food
        case .nightlife, .music: .nightlife
        case .artsCulture: .culture
        case .outdoors: .outdoors
        case .sports, .learning, .milestones: .activity
        case .travel, .everyday: .other
        }
    }
}

extension ExperienceCategory {
    /// The catalog's categories folded into the personal set; mirrors `life_category()` in the database.
    var life: LifeCategory {
        switch self {
        case .food, .cafe, .dessert, .market: .food
        case .bar, .nightlife: .nightlife
        case .music: .music
        case .comedy, .artsCulture, .attraction, .event: .artsCulture
        case .outdoors: .outdoors
        case .sports, .active: .sports
        case .class: .learning
        case .lodging: .travel
        case .games, .shopping, .wellness, .other: .everyday
        }
    }
}

extension Experience {
    /// The dot on a text card: its first category's hue, or a quiet neutral.
    var tint: Color { lifeCategories.first?.group.color ?? Color.primary.opacity(0.35) }

    /// "Oct 18" / "Summer 2021" / "Date unknown", with "(estimated)" when the time was guessed.
    var sourcedShortTime: Sourced<String> { Sourced(time.shortLabel(southern: isSouthern), provenance(of: "time")) }
    var sourcedTime: Sourced<String> { Sourced(time.label(southern: isSouthern), provenance(of: "time")) }
}

/// A photo or a video's poster that drifts slowly, like a still that's breathing. Still under Reduce Motion.
struct MediaThumb: View {
    let asset: MediaAsset
    var drift = true

    @Environment(LifeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var moving = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.primary.opacity(0.06)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(moving ? 1.12 : 1.03)
                        .offset(x: moving ? -geo.size.width * 0.03 : 0, y: moving ? -geo.size.height * 0.02 : 0)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: asset.clientId) {
            let img = await ThumbnailCache.shared.image(for: asset, storage: store.storage)
            withAnimation(.easeOut(duration: 0.3)) { image = img }
            guard drift, !reduceMotion, img != nil else { return }
            // Each card starts at its own moment so the wall doesn't pulse in unison.
            try? await Task.sleep(for: .milliseconds(Int.random(in: 0...1800)))
            withAnimation(.easeInOut(duration: Double.random(in: 8...11)).repeatForever(autoreverses: true)) { moving = true }
        }
        .accessibilityHidden(true)
    }
}

/// One Experience on the profile wall: its media when it has some, otherwise its words.
struct LifeCard: View {
    let experience: Experience

    @Environment(LifeStore.self) private var store

    var body: some View {
        let cover = store.cover(for: experience.id)
        Group {
            if let cover { mediaCard(cover) } else { TextCard(experience: experience) }
        }
        .overlay(alignment: .topTrailing) {
            if store.isPending(experience.id) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.45), in: .circle)
                    .padding(8)
                    .accessibilityLabel(store.syncStatus(experience.id) ?? "")
            }
        }
        .contentShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private func mediaCard(_ cover: MediaAsset) -> some View {
        let all = store.mediaFor(experience.id)
        let height: CGFloat = (cover.aspect ?? 0.8) >= 1.1 ? 170 : 220
        return ZStack(alignment: .bottomLeading) {
            MediaThumb(asset: cover)
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                SourcedText(experience.sourcedTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(detail(all, cover))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(height: height)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private func detail(_ all: [MediaAsset], _ cover: MediaAsset) -> String {
        var parts = [experience.sourcedShortTime.display]
        if cover.kind == .video, all.count == 1, let d = cover.durationSeconds {
            parts.append("▶ \(Duration.seconds(d).formatted(.time(pattern: .minuteSecond)))")
        } else if all.count > 1 {
            let photos = all.filter { $0.kind == .photo }.count, videos = all.count - photos
            parts.append([photos > 0 ? "\(photos) photo\(photos == 1 ? "" : "s")" : nil, videos > 0 ? "\(videos) video\(videos == 1 ? "" : "s")" : nil]
                .compactMap { $0 }.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }
}

/// A text-first Experience: as considered as a photo. Its own words carry it.
struct TextCard: View {
    let experience: Experience
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle().fill(experience.tint).frame(width: 8, height: 8)
            SourcedText(experience.sourcedTitle)
                .font(.title(19))
                .displayTracking(19)
                .foregroundStyle(Color.primary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            if let words = experience.description, !words.isEmpty {
                Text("“\(words)”")
                    .font(.footnote)
                    .foregroundStyle(Color.primary.opacity(0.65))
                    .lineLimit(3)
            }
            Text([experience.sourcedShortTime.display, experience.placeName].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.45))
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scheme == .dark ? Color(white: 0.07) : .white, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.primary.opacity(scheme == .dark ? 0.08 : 0)))
        .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 12, y: 6)
    }
}

/// Two columns that stay balanced: each card goes to the shorter column.
struct Mosaic: View {
    let experiences: [Experience]
    let onOpen: (Experience) -> Void

    @Environment(LifeStore.self) private var store

    var body: some View {
        let columns = split()
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<2, id: \.self) { c in
                LazyVStack(spacing: 10) {
                    ForEach(columns[c]) { e in
                        Button { onOpen(e) } label: { LifeCard(experience: e) }
                            .buttonStyle(PressableStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func split() -> [[Experience]] {
        var cols: [[Experience]] = [[], []], heights: [CGFloat] = [0, 0]
        for e in experiences {
            let h: CGFloat
            if let cover = store.cover(for: e.id) { h = (cover.aspect ?? 0.8) >= 1.1 ? 170 : 220 }
            else { h = 90 + CGFloat(min(e.title.count, 60)) * 0.9 + (e.description == nil ? 0 : 40) }
            let i = heights[0] <= heights[1] ? 0 : 1
            cols[i].append(e)
            heights[i] += h + 10
        }
        return cols
    }
}
