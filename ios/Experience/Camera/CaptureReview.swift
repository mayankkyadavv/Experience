import AVFoundation
import CoreLocation
import ExperienceCore
import SwiftUI

/// Review a capture, then say where it was. Picking an Experience marks it done, so its pillar rises (ADR-012).
struct CaptureReview: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationProvider.self) private var location
    let media: CapturedMedia
    let onRetake: () -> Void
    let onSaved: (_ experienceTitle: String?) -> Void

    @State private var placing = false
    @State private var query = ""
    @State private var here: CLLocation?
    @State private var saving: UUID??
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MediaView(media: media).ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onRetake) {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 44, height: 44)
                            .background(.black.opacity(0.35), in: .circle)
                    }
                    .accessibilityLabel("Retake")
                    Spacer()
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.top, Theme.Space.sm)
                Spacer()
                if !placing {
                    HStack(spacing: Theme.Space.md) {
                        Button("Retake", action: onRetake)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(.black.opacity(0.4), in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
                            .foregroundStyle(.white)
                        Button {
                            withAnimation(.spring(duration: 0.4, bounce: 0)) { placing = true }
                        } label: {
                            Text("Add to your city").font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(.white, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.bottom, Theme.Space.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if placing {
                VStack {
                    Spacer()
                    placePicker
                        .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .task { here = await location.current() }
        .statusBarHidden()
    }

    // MARK: Where was this?

    private var nearby: [CatalogItem] {
        let items = model.cityCatalog.filter { $0.matches(query) }
        guard let here = here ?? location.last else { return Array(items.prefix(40)) }
        func meters(_ i: CatalogItem) -> Double {
            i.coordinate.map { here.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lng)) } ?? .greatestFiniteMagnitude
        }
        return Array(items.sorted { meters($0) < meters($1) }.prefix(40))
    }

    private var placePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Capsule().fill(Theme.hairline).frame(width: 36, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
            HStack(alignment: .firstTextBaseline) {
                Text("Where was this?").font(.display(26)).displayTracking(26).foregroundStyle(Theme.text)
                Spacer()
                CloseButton { withAnimation(.spring(duration: 0.4, bounce: 0)) { placing = false } }
            }
            .padding(.leading, Theme.Space.xl)
            .padding(.trailing, Theme.Space.sm)

            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
                TextField(here == nil ? "Search places" : "Search, or pick one nearby", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            .padding(.horizontal, Theme.Space.md)
            .frame(minHeight: 44)
            .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            .padding(.horizontal, Theme.Space.xl)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(nearby) { item in
                        Button { Task { await save(item) } } label: { row(item) }
                            .buttonStyle(PressableStyle())
                            .disabled(saving != nil)
                        Divider().overlay(Theme.hairline).padding(.leading, Theme.Space.xl + 18)
                    }
                }
            }
            .frame(height: 300)
            .scrollDismissesKeyboard(.immediately)

            if let error { Text(error).font(.footnote).foregroundStyle(Theme.error).padding(.horizontal, Theme.Space.xl) }

            Button {
                Task { await save(nil) }
            } label: {
                if saving == .some(nil) { ProgressView() } else { Text("Not on the list. Just keep it") }
            }
            .buttonStyle(.secondary)
            .disabled(saving != nil)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
        .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.sheet, topTrailingRadius: Theme.Radius.sheet, style: .continuous))
    }

    private func row(_ item: CatalogItem) -> some View {
        HStack(spacing: Theme.Space.md) {
            Circle().fill(item.category.group.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.place?.name ?? item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                SourcedText(item.sourcedTitle).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
            if saving == .some(item.id) {
                ProgressView()
            } else if let c = item.coordinate, let here = here ?? location.last {
                Text(Self.distance(here.distance(from: CLLocation(latitude: c.lat, longitude: c.lng))))
                    .font(.caption).foregroundStyle(Theme.textMuted).monospacedDigit()
            }
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private func save(_ item: CatalogItem?) async {
        saving = .some(item?.id)
        error = nil
        do {
            try await model.saveCapture(media, experienceId: item?.id)
            onSaved(item?.place?.name ?? item?.title)
        } catch {
            self.error = "Couldn't save. It's still on your phone; try again."
            saving = nil
        }
    }

    static func distance(_ meters: CLLocationDistance) -> String {
        meters < 1000 ? "\(Int((meters / 10).rounded() * 10)) m" : String(format: "%.1f km", meters / 1000)
    }
}

/// Full-screen photo, or a silent looping video.
private struct MediaView: View {
    let media: CapturedMedia

    var body: some View {
        switch media.kind {
        case .photo:
            if let image = UIImage(contentsOfFile: media.url.path()) {
                Image(uiImage: image).resizable().scaledToFill()
            }
        case .video:
            LoopingVideo(url: media.url)
        }
    }
}

private struct LoopingVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        let player = AVQueuePlayer()
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var looper: AVPlayerLooper? }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
