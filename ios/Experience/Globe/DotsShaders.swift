import SceneKit
import UIKit

/// Shader modifiers for the Dots earth. Colors are designed in sRGB and converted to linear (SceneKit renders linear).
enum DotsShaders {
    /// Rows of dots from pole to pole (0.8° apart); each row holds as many dots as fit, so every dot covers the same area.
    static let rows = 225

    /// The sun, in view space: up and to the left, slightly in front, so the lit face looks at you and the night side wraps the right limb.
    static let sun = "normalize(float3(-0.62, 0.48, 0.62))"

    /// The whole earth in one pass: ocean, a faint ocean dot field, land dots with crisp anti-aliased edges,
    /// sunlight and night, the atmosphere's inner rim, and a slow ripple of light around your city.
    static let earth = """
    #pragma arguments
    texture2d<float> landSDF;
    texture2d<float> climate;
    float4 beacon;
    float4 beaconTint;
    float motion;

    #pragma body
    const float PI = 3.14159265;
    const float ROWS = \(rows).0;
    const float S = PI / ROWS;
    float t = scn_frame.time * motion;

    // Where on the earth this pixel is (lon 0 is +z, east is +x).
    float3 p = normalize((scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz);
    float lat = asin(clamp(p.y, -1.0, 1.0));
    float lng = atan2(p.x, p.z);

    // The equal-area cell this pixel falls in, and its dot's center.
    float row = min(floor((lat + PI * 0.5) / S), ROWS - 1.0);
    float latC = -PI * 0.5 + (row + 0.5) * S;
    float n = max(1.0, round(2.0 * PI * cos(latC) / S));
    float cellW = 2.0 * PI / n;
    float k = min(floor((lng + PI) / cellW), n - 1.0);
    float lngC = -PI + (k + 0.5) * cellW;
    // Distance to the center in steps, measured on the sphere so dots stay round up to the poles.
    // Continuous across cells in a row (and across the date line), so its derivative gives a clean edge width.
    float d = length(float2((lng - lngC) * cos(lat), lat - latC)) / S;
    float w = clamp(length(float2(dfdx(d), dfdy(d))), 1e-4, 0.6);
    float hsh = fract(sin(row * 12.9898 + k * 78.233) * 43758.5453);

    // Land: the coast distance (degrees) at the dot's center. Coastal dots shrink, which draws the coastline finer than the grid.
    constexpr sampler smp(coord::normalized, filter::linear, address::repeat);
    float2 uv = float2((lngC + PI) / (2.0 * PI), (PI * 0.5 - latC) / PI);
    float sdf = (landSDF.sample(smp, uv, level(0)).r - 0.5) * 4.0;
    float inland = clamp((sdf + 0.12) / 0.7, 0.0, 1.0);
    bool isLand = sdf > -0.12;

    // Light.
    float3 N = normalize(_surface.normal);
    float3 V = normalize(_surface.view);
    float3 L = \(sun);
    float ndl = dot(N, L);
    float day = smoothstep(-0.35, 0.45, ndl);
    float facing = clamp(dot(N, V), 0.0, 1.0);

    // Your city: dots near it glow in its color, and a ring of light leaves it every few seconds.
    float3 cdir = float3(cos(latC) * sin(lngC), sin(latC), cos(latC) * cos(lngC));
    float ang = acos(clamp(dot(cdir, beacon.xyz), -1.0, 1.0));
    float near = beacon.w * exp(-pow(ang / 0.055, 2.0));
    float phase = fract(t * 0.22);
    float ring = beacon.w * motion * exp(-pow((ang - (0.03 + phase * 0.30)) / 0.018, 2.0)) * pow(1.0 - phase, 1.5);
    float lit = clamp(near + ring * 0.9, 0.0, 1.0);

    // Ocean: deep navy, warmer and lighter toward the sun, with a soft sheen where the sun reflects.
    float3 oceanNight = float3(0.020, 0.028, 0.075);
    float3 oceanDay = float3(0.060, 0.090, 0.215);
    float3 ocean = mix(oceanNight, oceanDay, day);
    float sheen = pow(clamp(dot(reflect(-L, N), V), 0.0, 1.0), 18.0);
    ocean += float3(0.36, 0.42, 0.85) * sheen * 0.10;

    // The dot's color.
    float3 dotColor;
    float r;
    if (isLand) {
        // The dot's climate (tools/globe/climate.swift): warm deserts and steppe, jade tropics, green temperate land,
        // teal into boreal blue across the cold continents, lavender tundra, white ice.
        dotColor = climate.sample(smp, uv, level(0)).rgb;
        // Each dot breathes on its own slow clock; a faint band of light sweeps west to east.
        float breathe = 0.93 + 0.07 * sin(t * 0.7 + hsh * 6.2832);
        float sweep = 1.0 + 0.06 * motion * sin(lngC * 2.0 - t * 0.35);
        dotColor *= (0.90 + 0.10 * hsh) * mix(1.0, breathe * sweep, motion);
        // Night side: dimmer and cooler.
        float3 nightColor = mix(dotColor, float3(0.30, 0.36, 0.80), 0.40) * 0.38;
        dotColor = mix(nightColor, dotColor * 1.15, day);
        r = 0.38 * mix(0.55, 1.0, inland);
    } else {
        // A faint field of small dots across the sea, so the whole sphere reads as one material.
        dotColor = mix(ocean, float3(0.42, 0.50, 0.95), mix(0.04, 0.10, day));
        r = 0.11;
    }
    dotColor = mix(dotColor, beaconTint.rgb * 1.15 + 0.05, lit * (isLand ? 0.75 : 0.85));
    r = mix(r, isLand ? 0.42 : 0.30, lit);

    // Coverage with a one-pixel edge; when dots get smaller than a pixel (at the limb), fade to their average so nothing shimmers.
    float cov = clamp((r - d) / w + 0.5, 0.0, 1.0);
    cov = mix(cov, PI * r * r, clamp(w / r - 0.6, 0.0, 1.0));

    float3 col = mix(pow(ocean, 2.2), pow(dotColor, 2.2), cov);
    // Land dots give off a little light into the gaps, so continents glow instead of reading as a pattern.
    float glow = isLand ? 0.16 * exp(-max(d - r, 0.0) * 7.0) * (1.0 - cov) * mix(0.4, 1.0, day) : 0.0;
    col += pow(dotColor, 2.2) * glow;

    // The atmosphere seen through the edge of the earth, brighter on the sunlit side.
    float rim = pow(1.0 - facing, 3.0);
    float3 air = mix(float3(0.30, 0.30, 0.95), float3(0.55, 0.78, 1.00), day);
    col += pow(air, 2.2) * rim * mix(0.10, 0.32, day);

    _output.color = float4(col, 1.0);
    """

