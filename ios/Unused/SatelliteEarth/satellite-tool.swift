// Builds the Satellite earth textures from public-domain NASA imagery.
//
//   swift tools/globe/satellite.swift <sources dir> <out dir>
//
// <sources dir> holds (NASA Visible Earth / Earth Observatory, public domain):
//   bmng/topo_bathy_21600.jpg       Blue Marble Next Generation, July 2004, topography + bathymetry (record 73751)
//   clouds/clouds_8192.tif          Blue Marble cloud composite (record 57747)
//   night/blackmarble_2016_3km.jpg  Black Marble 2016, Earth at Night (record 144898)
//   elev/elev_21600.png             GEBCO/SRTM land elevation (record 73934)
//   bath/bath_21600.png             GEBCO bathymetry, land is white (record 73963)
//
// Writes small HEIC files for the bundle; the app turns them into ASTC 4×4 GPU textures with mipmaps at load
// (SatelliteTextures.swift), which keeps the bundle small and the GPU copy compact and sharp:
//   satellite_day.heic     8192×4096 color
//   satellite_clouds.heic  4096×2048 gray cloud brightness
//   satellite_data.heic    8192×4096 gray atlas of four 4096×2048 quadrants:
//                          top left water mask · top right night lights · bottom left slope east · bottom right slope north
import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
let src = args[1], out = args[2]
let rgbSpace = CGColorSpace(name: CGColorSpace.sRGB)!

/// Decodes and downsamples a (possibly huge) image to `w` pixels wide.
func load(_ path: String, width w: Int) -> CGImage {
    let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: "\(src)/\(path)") as CFURL, nil)!
    let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                 kCGImageSourceThumbnailMaxPixelSize: w,
                                 kCGImageSourceShouldCacheImmediately: true]
    return CGImageSourceCreateThumbnailAtIndex(s, 0, opts as CFDictionary)!
}

/// RGBA8 pixels at exactly w×h.
func pixels(_ img: CGImage, _ w: Int, _ h: Int) -> [UInt8] {
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: rgbSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return px
}

func writeHEIC(_ img: CGImage, _ name: String, quality: Double) {
    let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/\(name)") as CFURL, "public.heic" as CFString, 1, nil)!
    CGImageDestinationAddImage(dst, img, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    precondition(CGImageDestinationFinalize(dst))
    let size = (try? FileManager.default.attributesOfItem(atPath: "\(out)/\(name)")[.size] as? Int) ?? 0
    print(name, img.width, img.height, "bytes:", size)
}

/// A gray image stored as RGB (ImageIO's HEIC writer takes no gray input; equal channels cost almost nothing in chroma).
func gray(_ px: [UInt8], _ w: Int, _ h: Int) -> CGImage {
    var rgb = [UInt8](repeating: 255, count: w * h * 4)
    for i in 0..<(w * h) { rgb[i * 4] = px[i]; rgb[i * 4 + 1] = px[i]; rgb[i * 4 + 2] = px[i] }
    return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: rgbSpace,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: CGDataProvider(data: Data(rgb) as CFData)!,
                   decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

// 1. Day color: Blue Marble NG, 21600 → 8192.
writeHEIC(load("bmng/topo_bathy_21600.jpg", width: 8192), "satellite_day.heic", quality: 0.86)

// 2. Clouds: brightness (the shader shapes it into coverage).
do {
    let w = 4096, h = 2048
    let px = pixels(load("clouds/clouds_8192.tif", width: w), w, h)
    writeHEIC(gray((0..<(w * h)).map { px[$0 * 4] }, w, h), "satellite_clouds.heic", quality: 0.9)
}

// 3. Surface data at 4096: water mask, night lights, terrain slopes, as quadrants of one gray atlas.
do {
    let w = 4096, h = 2048
    let bath = pixels(load("bath/bath_21600.png", width: w), w, h)
    let day = pixels(load("bmng/topo_bathy_21600.jpg", width: w), w, h)
    let night = pixels(load("night/blackmarble_2016_3km.jpg", width: w), w, h)
    let elev = pixels(load("elev/elev_21600.png", width: w), w, h)
    var atlas = [UInt8](repeating: 0, count: w * h * 4)
    func put(_ q: Int, _ x: Int, _ y: Int, _ v: Double) {
        atlas[(y + (q / 2) * h) * w * 2 + x + (q % 2) * w] = UInt8(min(255, max(0, v.rounded())))
    }

    // Elevation in arbitrary units, then slopes per unit of ground distance (east shrinks with cos(lat)).
    var height = [Double](repeating: 0, count: w * h)
    for i in 0..<(w * h) { height[i] = Double(elev[i * 4]) }
    func hgt(_ x: Int, _ y: Int) -> Double { height[min(h - 1, max(0, y)) * w + (x + w) % w] }
    let gain = 0.045

    for y in 0..<h {
        // Row 0 is the top (north).
        let lat = (0.5 - (Double(y) + 0.5) / Double(h)) * .pi
        let c = max(0.12, cos(lat))
        for x in 0..<w {
            let i = (y * w + x) * 4
            // Water: GEBCO bathymetry marks land as white; inland lakes come from the Blue Marble color.
            let r = Double(day[i]), g = Double(day[i + 1]), b = Double(day[i + 2])
            let ocean = bath[i] < 250
            let lake = b > r + 22 && b > g + 4 && (r + g + b) / 3 < 110
            // Night lights: the warm city light over the bluish moonlit land.
            let nr = Double(night[i]), nb = Double(night[i + 2])
            let lights = smooth(0, 1, (nr - 0.5 * nb - 14) / 125)
            let sx = (hgt(x + 1, y) - hgt(x - 1, y)) / (2 * c)
            let sy = (hgt(x, y - 1) - hgt(x, y + 1)) / 2
            put(0, x, y, ocean || lake ? 255 : 0)
            put(1, x, y, lights * 255)
            put(2, x, y, 127.5 + sx * gain * 127.5)
            put(3, x, y, 127.5 + sy * gain * 127.5)
        }
    }
    writeHEIC(gray(atlas, w * 2, h * 2), "satellite_data.heic", quality: 0.92)
}
