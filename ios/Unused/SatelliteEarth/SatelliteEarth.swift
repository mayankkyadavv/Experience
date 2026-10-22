import Metal
import SceneKit
import UIKit

/// NASA's Blue Marble lit by a low sun: a soft terminator, warm city lights on the night side, sun glint on the
/// oceans only, terrain relief, clouds that cast faint shadows, and a thin atmosphere that warms at the terminator.
/// One draw for the earth (everything is shaded in one pass) and one for the atmosphere.
/// The textures load in the background (SatelliteTextures.swift); the earth fades in when they are ready.
final class SatelliteEarth: EarthLook {
    private let earthMaterial: SCNMaterial
    private let fading: [SCNNode]
    private var textures: SatelliteTextures?
    private var cloudShift: Float = 0

    init(layers: EarthLayers) {
        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 160
        let m = sphere.firstMaterial!
        m.lightingModel = .constant
        m.diffuse.mipFilter = .linear
        m.diffuse.maxAnisotropy = 16
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .clamp
        m.setValue(Float(0), forKey: "cloudShift")
        m.shaderModifiers = [.fragment: SatelliteShaders.surface]
        earthMaterial = m
        let earthNode = SCNNode(geometry: sphere)
        layers.earth.addChildNode(earthNode)

        let shell = SCNSphere(radius: SatelliteShaders.shellRadius)
        shell.segmentCount = 72
        let a = shell.firstMaterial!
        a.lightingModel = .constant
        a.cullMode = .front
        a.blendMode = .add
        a.writesToDepthBuffer = false
        a.diffuse.contents = UIColor.black
        a.shaderModifiers = [.fragment: SatelliteShaders.atmosphere]
        let shellNode = SCNNode(geometry: shell)
        shellNode.renderingOrder = 2
        layers.atmosphere.addChildNode(shellNode)

        fading = [earthNode, shellNode]
        fading.forEach { $0.opacity = 0 }
        SatelliteTextures.load { [weak self] t in self?.show(t) }
    }

    private func show(_ t: SatelliteTextures?) {
        guard let t else { return }
        textures = t
        earthMaterial.diffuse.contents = t.day
        earthMaterial.setValue(SCNMaterialProperty(contents: t.clouds), forKey: "cloudsTex")
        earthMaterial.setValue(SCNMaterialProperty(contents: t.data), forKey: "surfaceTex")
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        fading.forEach { $0.opacity = 1 }
        SCNTransaction.commit()
    }

    func update(dt: Float, reduceMotion: Bool) {
        guard !reduceMotion else { return }
        // Clouds drift east very slowly, about once round the world in half an hour.
        cloudShift = (cloudShift + dt * 0.00055).truncatingRemainder(dividingBy: 1)
        earthMaterial.setValue(cloudShift, forKey: "cloudShift")
    }
}

/// Shader modifiers for the satellite earth. Directions are in view space; the camera never rotates, so the sun stays put
/// on screen while the globe turns under it.
enum SatelliteShaders {
    static let shellRadius: CGFloat = 1.1

    /// Toward the sun: upper left and in front, so a crescent of night sits on the lower right.
    private static let sun = "normalize(float3(-0.80, 0.30, 0.52))"