    /// A thin atmosphere outside the limb. Computed from how close each view ray passes to the earth,
    /// so the glow is smooth and correct at any distance; brighter and lighter on the sunlit side.
    static func atmosphere(radius: CGFloat = 1.13) -> SCNNode {
        let s = SCNSphere(radius: radius)
        s.segmentCount = 64
        let m = s.firstMaterial!
        m.lightingModel = .constant
        m.cullMode = .front
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.diffuse.contents = UIColor.black
        m.shaderModifiers = [.fragment: """
        float3 c = (scn_node.modelViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz;
        float3 dir = normalize(_surface.position);
        float3 closest = dir * dot(c, dir);
        float b = length(closest - c);
        float x = clamp((b - 1.0) / (\(radius) - 1.0), 0.0, 1.0);
        // Falls off fast, like real air, and reaches zero at the shell.
        float glow = exp(-x * 5.0) * (1.0 - x) * (1.0 - x);
        float3 L = \(sun);
        float side = dot(normalize(closest - c), L) * 0.5 + 0.5;
        float3 air = mix(float3(0.30, 0.28, 0.95), float3(0.55, 0.80, 1.00), side);
        float strength = mix(0.25, 0.85, side);
        float3 col = pow(air, 2.2) * glow * strength;
        _output.color = float4(col, max(col.r, max(col.g, col.b)));
        """]
        let node = SCNNode(geometry: s)
        node.renderingOrder = 2
        return node
    }
}
