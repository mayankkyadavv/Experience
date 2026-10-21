import AVFoundation
import Observation
import UIKit

/// A photo or video the user just took, saved in the app's documents folder (ADR-012: media stays on the device).
struct CapturedMedia: Identifiable, Equatable {
    enum Kind: String { case photo, video }
    let id = UUID()
    let kind: Kind
    let url: URL
    let takenAt: Date
    var duration: TimeInterval?
}

/// The camera: one session, photo + movie outputs, lens-aware zoom, focus, flip, flash.
/// Session work runs on its own queue; observable state is updated on the main actor.
@MainActor @Observable
final class CameraModel: NSObject {
    enum State: Equatable { case starting, running, denied, unavailable }

    let session = AVCaptureSession()
    private(set) var state: State = .starting
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var isRecording = false
    private(set) var recordingStarted: Date?
    var flash: AVCaptureDevice.FlashMode = .off
    /// Zoom as people read it (0.5×, 1×, 2×…), independent of which lens is behind it.
    private(set) var zoom: CGFloat = 1
    private(set) var minZoom: CGFloat = 1
    private(set) var maxZoom: CGFloat = 10
    /// Lens presets available on this device, in display terms.
    private(set) var presets: [CGFloat] = [1]
    var captured: CapturedMedia?

    static let maxVideo: TimeInterval = 60

    private let queue = DispatchQueue(label: "experience.camera")
    nonisolated(unsafe) private var device: AVCaptureDevice?
    nonisolated(unsafe) private var videoInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var audioAdded = false
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    /// Device zoom factor = display zoom / multiplier (0.5 when the virtual device starts on the ultra wide).
    nonisolated(unsafe) private var multiplier: CGFloat = 1

