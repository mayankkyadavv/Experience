import AVKit
import ExperienceCore
import SwiftUI

/// One of your own Experiences (brief §7): a strong cover or a text-first page, title, time, place,
/// who can see it, then its words and where it's collected.
struct LifeExperienceView: View {
    let experience: Experience

    @Environment(LifeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        let media = store.mediaFor(experience.id)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    if !media.isEmpty {
                        TabView(selection: $page) {
                            ForEach(Array(media.enumerated()), id: \.element.id) { i, m in
                                MediaPage(asset: m).tag(i)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
                        .frame(height: 420)
                        .clipShape(.rect(cornerRadius: Theme.Radius.card, style: .continuous))
                        .environment(\.colorScheme, .dark)
                    }

                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        if media.isEmpty {
                            Circle().fill(experience.tint).frame(width: 10, height: 10)
                        }
                        SourcedText(experience.sourcedTitle)
                            .font(.display(30))
                            .displayTracking(30)
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        SourcedText(experience.sourcedTime)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary.opacity(0.7))
                        if let place = experience.placeName ?? experience.placeLocality {
                            Label(place, systemImage: "mappin").font(.subheadline).foregroundStyle(Color.primary.opacity(0.7))
                        }
                        HStack(spacing: Theme.Space.sm) {
                            Label(experience.visibility.label, systemImage: experience.visibility == .private ? "lock.fill" : "person.2.fill")
                            if experience.state == .want { Label("Want to Experience", systemImage: "bookmark") }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .padding(.top, 2)
                    }

                    if let words = experience.description, !words.isEmpty {
                        Text(words)
                            .font(.body)
                            .foregroundStyle(Color.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    let inCollections = store.allCollections.filter { c in store.members(of: c.id).contains { $0.id == experience.id } }
                    if !inCollections.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("In").font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Color.primary.opacity(0.5))
                            ForEach(inCollections) { c in
                                Label(c.title, systemImage: c.kind.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                            }
                        }
                    }

                    if let status = store.syncStatus(experience.id) {
                        Label(status, systemImage: "icloud.and.arrow.up").font(.footnote).foregroundStyle(Color.primary.opacity(0.55))
                    }
                }
                .padding(Theme.Space.xl)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }
}

/// One photo or video, as large as it can be. Videos play from the copy on this phone when there is one.
private struct MediaPage: View {
    let asset: MediaAsset
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if asset.kind == .video, let file = asset.deviceFile, let local = LifeFiles.locate(file) {
                VideoPlayer(player: player)
                    .onAppear { player = AVPlayer(url: local) }
                    .onDisappear { player?.pause() }
            } else if asset.kind == .photo, let file = asset.deviceFile, let local = LifeFiles.locate(file),
                      let image = UIImage(contentsOfFile: local.path()) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                MediaThumb(asset: asset, drift: false)
            }
        }
        .accessibilityLabel(asset.altText ?? (asset.kind == .video ? "Video" : "Photo"))
    }
}
