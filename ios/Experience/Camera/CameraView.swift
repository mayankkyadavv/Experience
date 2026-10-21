import AVFoundation
import ExperienceCore
import SwiftUI

/// A calm, full-screen camera, opened from + on home. Tap the shutter for a photo, hold it to record.
struct CameraView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    let camera: CameraModel
    let onClose: () -> Void

    @State private var pinchStart: CGFloat?
    @State private var focusPoint: CGPoint?
    @State private var flipTrigger = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.state {
            case .running, .starting:
                CameraPreview(session: camera.session, onDoubleTap: flip) { devicePoint, viewPoint in
                    camera.focus(at: devicePoint)
                    withAnimation(Theme.Motion.micro) { focusPoint = viewPoint }
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        withAnimation(Theme.Motion.short) { if focusPoint == viewPoint { focusPoint = nil } }
                    }
                }
                .ignoresSafeArea()
                .opacity(camera.state == .running ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: camera.state)
                .gesture(pinch)
                if let focusPoint { FocusRing().position(focusPoint).allowsHitTesting(false) }
            case .denied:
                message("Camera access is off", "Turn it on in Settings to capture what you're doing.", button: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .unavailable:
                #if LOCAL_BACKEND
                message("No camera here", "The camera needs a real iPhone. Everything else works.", button: "Try with a test photo") {
                    camera.useTestPhoto()
                }
                #else
                message("No camera here", "The camera needs a real iPhone. Everything else works.", button: nil, action: {})
                #endif
            }

            controls
        }
        .statusBarHidden(camera.state == .running)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await camera.start() } } else if phase == .background { camera.stop() }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack {
            HStack {
                CircleIcon(system: camera.flash == .on ? "bolt.fill" : "bolt.slash", label: camera.flash == .on ? "Flash on" : "Flash off") {
                    camera.flash = camera.flash == .on ? .off : .on
                }
                Spacer()
                CircleIcon(system: "arrow.triangle.2.circlepath", label: "Flip camera") { flip() }
                    .rotationEffect(.degrees(Double(flipTrigger) * 180))
                    .animation(.spring(duration: 0.4, bounce: 0), value: flipTrigger)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.sm)
            .opacity(camera.isRecording ? 0.0 : 1)
            .overlay { if camera.isRecording, let s = camera.recordingStarted { RecordingClock(started: s) } }

            Spacer()

            if camera.state == .running, camera.presets.count > 1, !camera.isRecording {
                ZoomPresets(camera: camera)
                    .padding(.bottom, Theme.Space.lg)
                    .transition(.opacity)
            }

            HStack {
                CircleIcon(system: "xmark", label: "Close", size: 52, action: onClose)
                Spacer()
                Shutter(camera: camera)
                Spacer()
                Color.clear.frame(width: 52, height: 52)
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.lg)
        }
        .animation(Theme.Motion.short, value: camera.isRecording)
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? camera.zoom
                if pinchStart == nil { pinchStart = start }
                camera.setZoom(start * value.magnification)
            }
            .onEnded { _ in pinchStart = nil }
    }

    private func flip() {
        flipTrigger += 1
        Task { await camera.flip() }
    }

    private func message(_ title: String, _ body: String, button: String?, action: @escaping () -> Void) -> some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "camera").font(.system(size: 34, weight: .semibold))
            Text(title).font(.title(24)).displayTracking(24)
            Text(body).font(.body).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            if let button {
                Button(button, action: action)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, Theme.Space.xl)
                    .frame(minHeight: 48)
                    .background(.white, in: .capsule)
                    .foregroundStyle(.black)
                    .padding(.top, Theme.Space.sm)
            }
        }
        .foregroundStyle(.white)
        .padding(Theme.Space.xxl)
    }
}

// MARK: - Shutter

/// One white ring. Tap = photo. Hold = video (ring fills over 60 s); slide up while holding to zoom.
private struct Shutter: View {
    let camera: CameraModel
    @State private var pressed = false
    @State private var pressStart: Date?
    @State private var holdTask: Task<Void, Never>?
    @State private var zoomAtHold: CGFloat = 1
    @State private var shots = 0

