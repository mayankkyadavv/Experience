import Observation
import SceneKit
import SwiftUI
import UIKit

/// The two earth styles under comparison. Temporary: the founder picks one, then the other is deleted.
enum GlobeStyle: String, CaseIterable, Identifiable {
    case dots, satellite
    var id: String { rawValue }
    var label: String { self == .dots ? "Dots" : "Satellite" }
}

/// A glowing point on the globe: one per city where you have Experiences (the brief clusters at world scale).
struct GlobeBeacon: Equatable, Identifiable {
    let id: String
    let lat: Double
    let lng: Double
    let color: UIColor
}

/// Drives the globe from SwiftUI: focus a place (before diving into a city) or release it back to spinning.
@MainActor @Observable
final class GlobeController {
    fileprivate(set) var focusRequest: (lat: Double, lng: Double, zoom: Bool, id: Int)?
    private var nextId = 0

    func focus(lat: Double, lng: Double, zoom: Bool = false) {
        nextId += 1
        focusRequest = (lat, lng, zoom, nextId)
    }

    func release() {
        nextId += 1
        focusRequest = nil
    }
}

/// A spinning earth in SceneKit. Drag to turn it (with inertia); it resumes its slow spin when let go.
struct GlobeView: UIViewRepresentable {
    var style: GlobeStyle
    var beacons: [GlobeBeacon]
    var controller: GlobeController
    var reduceMotion: Bool
    var onBeaconTap: (GlobeBeacon) -> Void = { _ in }

    func makeCoordinator() -> GlobeCoordinator { GlobeCoordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 120 // ProMotion; capped at the display's rate
        view.rendersContinuously = true
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraNode
        view.delegate = context.coordinator
        view.isPlaying = true
        #if DEBUG
        view.showsStatistics = ProcessInfo.processInfo.arguments.contains("-globeStats") // fps + draw calls
        #endif
        view.addGestureRecognizer(UIPanGestureRecognizer(target: context.coordinator, action: #selector(GlobeCoordinator.pan(_:))))
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(GlobeCoordinator.tap(_:))))
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.onBeaconTap = onBeaconTap
        c.reduceMotion = reduceMotion
        c.apply(style: style)
        c.apply(beacons: beacons)
        if let r = controller.focusRequest {
            if r.id != c.lastFocusId { c.lastFocusId = r.id; c.focus(lat: r.lat, lng: r.lng, zoom: r.zoom) }
        } else if c.isFocused {
            c.unfocus()
        }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: GlobeCoordinator) {
        view.isPlaying = false
    }
}