    static let surface = """
    #pragma arguments
    texture2d<float> cloudsTex;
    texture2d<float> surfaceTex;
    float cloudShift;
    #pragma body
    constexpr sampler ss(filter::linear, mip_filter::linear, s_address::repeat, t_address::clamp_to_edge, max_anisotropy(8));
    float2 uv = _surface.diffuseTexcoord;
    float3 V = normalize(_surface.view);
    float3 Ng = normalize(_surface.normal);
    float3 L = \(sun);

    // Local east / north from the globe's axis.
    float3 axis = normalize((scn_node.modelViewTransform * float4(0.0, 1.0, 0.0, 0.0)).xyz);
    float3 E = cross(axis, Ng);
    float coslat = length(E);
    E = coslat > 1e-4 ? E / coslat : float3(1.0, 0.0, 0.0);
    float3 Nn = cross(Ng, E);

    float4 sf = surfaceTex.sample(ss, uv);
    // Water: the 4K mask, sharpened to the 8K day map's own coastline (water there is clearly bluer than red).
    float3 albedo = _surface.diffuse.rgb;
    float water = smoothstep(0.2, 0.8, sf.r) * smoothstep(0.004, 0.02, albedo.b - albedo.r);
    float lights = sf.g;
    float2 slope = sf.ba * 2.0 - 1.0;
    float3 N = normalize(Ng - (E * slope.x + Nn * slope.y) * 0.55);

    float mu = dot(Ng, L);                  // sun height over the horizon
    float day = smoothstep(-0.10, 0.16, mu);
    float3 sunColor = mix(float3(1.0, 0.50, 0.26), float3(1.0, 0.97, 0.93), smoothstep(-0.05, 0.38, mu));

    // Clouds and their shadows (cast a little away from the sun).
    float2 cuv = float2(uv.x + cloudShift, uv.y);
    float cloud = smoothstep(0.10, 0.82, cloudsTex.sample(ss, cuv).r);
    float2 sunT = float2(dot(L, E), dot(L, Nn)) * (0.006 / max(mu, 0.18));
    float2 shadowUV = cuv + float2(sunT.x / (6.2832 * max(coslat, 0.15)), -sunT.y / 3.1416);
    float shadow = smoothstep(0.10, 0.82, cloudsTex.sample(ss, shadowUV).r);

    // Ground: a little more saturated, oceans deeper and bluer.
    float lum = dot(albedo, float3(0.2126, 0.7152, 0.0722));
    albedo = max(mix(float3(lum), albedo, 1.08), 0.0);
    albedo = mix(albedo, albedo * float3(0.46, 0.74, 1.04) + float3(0.0, 0.002, 0.007), water);
    float diffuse = max(dot(N, L), 0.0) * smoothstep(-0.05, 0.12, mu);
    float3 color = albedo * sunColor * (diffuse * 1.7 + 0.006) + float3(0.001, 0.002, 0.006) * (1.0 - day); // faint blue night
    color *= 1.0 - 0.42 * shadow * (1.0 - cloud) * day;

    // Sun glint on open water only.
    float3 H = normalize(L + V);
    float nh = max(dot(Ng, H), 0.0);
    float glint = pow(nh, 110.0) * 0.55 + pow(nh, 20.0) * 0.07;
    color += glint * water * (1.0 - cloud) * day * sunColor;

    // Clouds catch the light; at the terminator they turn warm.
    float cloudLight = smoothstep(-0.06, 0.5, mu) * 0.5 + max(mu, 0.0) * 0.55;
    float3 cloudColor = float3(0.96, 0.98, 1.0) * sunColor * cloudLight * 1.3 + float3(0.004, 0.006, 0.012);
    color = mix(color, cloudColor, cloud * 0.94);

    // City lights on the night side, dimmed by clouds.
    // A blurred mip of the same lights adds a soft glow around each city.
    float night = 1.0 - smoothstep(-0.16, 0.04, mu);
    float glow = surfaceTex.sample(ss, uv, bias(2.5)).g;
    float city = pow(lights, 1.15) * 1.7 + glow * 0.9;
    color += float3(1.0, 0.62, 0.30) * city * night * (1.0 - 0.75 * cloud);

    // Air: blue haze toward the limb on the day side, warm at the terminator.
    float rim = 1.0 - max(dot(Ng, V), 0.0);
    float haze = pow(rim, 3.0);
    float3 blue = float3(0.30, 0.56, 1.0) * smoothstep(-0.12, 0.45, mu);
    float3 warm = float3(1.0, 0.42, 0.16) * exp(-pow((mu - 0.03) / 0.08, 2.0)) * pow(rim, 2.0) * 0.5;
    color = mix(color, blue * 1.1, haze * 0.7) + (blue + warm) * pow(rim, 6.0) * 0.55;

    // Gentle filmic shoulder so highlights roll off instead of clipping.
    color = 1.0 - exp(-color * 1.4);
    color = mix(color, color * color * (3.0 - 2.0 * color), 0.25); // a touch of contrast
    _output.color = float4(color, 1.0);
    """

    /// The thin outer glow, from the ray's closest approach to the earth's center (b): dense near the surface, gone by
    /// the shell's edge. Lit by the same sun, warm in a band at the terminator.
    static let atmosphere = """
    #pragma body
    float3 L = \(sun);
    float3 d = normalize(_surface.position);
    float3 c = (scn_node.modelViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz;
    float3 p = dot(c, d) * d - c;
    float b = length(p);
    float3 r = p / max(b, 1e-4);
    float h = max(b - 1.0, 0.0);
    float edge = 1.0 - smoothstep(0.0, \(shellRadius - 1.0), h);
    float glow = (exp(-h / 0.009) * 0.85 + exp(-h / 0.032) * 0.18) * edge;
    float m = dot(r, L);
    float3 col = float3(0.30, 0.58, 1.0) * smoothstep(-0.30, 0.40, m)
               + float3(1.0, 0.45, 0.18) * exp(-pow((m + 0.02) / 0.09, 2.0)) * 0.45;
    col *= glow;
    _output.color = float4(col, max(col.r, max(col.g, col.b)));
    """
}
