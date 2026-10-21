import SceneKit
import UIKit

/// The nodes a look may fill. The coordinator empties them when the style changes.
struct EarthLayers {
    /// Spins with the globe (radius 1 is the surface; beacons sit at 1.0).
    let earth: SCNNode
    /// Spins with the globe; a look may add its own drift in `update`.
    let clouds: SCNNode
    /// Not rotated: for view-dependent effects such as an atmosphere halo.
    let atmosphere: SCNNode
    /// Not rotated: the look's lights (the camera looks down -z from z ≈ 5.1).
    let lights: SCNNode
}

/// One way the earth can look. Builds its nodes in `init`, then animates them every frame.
protocol EarthLook: AnyObject {
    init(layers: EarthLayers)
    /// Render thread, once per frame. `dt` is seconds since the last frame.
    func update(dt: Float, reduceMotion: Bool)
    /// Main thread, whenever the beacons change (and right after `init`).
    func setBeacons(_ beacons: [GlobeBeacon])
}

extension EarthLook {
    func update(dt: Float, reduceMotion: Bool) {}
    func setBeacons(_ beacons: [GlobeBeacon]) {}
}

/// Small shared shader helpers. Looks that need something different keep their own copy instead of changing these.
enum EarthShaders {
    /// A fragment modifier that adds a colored fresnel glow at the limb of a surface.
    static func rim(r: Double, g: Double, b: Double, power: Double, strength: Double) -> String {
        """
        float3 n = normalize(_surface.normal);
        float3 v = normalize(_surface.view);
        float rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), \(power));
        _output.color.rgb += float3(\(r), \(g), \(b)) * rim * \(strength);
        """
    }

    /// An atmosphere: a larger back-faced sphere, additive, bright at the earth's edge and fading outward.
    static func halo(r: Double, g: Double, b: Double, strength: Double, radius: CGFloat = 1.16) -> SCNNode {
        let s = SCNSphere(radius: radius)
        s.segmentCount = 96
        let m = s.firstMaterial!
        m.lightingModel = .constant
        m.cullMode = .front
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.diffuse.contents = UIColor.black
        m.shaderModifiers = [.fragment: """
        // Back faces: |n·v| is ~0.5 at the earth's edge and 0 at the halo's rim, so this fades outward.
        float3 n = normalize(_surface.normal);
        float3 v = normalize(_surface.view);
        float d = clamp(abs(dot(n, v)) / 0.5, 0.0, 1.0);
        float glow = pow(d, 3.0) * \(strength);
        _output.color = float4(float3(\(r), \(g), \(b)) * glow, glow);
        """]
        let node = SCNNode(geometry: s)
        node.renderingOrder = 2
        return node
    }
}