/// Owns the scene graph and motion. root → tilt (pitch) → spin (yaw) → earth layers and beacons.
/// What the earth looks like lives in an `EarthLook` (EarthLook.swift, DotsEarth.swift, SatelliteEarth.swift).
final class GlobeCoordinator: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let tilt = SCNNode()
    private let spin = SCNNode()
    private let clouds = SCNNode()
    private let earth = SCNNode()
    private let beaconLayer = SCNNode()
    private let atmosphere = SCNNode()
    private let lights = SCNNode()
    private var look: EarthLook?

    var onBeaconTap: (GlobeBeacon) -> Void = { _ in }
    var reduceMotion = false
    var lastFocusId = -1
    private(set) var isFocused = false

    private var style: GlobeStyle?
    private var beacons: [GlobeBeacon] = []

    // Spin state (radians). Touched on the render thread and the main thread; a lock keeps them consistent.
    private let lock = NSLock()
    private var yaw: Float = -1.3
    private var pitch: Float = 0.38
    private var velocity: Float = 0
    private var dragging = false
    private var lastInteraction = Date.distantPast
    private var lastTime: TimeInterval?

    private static let autoSpin: Float = 0.10 // rad/s
    private static let restingPitch: Float = 0.38 // show more of the north, where most people live
    private static let restingDistance: Float = 5.1 // leaves room for the atmosphere

    override init() {
        super.init()
        let camera = SCNCamera()
        camera.fieldOfView = 30
        camera.zNear = 0.1
        camera.zFar = 20
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, Self.restingDistance)
        scene.rootNode.addChildNode(cameraNode)

        scene.rootNode.addChildNode(tilt)
        tilt.addChildNode(spin)
        spin.addChildNode(earth)
        spin.addChildNode(clouds)
        spin.addChildNode(beaconLayer)
        scene.rootNode.addChildNode(atmosphere)
        scene.rootNode.addChildNode(lights)
    }

    // MARK: Style

    func apply(style newStyle: GlobeStyle) {
        guard newStyle != style else { return }
        style = newStyle
        lock.lock()
        defer { lock.unlock() }
        for layer in [earth, clouds, atmosphere, lights] { layer.childNodes.forEach { $0.removeFromParentNode() } }
        clouds.eulerAngles = SCNVector3Zero
        let layers = EarthLayers(earth: earth, clouds: clouds, atmosphere: atmosphere, lights: lights)
        look = switch newStyle {
        case .dots: DotsEarth(layers: layers)
        case .satellite: SatelliteEarth(layers: layers)
        }
        look?.setBeacons(beacons)
    }

    // MARK: Beacons

    func apply(beacons new: [GlobeBeacon]) {
        guard new != beacons else { return }
        beacons = new
        look?.setBeacons(new)
        beaconLayer.childNodes.forEach { $0.removeFromParentNode() }
        for b in new {
            let node = SCNNode()
            node.name = b.id
            node.position = Self.point(lat: b.lat, lng: b.lng, radius: 1.0)
            // Orient +y along the surface normal so the beam stands straight up.
            node.look(at: Self.point(lat: b.lat, lng: b.lng, radius: 2), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))

            let core = SCNSphere(radius: 0.022)
            core.firstMaterial?.lightingModel = .constant
            core.firstMaterial?.diffuse.contents = UIColor.white
            node.addChildNode(SCNNode(geometry: core))

            let beam = SCNCylinder(radius: 0.007, height: 0.12)
            beam.firstMaterial?.lightingModel = .constant
            beam.firstMaterial?.diffuse.contents = b.color
            beam.firstMaterial?.blendMode = .add
            let beamNode = SCNNode(geometry: beam)
            beamNode.position = SCNVector3(0, 0.06, 0)
            node.addChildNode(beamNode)

            let ring = SCNTube(innerRadius: 0.035, outerRadius: 0.045, height: 0.001)
            ring.firstMaterial?.lightingModel = .constant
            ring.firstMaterial?.diffuse.contents = b.color
            ring.firstMaterial?.blendMode = .add
            let ringNode = SCNNode(geometry: ring)
            node.addChildNode(ringNode)
            if !reduceMotion {
                let grow = SCNAction.group([.scale(to: 2.6, duration: 1.8), .fadeOut(duration: 1.8)])
                grow.timingMode = .easeOut
                ringNode.runAction(.repeatForever(.sequence([.group([.scale(to: 1, duration: 0), .fadeIn(duration: 0)]), grow, .wait(duration: 0.4)])))
            }
            beaconLayer.addChildNode(node)
        }
    }

    /// SCNSphere maps longitude 0 to +z and east toward +x.
    static func point(lat: Double, lng: Double, radius: Double) -> SCNVector3 {
        let φ = lat * .pi / 180, λ = lng * .pi / 180
        return SCNVector3(Float(radius * cos(φ) * sin(λ)), Float(radius * sin(φ)), Float(radius * cos(φ) * cos(λ)))
    }

    // MARK: Focus

    func focus(lat: Double, lng: Double, zoom: Bool) {
        lock.lock()
        isFocused = true
        velocity = 0
        // Choose the yaw closest to the current one so it turns the short way round.
        var target = Float(-lng * .pi / 180)
        while target - yaw > .pi { target -= 2 * .pi }
        while target - yaw < -.pi { target += 2 * .pi }
        yaw = target
        pitch = Float(lat * .pi / 180)
        lock.unlock()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : 0.9
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0, 0.15, 1)
        spin.eulerAngles.y = target
        tilt.eulerAngles.x = pitch
        cameraNode.position.z = zoom ? 3.5 : Self.restingDistance
        SCNTransaction.commit()
    }

    func unfocus() {
        lock.lock()
        isFocused = false
        pitch = Self.restingPitch
        lastInteraction = Date()
        lock.unlock()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : 0.9
        tilt.eulerAngles.x = Self.restingPitch
        cameraNode.position.z = Self.restingDistance
        SCNTransaction.commit()
    }

    // MARK: Gestures

    @objc func pan(_ g: UIPanGestureRecognizer) {
        guard let view = g.view else { return }
        let scale = Float(2.4 / max(view.bounds.width, 1))
        lock.lock()
        defer { lock.unlock() }
        guard !isFocused else { return }
        switch g.state {
        case .began:
            dragging = true
            velocity = 0
        case .changed:
            let t = g.translation(in: view)
            g.setTranslation(.zero, in: view)
            yaw += Float(t.x) * scale
            pitch = min(1.1, max(-1.1, pitch + Float(t.y) * scale))
        default:
            dragging = false
            velocity = Float(g.velocity(in: view).x) * scale
            lastInteraction = Date()
        }
    }

    @objc func tap(_ g: UITapGestureRecognizer) {
        guard let view = g.view as? SCNView else { return }
        let hits = view.hitTest(g.location(in: view), options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .boundingBoxOnly: true])
        for hit in hits {
            var node: SCNNode? = hit.node
            while let n = node, n.parent !== beaconLayer { node = n.parent }
            if let id = node?.name, let beacon = beacons.first(where: { $0.id == id }) {
                onBeaconTap(beacon)
                return
            }
        }
    }

    // MARK: Frame loop

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = Float(min(1.0 / 20, time - (lastTime ?? time)))
        lastTime = time
        lock.lock()
        defer { lock.unlock() }
        guard !isFocused else { look?.update(dt: dt, reduceMotion: reduceMotion); return }
        if !dragging {
            // Inertia decays; then the slow spin eases back in, and the pitch settles to rest.
            velocity *= pow(0.04, dt)
            let idle = Float(min(1, max(0, Date().timeIntervalSince(lastInteraction) - 1.2) / 1.5))
            yaw += (velocity + (reduceMotion ? 0 : Self.autoSpin * idle)) * dt
            pitch += (Self.restingPitch - pitch) * min(1, dt * 1.2 * idle)
        }
        spin.eulerAngles.y = yaw
        tilt.eulerAngles.x = pitch
        look?.update(dt: dt, reduceMotion: reduceMotion)
        // Beacons on the far side fade out instead of poking past the limb.
        for node in beaconLayer.childNodes {
            let z = node.presentation.worldPosition.z
            node.opacity = CGFloat(min(1, max(0, (z - 0.05) / 0.25)))
        }
    }
}
