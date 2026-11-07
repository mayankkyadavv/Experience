import CoreLocation
import ExperienceCore
import SwiftUI

/// The camera page, to the right of the globe. Shoot freely: every photo and video drops into tonight's draft
/// beside the shutter, grouped by time and place. Open the tray to keep it as an Experience, or gather it later
/// from the card on the globe.
struct CaptureFlow: View {
    @Environment(CaptureTray.self) private var tray
    @Environment(LocationProvider.self) private var location
    let camera: CameraModel
    /// The camera runs only while its page is on screen.
    let isActive: Bool

    @State private var confirmation: String?
    @State private var opened: OpenDraft?
    @State private var added = 0

    private struct OpenDraft: Identifiable { let id: UUID }

    var body: some View {
        ZStack {
            CameraView(camera: camera, isActive: isActive) {
                if let latest = tray.latest {
                    TrayButton(draft: latest, count: tray.shotCount) { opened = OpenDraft(id: latest.id) }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }

            if let confirmation {
                VStack {
                    HStack(spacing: Theme.Space.sm) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                        Text(confirmation).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .frame(minHeight: 34)
                    .background(.black.opacity(0.5), in: .capsule)
                    .padding(.top, 64)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(2)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0), value: tray.shotCount)
        .sensoryFeedback(.success, trigger: confirmation) { _, now in now != nil }
        .onChange(of: camera.captured) { _, media in
            guard let media else { return }
            camera.captured = nil
            Task { await file(media) }
        }
        .sheet(item: $opened) { target in
            TraySheet(draft: target.id) { title in confirm("Saved “\(title)” privately") }
        }
    }

    /// Into the tray at once, with a location if there's a fresh one. Otherwise the location follows: asked for
    /// the first time here, where it helps (to suggest the place), and never holding up the shot.
    private func file(_ media: CapturedMedia) async {
        let fresh = location.last.flatMap { -$0.timestamp.timeIntervalSinceNow < 300 ? $0 : nil }
        let startedNew = await tray.add(media, at: fresh)
        confirm(startedNew ? "Started a new draft" : "Added to \(CaptureTray.dayWord().lowercased())'s draft")
        guard fresh == nil, let shot = tray.latest?.shots.last else { return }
        if let found = await location.current() { tray.locate(shot.id, found) }
    }

    private func confirm(_ text: String) {
        withAnimation(Theme.Motion.short) { confirmation = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(Theme.Motion.short) { if confirmation == text { confirmation = nil } }
        }
    }
}

/// Beside the shutter: the last two shots fanned like prints, a count, and the day. Tap to open the tray.
private struct TrayButton: View {
    let draft: TrayDraft
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    let last = Array(draft.shots.suffix(2))
                    ForEach(Array(last.enumerated()), id: \.element.id) { i, shot in
                        MediaThumb(asset: shot.asset, drift: false)
                            .frame(width: 44, height: 56)
                            .clipShape(.rect(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white, lineWidth: 2))
                            .rotationEffect(.degrees(i == last.count - 1 ? 4 : -10))
                            .offset(x: i == last.count - 1 ? 4 : -4)
                    }
                }
                .frame(width: 64, height: 60)
                .overlay(alignment: .topTrailing) {
                    Text("\(count)")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(CategoryGroup.food.color, in: .capsule)
                        .offset(x: 4, y: -6)
                        .contentTransition(.numericText())
                }
                Text(CaptureTray.dayWord())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3)
            }
            .frame(minWidth: 76, minHeight: 76)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(CaptureTray.dayWord())'s draft, \(TrayDraft.countLabel(photos: draft.photos, videos: draft.videos).lowercased())")
        .accessibilityHint("Opens it to review and save")
    }
}
