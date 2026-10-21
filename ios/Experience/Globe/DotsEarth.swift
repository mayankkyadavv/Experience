import ImageIO
import Metal
import SceneKit
import UIKit

/// Land as equal-area dots colored by climate (Köppen-Geiger) over a deep night ocean, lit by a soft sun.
/// The dots are drawn per pixel in one shader (DotsShaders), so they stay round and sharp at any zoom;
/// the textures are a 2 MB coastline distance field and a 2 MB climate color map. Two draws: the earth and its atmosphere.
final class DotsEarth: EarthLook {
    private let earthMaterial: SCNMaterial
    private let earthNode: SCNNode
    private var motion: Float = -1

    init(layers: EarthLayers) {
        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 128 // the silhouette stays within a third of a pixel at full size
        let m = sphere.firstMaterial!
        m.lightingModel = .constant
        m.diffuse.contents = UIColor.black
        m.shaderModifiers = [.fragment: DotsShaders.earth]
        m.setValue(SCNMaterialProperty(contents: Self.landField as Any), forKey: "landSDF")
        m.setValue(SCNMaterialProperty(contents: Self.climateColors as Any), forKey: "climate")
        m.setValue(NSValue(scnVector4: SCNVector4Zero), forKey: "beacon")
        m.setValue(NSValue(scnVector4: SCNVector4(1, 0.7, 0, 1)), forKey: "beaconTint")
        m.setValue(1.0, forKey: "motion")
        earthMaterial = m
        earthNode = SCNNode(geometry: sphere)
        layers.earth.addChildNode(earthNode)
        layers.atmosphere.addChildNode(DotsShaders.atmosphere())
    }

    func update(dt: Float, reduceMotion: Bool) {
        let m: Float = reduceMotion ? 0 : 1
        if m != motion {
            motion = m
            earthMaterial.setValue(Double(m), forKey: "motion")
        }
    }

    /// Lights the dots around your city (the first beacon) in its color.
    func setBeacons(_ beacons: [GlobeBeacon]) {
        guard let b = beacons.first else {
            earthMaterial.setValue(NSValue(scnVector4: SCNVector4Zero), forKey: "beacon")
            return
        }
        let p = GlobeCoordinator.point(lat: b.lat, lng: b.lng, radius: 1)
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
        b.color.getRed(&r, green: &g, blue: &bl, alpha: &a)
        earthMaterial.setValue(NSValue(scnVector4: SCNVector4(p.x, p.y, p.z, 1)), forKey: "beacon")
        earthMaterial.setValue(NSValue(scnVector4: SCNVector4(Float(r), Float(g), Float(bl), 1)), forKey: "beaconTint")
    }

    /// The coastline distance field (tools/globe/dots.swift) as a one-channel texture: 2048x1024, 2 MB on the GPU.
    private static let landField = texture("dots_land", gray: true)

    /// Climate colors (tools/globe/climate.swift), 1024x512 sRGB, 2 MB on the GPU. Loaded as raw values: the shader
    /// does its own sRGB-to-linear conversion, like every other color in it.
    private static let climateColors = texture("dots_climate", gray: false)

    private static func texture(_ name: String, gray: Bool) -> Any? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let w = img.width, h = img.height, bpp = gray ? 1 : 4
        guard let device = MTLCreateSystemDefaultDevice() else { return UIImage(cgImage: img) }
        var px = [UInt8](repeating: 0, count: w * h * bpp)
        let drew = px.withUnsafeMutableBytes { buf -> Bool in
            let space = gray ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!
            let info = gray ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * bpp,
                                      space: space, bitmapInfo: info) else { return false }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: gray ? .r8Unorm : .rgba8Unorm, width: w, height: h, mipmapped: false)
        desc.usage = .shaderRead
        guard drew, let tex = device.makeTexture(descriptor: desc) else { return UIImage(cgImage: img) }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: px, bytesPerRow: w * bpp)
        return tex
    }
}
