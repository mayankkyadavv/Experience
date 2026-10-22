import Accelerate
import ImageIO
import Metal
import UIKit

/// The satellite earth's three textures, turned from small bundled HEIC files into ASTC 4×4 Metal textures with full
/// mip chains on a background thread (ImageIO's ASTC encoder is fast). ASTC 4×4 keeps the 8K day map sharp at
/// 1 byte per pixel: about 43 MB of GPU memory for the day map and 11 MB each for clouds and data.
/// Images come from `tools/globe/satellite.swift`.
final class SatelliteTextures {
    /// 8192×4096 color (sRGB).
    let day: MTLTexture
    /// 4096×2048 cloud brightness in every channel.
    let clouds: MTLTexture
    /// 4096×2048 R water mask · G night lights · B slope east · A slope north.
    let data: MTLTexture

    private init(day: MTLTexture, clouds: MTLTexture, data: MTLTexture) {
        self.day = day
        self.clouds = clouds
        self.data = data
    }

    // Main thread only. Shared while any satellite earth holds them; rebuilt after they are released.
    private static weak var cached: SatelliteTextures?
    private static var waiting: [(SatelliteTextures?) -> Void] = []

    /// Calls `done` on the main thread with the textures (synchronously if they are already loaded), or nil if they can't be built.
    static func load(_ done: @escaping (SatelliteTextures?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        if let cached { return done(cached) }
        waiting.append(done)
        guard waiting.count == 1 else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            let built = build()
            #if DEBUG
            print("SatelliteTextures: built in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
            #endif
            DispatchQueue.main.async {
                cached = built
                let callbacks = waiting
                waiting = []
                callbacks.forEach { $0(built) }
            }
        }
    }

    // MARK: Building

    private static func build() -> SatelliteTextures? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let compressed = device.supportsFamily(.apple2) // ASTC; every iOS 17 device and Apple-silicon simulators
        func image(_ name: String) -> CGImage? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "heic"),
                  let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(src, 0, nil)
        }
        return autoreleasepool {
            // Each decoded image is released as soon as it is drawn, so only one full-size copy lives at a time.
            guard var px = image("satellite_day").map({ Pixels($0, gray: false) }),
                  let day = makeTexture(device, &px, srgb: true, compressed: compressed) else { return nil }

            guard var cloudPx = image("satellite_clouds").map({ Pixels($0, gray: false) }),
                  let clouds = makeTexture(device, &cloudPx, srgb: false, compressed: compressed) else { return nil }

            // The data atlas holds four quadrants; interleave them into the four channels.
            guard let atlas = image("satellite_data").map({ Pixels($0, gray: true) }) else { return nil }
            let w = atlas.width / 2, h = atlas.height / 2
            var dataPx = Pixels(width: w, height: h)
            atlas.bytes.withUnsafeBytes { a in
                dataPx.bytes.withUnsafeMutableBytes { o in
                    func quadrant(_ q: Int) -> vImage_Buffer {
                        // Rows are stored bottom-up, so the atlas's bottom quadrants come first in memory.
                        let row = (1 - q / 2) * h, column = (q % 2) * w
                        return vImage_Buffer(data: UnsafeMutableRawPointer(mutating: a.baseAddress! + row * atlas.width + column),
                                             height: vImagePixelCount(h), width: vImagePixelCount(w), rowBytes: atlas.width)
                    }
                    var (r, g, b, al) = (quadrant(0), quadrant(1), quadrant(2), quadrant(3))
                    var dest = vImage_Buffer(data: o.baseAddress, height: vImagePixelCount(h), width: vImagePixelCount(w), rowBytes: w * 4)
                    // "ARGB" names the byte order only: the first plane lands in byte 0 (R here).
                    _ = vImageConvert_Planar8toARGB8888(&r, &g, &b, &al, &dest, vImage_Flags(kvImageNoFlags))
                }
            }
            guard let data = makeTexture(device, &dataPx, srgb: false, compressed: compressed) else { return nil }
            return SatelliteTextures(day: day, clouds: clouds, data: data)
        }
    }

    /// Uploads every mip level (each a 2×2 reduction of the one above), ASTC-encoded when `compressed`.
    private static func makeTexture(_ device: MTLDevice, _ px: inout Pixels, srgb: Bool, compressed: Bool) -> MTLTexture? {
        let format: MTLPixelFormat = compressed ? (srgb ? .astc_4x4_srgb : .astc_4x4_ldr) : (srgb ? .rgba8Unorm_srgb : .rgba8Unorm)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: px.width, height: px.height, mipmapped: true)
        desc.usage = .shaderRead
        desc.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: desc) else { return nil }
        for level in 0..<texture.mipmapLevelCount {
            if level > 0 { px = px.halved() }
            let region = MTLRegionMake2D(0, 0, px.width, px.height)
            if compressed {
                let ok = px.withASTC { texture.replace(region: region, mipmapLevel: level, withBytes: $0, bytesPerRow: (px.width + 3) / 4 * 16) }
                guard ok else { return nil }
            } else {
                // Rare fallback (no ASTC): upload the rows top-down one at a time.
                px.bytes.withUnsafeBytes { b in
                    for y in 0..<px.height {
                        texture.replace(region: MTLRegionMake2D(0, px.height - 1 - y, px.width, 1), mipmapLevel: level,
                                        withBytes: b.baseAddress! + y * px.width * 4, bytesPerRow: px.width * 4)
                    }
                }
            }
        }
        return texture
    }
}