    // MARK: Lifecycle

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { state = .denied; return }
        case .denied, .restricted:
            state = .denied
            return
        default:
            break
        }
        guard AVCaptureDevice.default(for: .video) != nil else { state = .unavailable; return }
        let pos = position
        let ok = await run { [self] in configure(position: pos) }
        guard ok else { state = .unavailable; return }
        applyDeviceInfo()
        await run { [self] in if !session.isRunning { session.startRunning() } }
        state = .running
    }

    func stop() {
        queue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    /// Picks the best camera for a position: the virtual multi-lens camera on the back when there is one.
    nonisolated private static func camera(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: position).devices.first
    }

    nonisolated private func configure(position: AVCaptureDevice.Position) -> Bool {
        guard let cam = Self.camera(position), let input = try? AVCaptureDeviceInput(device: cam) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        if let videoInput { session.removeInput(videoInput) }
        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        videoInput = input
        device = cam
        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .balanced
        }
        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: Self.maxVideo, preferredTimescale: 600)
        }
        let ultraWideFirst = cam.isVirtualDevice && cam.constituentDevices.first?.deviceType == .builtInUltraWideCamera
        multiplier = ultraWideFirst ? 1 / (cam.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 2) : 1
        // Start at 1× (the wide lens), like the system camera.
        try? cam.lockForConfiguration()
        cam.videoZoomFactor = max(cam.minAvailableVideoZoomFactor, min(1 / multiplier, cam.maxAvailableVideoZoomFactor))
        cam.unlockForConfiguration()
        return true
    }

    private func applyDeviceInfo() {
        guard let device else { return }
        minZoom = device.minAvailableVideoZoomFactor * multiplier
        maxZoom = min(device.maxAvailableVideoZoomFactor, 15 / multiplier) * multiplier
        zoom = device.videoZoomFactor * multiplier
        var lenses: [CGFloat] = []
        if minZoom < 1 { lenses.append(0.5) }
        lenses.append(1)
        if device.isVirtualDevice {
            for f in device.virtualDeviceSwitchOverVideoZoomFactors.map({ CGFloat($0.doubleValue) * multiplier }) where f > 1.01 {
                lenses.append((f * 2).rounded() / 2)
            }
        }
        if !lenses.contains(where: { $0 > 1 }), maxZoom >= 2 { lenses.append(2) }
        presets = Array(Set(lenses)).sorted()
    }

    // MARK: Controls

    func flip() async {
        guard !isRecording else { return }
        position = position == .back ? .front : .back
        let pos = position
        _ = await run { [self] in configure(position: pos) }
        applyDeviceInfo()
    }

    /// Display zoom (0.5…max). Smooth when `ramp` is set (preset taps), immediate for pinches.
    func setZoom(_ value: CGFloat, ramp: Bool = false) {
        guard let device else { return }
        let display = max(minZoom, min(value, maxZoom))
        zoom = display
        let factor = display / multiplier
        queue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            if ramp { device.ramp(toVideoZoomFactor: factor, withRate: 8) } else { device.videoZoomFactor = factor }
            device.unlockForConfiguration()
        }
    }

    /// Focus and expose at a point in device coordinates (0…1).
    func focus(at point: CGPoint) {
        guard let device else { return }
        queue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point; device.focusMode = .autoFocus }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point; device.exposureMode = .autoExpose }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        }
    }

    // MARK: Capture

    func takePhoto() {
        guard state == .running, !isRecording else { return }
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flash) { settings.flashMode = flash }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() async {
        guard state == .running, !isRecording else { return }
        // Ask for the microphone the first time someone records, not before.
        if !audioAdded, await AVCaptureDevice.requestAccess(for: .audio) {
            await run { [self] in
                guard let mic = AVCaptureDevice.default(for: .audio), let input = try? AVCaptureDeviceInput(device: mic),
                      session.canAddInput(input) else { return }
                session.beginConfiguration()
                session.addInput(input)
                session.commitConfiguration()
                audioAdded = true
            }
        }
        let url = Self.newFile("mov")
        if flash == .on, let device, device.hasTorch {
            queue.async { try? device.lockForConfiguration(); device.torchMode = .on; device.unlockForConfiguration() }
        }
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        recordingStarted = Date()
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
        if let device, device.hasTorch {
            queue.async { try? device.lockForConfiguration(); device.torchMode = .off; device.unlockForConfiguration() }
        }
    }

    // MARK: Files

    nonisolated static var folder: URL {
        let url = URL.documentsDirectory.appending(path: "Captures", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    nonisolated static func newFile(_ ext: String) -> URL { folder.appending(path: "\(UUID().uuidString).\(ext)") }

    func discard(_ media: CapturedMedia) {
        try? FileManager.default.removeItem(at: media.url)
        if captured == media { captured = nil }
    }

    #if LOCAL_BACKEND
    /// Simulator stand-in for a real capture, so the rest of the flow can be exercised.
    func useTestPhoto() {
        let size = CGSize(width: 1080, height: 1920)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(rgb: 0x2D6BFF).cgColor, UIColor(rgb: 0xE63E8C).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        let url = Self.newFile("jpg")
        guard let data = image.jpegData(compressionQuality: 0.8), (try? data.write(to: url)) != nil else { return }
        captured = CapturedMedia(kind: .photo, url: url, takenAt: Date())
    }
    #endif

    // MARK: Helpers

    @discardableResult
    private func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { c in queue.async { c.resume(returning: work()) } }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        let url = Self.newFile("heic")
        guard (try? data.write(to: url)) != nil else { return }
        Task { @MainActor in captured = CapturedMedia(kind: .photo, url: url, takenAt: Date()) }
    }
}

extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        let duration = output.recordedDuration.seconds
        Task { @MainActor in
            isRecording = false
            let started = recordingStarted ?? Date()
            recordingStarted = nil
            // Reaching the 60 s limit reports an "error" but the file is complete.
            if FileManager.default.fileExists(atPath: url.path()), duration > 0.3 {
                captured = CapturedMedia(kind: .video, url: url, takenAt: started, duration: duration)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