    var body: some View {
        ZStack {
            Circle().strokeBorder(.white, lineWidth: 5).frame(width: 84, height: 84)
            if camera.isRecording, let started = camera.recordingStarted {
                TimelineView(.animation) { context in
                    let progress = min(1, context.date.timeIntervalSince(started) / CameraModel.maxVideo)
                    Circle().trim(from: 0, to: progress)
                        .stroke(CategoryGroup.food.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 79, height: 79)
                }
            }
            Circle()
                .fill(camera.isRecording ? CategoryGroup.food.color : .white)
                .frame(width: camera.isRecording ? 34 : 68, height: camera.isRecording ? 34 : 68)
                .clipShape(RoundedRectangle(cornerRadius: camera.isRecording ? 9 : 34, style: .continuous))
                .scaleEffect(pressed && !camera.isRecording ? 0.9 : 1)
        }
        .frame(width: 96, height: 96)
        .contentShape(.circle)
        .animation(.spring(duration: 0.3, bounce: 0), value: camera.isRecording)
        .animation(.spring(duration: 0.2, bounce: 0), value: pressed)
        .gesture(press)
        .sensoryFeedback(.impact(weight: .light), trigger: shots)
        .sensoryFeedback(.impact(weight: .medium), trigger: camera.isRecording)
        .accessibilityElement()
        .accessibilityLabel(camera.isRecording ? "Stop recording" : "Shutter")
        .accessibilityHint("Tap for a photo. Touch and hold to record video.")
        .accessibilityAction { camera.isRecording ? camera.stopRecording() : camera.takePhoto() }
        .disabled(camera.state != .running)
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil {
                    pressStart = Date()
                    pressed = true
                    holdTask = Task {
                        try? await Task.sleep(for: .milliseconds(280))
                        guard !Task.isCancelled else { return }
                        zoomAtHold = camera.zoom
                        await camera.startRecording()
                    }
                }
                // Slide up while recording to zoom in (about 2× per 150 pt).
                if camera.isRecording {
                    let up = max(0, -value.translation.height)
                    camera.setZoom(zoomAtHold * pow(2, up / 150))
                }
            }
            .onEnded { _ in
                holdTask?.cancel()
                pressed = false
                if camera.isRecording {
                    camera.stopRecording()
                } else if let start = pressStart, Date().timeIntervalSince(start) < 0.28 {
                    shots += 1
                    camera.takePhoto()
                }
                pressStart = nil
            }
    }
}

// MARK: - Pieces

private struct ZoomPresets: View {
    let camera: CameraModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(camera.presets, id: \.self) { preset in
                let next = camera.presets.first { $0 > preset } ?? .infinity
                let active = camera.zoom >= preset - 0.01 && camera.zoom < next - 0.01
                Button {
                    camera.setZoom(preset, ramp: true)
                } label: {
                    Text(active ? Self.format(camera.zoom) + "×" : Self.format(preset))
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(active ? CategoryGroup.activity.color : .white)
                        .frame(width: active ? 40 : 32, height: active ? 40 : 32)
                        .background(.black.opacity(0.35), in: .circle)
                }
                .accessibilityLabel("\(Self.format(preset)) times zoom")
            }
        }
        .padding(5)
        .background(.black.opacity(0.2), in: .capsule)
        .animation(Theme.Motion.micro, value: camera.zoom)
    }

    static func format(_ z: CGFloat) -> String {
        z < 1 ? String(format: ".%d", Int((z * 10).rounded())) : (z.rounded() == z || z >= 10 ? "\(Int(z.rounded()))" : String(format: "%.1f", z))
    }
}

private struct CircleIcon: View {
    let system: String
    let label: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.black.opacity(0.3), in: .circle)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

private struct RecordingClock: View {
    let started: Date

    var body: some View {
        TimelineView(.periodic(from: started, by: 1)) { context in
            let s = Int(context.date.timeIntervalSince(started))
            HStack(spacing: 6) {
                Circle().fill(CategoryGroup.food.color).frame(width: 8, height: 8)
                Text(String(format: "%d:%02d", s / 60, s % 60)).font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.black.opacity(0.4), in: .capsule)
        }
    }
}

private struct FocusRing: View {
    @State private var settled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(CategoryGroup.activity.color, lineWidth: 1.5)
            .frame(width: 72, height: 72)
            .scaleEffect(settled ? 1 : 1.3)
            .onAppear { withAnimation(.spring(duration: 0.3, bounce: 0)) { settled = true } }
    }
}

// MARK: - Preview layer

/// AVCaptureVideoPreviewLayer in SwiftUI; reports taps in device and view coordinates for focus.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onDoubleTap: () -> Void
    let onTap: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.layer0.session = session
        view.layer0.videoGravity = .resizeAspectFill
        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap))
        double.numberOfTapsRequired = 2
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.require(toFail: double)
        view.addGestureRecognizer(double)
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onDoubleTap = onDoubleTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap, onDoubleTap: onDoubleTap) }

    final class Coordinator: NSObject {
        weak var view: PreviewView?
        var onTap: (CGPoint, CGPoint) -> Void
        var onDoubleTap: () -> Void
        init(onTap: @escaping (CGPoint, CGPoint) -> Void, onDoubleTap: @escaping () -> Void) {
            self.onTap = onTap
            self.onDoubleTap = onDoubleTap
        }

        @objc func doubleTap() { onDoubleTap() }

        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let view else { return }
            let p = g.location(in: view)
            onTap(view.layer0.captureDevicePointConverted(fromLayerPoint: p), p)
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var layer0: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
