import SwiftUI

/// Camera → review → "Where was this?" → back to the camera with a quiet confirmation. Opened from + on home.
struct CaptureFlow: View {
    @Environment(AppModel.self) private var model
    let camera: CameraModel
    let onClose: () -> Void

    @State private var confirmation: String?

    var body: some View {
        ZStack {
            CameraView(camera: camera, onClose: onClose)

            if let media = camera.captured {
                CaptureReview(media: media, onRetake: {
                    withAnimation(.spring(duration: 0.35, bounce: 0)) { camera.discard(media) }
                }, onSaved: { place in
                    withAnimation(.spring(duration: 0.35, bounce: 0)) { camera.captured = nil }
                    confirm(place.map { "Added \($0) to your \(model.city?.name ?? "city")" } ?? "Saved to your \(model.city?.name ?? "city")")
                })
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                .zIndex(1)
            }

            if let confirmation {
                VStack {
                    HStack(spacing: Theme.Space.sm) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                        Text(confirmation).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .frame(minHeight: 44)
                    .background(.black.opacity(0.55), in: .capsule)
                    .padding(.top, 64)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(2)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0), value: camera.captured)
        .sensoryFeedback(.success, trigger: confirmation)
    }

    private func confirm(_ text: String) {
        withAnimation(Theme.Motion.short) { confirmation = text }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(Theme.Motion.short) { if confirmation == text { confirmation = nil } }
        }
    }
}
