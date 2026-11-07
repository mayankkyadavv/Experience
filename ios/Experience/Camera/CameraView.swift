import AVFoundation
import ExperienceCore
import SwiftUI

/// A calm, full-screen camera: the page to the right of the globe. Tap the shutter for a photo, hold it to record.
struct CameraView<Accessory: View>: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    let camera: CameraModel
    /// The session runs (and the camera light is on) only while this page is showing.
    let isActive: Bool
    /// Sits left of the shutter (the draft tray); hidden while recording.
    @ViewBuilder var accessory: () -> Accessory

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
        .statusBarHidden(isActive && camera.state == .running)
        .task(id: isActive) {
            if isActive { await camera.start() } else { camera.stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isActive { Task { await camera.start() } } else if phase == .background { camera.stop() }
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

            Group {
                if camera.isRecording {
                    // While recording the presets give way to a readout of the slide-to-zoom.
                    Text(ZoomPresets.format(camera.zoom) + "×")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(.black.opacity(0.35), in: .capsule)
                        .accessibilityLabel("Zoom \(ZoomPresets.format(camera.zoom)) times")
                } else if camera.state == .running, camera.presets.count > 1 {
                    ZoomPresets(camera: camera)
                }
            }
            .frame(height: 50)
            .padding(.bottom, Theme.Space.md)
            .transition(.opacity)

            Shutter(camera: camera)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    accessory()
                        .padding(.leading, 28)
                        .opacity(camera.isRecording || camera.shutterDown ? 0 : 1)
                        .allowsHitTesting(!camera.isRecording && !camera.shutterDown)
                }
                .padding(.bottom, Theme.Space.md)
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

/// One white ring. Tap = photo. Hold = video (the ring fills over 60 s).
/// While holding: slide up to zoom in, down to zoom out, right onto the lock to keep recording without holding.
/// A locked recording stops with a tap on the shutter.
private struct Shutter: View {
    let camera: CameraModel
    @GestureState private var touching = false
    @State private var pressStart: Date?
    @State private var holdTask: Task<Void, Never>?
    @State private var zoomAtHold: CGFloat = 1
    /// The finger's offset when recording began; zoom and lock measure from here.
    @State private var origin: CGSize = .zero
    @State private var latest: CGSize = .zero
    @State private var lockProgress: CGFloat = 0
    @State private var locked = false
    @State private var stopOnRelease = false
    @State private var shots = 0

    static let holdDelay = 0.28
    static let lockDistance: CGFloat = 80
    /// Points of vertical slide per doubling of zoom.
    static let zoomPerDoubling: CGFloat = 150

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
                .scaleEffect(camera.shutterDown && !camera.isRecording ? 0.9 : 1)
        }
        .scaleEffect(camera.isRecording && !locked ? 1.12 : 1)
        .frame(width: 96, height: 96)
        .contentShape(.circle)
        .overlay(alignment: .leading) {
            if camera.isRecording && (locked || camera.shutterDown) {
                LockTrack(progress: lockProgress, locked: locked)
                    .offset(x: 96 + Theme.Space.sm)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0), value: camera.isRecording)
        .animation(.spring(duration: 0.3, bounce: 0), value: locked)
        .animation(.spring(duration: 0.2, bounce: 0), value: camera.shutterDown)
        .gesture(press)
        .onChange(of: touching) { _, down in
            // A cancelled touch (an alert, a call) never reaches onEnded; let go the same way.
            if !down { release() }
        }
        .onChange(of: camera.isRecording) { _, recording in
            if !recording { locked = false; stopOnRelease = false; lockProgress = 0 }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: shots)
        .sensoryFeedback(.impact(weight: .medium), trigger: camera.isRecording)
        .sensoryFeedback(.success, trigger: locked) { _, now in now }
        .accessibilityElement()
        .accessibilityLabel(camera.isRecording ? "Stop recording" : "Shutter")
        .accessibilityHint(camera.isRecording ? "" : "Tap for a photo. Touch and hold to record video.")
        .accessibilityAction { camera.isRecording ? camera.stopRecording() : camera.takePhoto() }
        .accessibilityAction(named: "Record video") {
            // VoiceOver can't hold and slide, so this starts a locked recording.
            guard !camera.isRecording else { return }
            locked = true
            Task { await camera.startRecording() }
        }
        .disabled(camera.state != .running)
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                latest = value.translation
                if pressStart == nil {
                    pressStart = Date()
                    camera.shutterDown = true
                    // Touching a locked recording: lifting the finger stops it.
                    if locked { stopOnRelease = true; return }
                    holdTask = Task {
                        try? await Task.sleep(for: .seconds(Self.holdDelay))
                        guard !Task.isCancelled else { return }
                        zoomAtHold = camera.zoom
                        origin = latest
                        await camera.startRecording(stillWanted: { camera.shutterDown })
                    }
                }
                guard camera.isRecording, !locked, !stopOnRelease else { return }
                let dx = latest.width - origin.width
                let dy = latest.height - origin.height
                camera.setZoom(zoomAtHold * pow(2, -dy / Self.zoomPerDoubling))
                lockProgress = min(1, max(0, dx / Self.lockDistance))
                if lockProgress >= 1 { locked = true; lockProgress = 0 }
            }
            .onEnded { _ in release() }
    }

    private func release() {
        guard let start = pressStart else { return }
        pressStart = nil
        holdTask?.cancel()
        holdTask = nil
        camera.shutterDown = false
        lockProgress = 0
        if stopOnRelease {
            stopOnRelease = false
            locked = false
            camera.stopRecording()
        } else if camera.isRecording {
            if !locked { camera.stopRecording() }
        } else if Date().timeIntervalSince(start) < Self.holdDelay {
            shots += 1
            camera.takePhoto()
        }
    }
}

/// Beside the shutter while recording: a track to slide right along, ending in a lock. Once locked, just the lock.
private struct LockTrack: View {
    let progress: CGFloat
    let locked: Bool

    var body: some View {
        HStack(spacing: 2) {
            if !locked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4 + 0.6 * progress))
                    .frame(width: 30)
            }
            Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(locked || progress > 0.95 ? .black : .white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(locked ? 1 : 0.2 + 0.8 * progress), in: .circle)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(3)
        .background(.black.opacity(locked ? 0 : 0.3), in: .capsule)
        .accessibilityHidden(true)
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