/// 8-bit pixels with rows stored bottom-up (the order ImageIO's ASTC writer expects): RGBA, or one channel when `gray`.
private struct Pixels {
    var width: Int
    var height: Int
    var bytes: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
    }

    init(_ image: CGImage, gray: Bool) {
        width = image.width
        height = image.height
        let channels = gray ? 1 : 4
        bytes = [UInt8](repeating: 0, count: width * height * channels)
        let space = gray ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!
        let info = gray ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue // opaque, so alpha is 255
        let (w, h) = (width, height)
        bytes.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * channels, space: space, bitmapInfo: info) else { return }
            // A bitmap context's first row in memory is the image's top; flip so it is the bottom.
            ctx.translateBy(x: 0, y: CGFloat(h))
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    /// Half size in each direction (at least 1), filtered by vImage.
    func halved() -> Pixels {
        var out = Pixels(width: max(1, width / 2), height: max(1, height / 2))
        bytes.withUnsafeBytes { s in
            out.bytes.withUnsafeMutableBytes { d in
                var sb = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: s.baseAddress), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                var db = vImage_Buffer(data: d.baseAddress, height: vImagePixelCount(out.height), width: vImagePixelCount(out.width), rowBytes: out.width * 4)
                _ = vImageScale_ARGB8888(&sb, &db, nil, vImage_Flags(kvImageNoFlags))
            }
        }
        return out
    }

    /// Encodes this level as ASTC 4×4 and hands the raw blocks to `body`. ImageIO's .astc writer stores rows bottom-up
    /// (GL style) and these rows already are, so block row 0 comes out as the image's top, as Metal expects.
    func withASTC(_ body: (UnsafeRawPointer) -> Void) -> Bool {
        let rowBytes = width * 4
        return bytes.withUnsafeBytes { b -> Bool in
            // The provider borrows the pixels; the encode finishes before this closure returns.
            guard let provider = CGDataProvider(dataInfo: nil, data: b.baseAddress!, size: b.count, releaseData: { _, _, _ in }),
                  let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return false }
            let out = NSMutableData()
            guard let dst = CGImageDestinationCreateWithData(out, "org.khronos.astc" as CFString, 1, nil) else { return false }
            CGImageDestinationAddImage(dst, image, nil) // 4×4 blocks by default
            guard CGImageDestinationFinalize(dst) else { return false }
            let blocks = ((width + 3) / 4) * ((height + 3) / 4) * 16
            guard out.length == 16 + blocks else { return false }
            let header = out.bytes.assumingMemoryBound(to: UInt8.self)
            guard header[4] == 4, header[5] == 4 else { return false }
            body(out.bytes + 16)
            return true
        }
    }
}
