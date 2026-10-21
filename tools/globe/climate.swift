// Builds the Dots earth's land colors: each place takes the color of its climate (Köppen-Geiger, 1991-2020),
// 1024x512 equirectangular sRGB. Warm sands and ochres for deserts and steppe, jade for rainforest, fresh greens
// for temperate land, teal into boreal blue for the cold continents, lavender tundra and white ice.
// Neighboring climates blend softly (in OKLab) so borders read as weather, not as a political map.
//
// Source: Beck et al. (2023), High-resolution (1 km) Köppen-Geiger maps for 1901-2099, Scientific Data 10, 724.
// CC BY 4.0, https://doi.org/10.6084/m9.figshare.21789074 (koppen_geiger_tif.zip → 1991_2020/koppen_geiger_0p1.tif).
// Usage: swift tools/globe/climate.swift <koppen_geiger_0p1.tif> ios/Experience/Resources/Globe
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let inPath = args[1], outDir = args[2]
let w = 1024, h = 512

// Class colors in the source file (Beck et al. legend), in class order 1...30.
let legend: [(Int, Int, Int)] = [
    (0, 0, 255), (0, 120, 255), (70, 170, 250), (255, 0, 0), (255, 150, 150), (245, 165, 0), (255, 220, 100),
    (255, 255, 0), (200, 200, 0), (150, 150, 0), (150, 255, 150), (100, 200, 100), (50, 150, 50),
    (200, 255, 80), (100, 255, 80), (50, 200, 0), (255, 0, 255), (200, 0, 200), (150, 50, 150), (150, 100, 150),
    (170, 175, 255), (90, 120, 220), (75, 80, 180), (50, 0, 135), (0, 255, 255), (55, 200, 255), (0, 125, 125),
    (0, 70, 95), (178, 178, 178), (102, 102, 102),
]

// Our palette, same order. Hot and dry is warm, wet is green, cold is blue, polar is pale.
let palette: [UInt32] = [
    0x12B886, 0x2BC49A, 0xB8C24E,                     // Af rainforest, Am monsoon, Aw savanna
    0xF59E5B, 0xE8907E, 0xEDB654, 0xD9BE85,           // BWh hot desert, BWk cold desert, BSh hot steppe, BSk cold steppe
    0xC2BD5A, 0xA6BE72, 0x8FB08A,                     // Csa/Csb/Csc Mediterranean
    0x74C46E, 0x84BE88, 0x78AE92,                     // Cwa/Cwb/Cwc dry-winter temperate, highlands
    0x5CC77E, 0x4FBFA0, 0x4AA9AE,                     // Cfa humid subtropical, Cfb oceanic, Cfc subpolar oceanic
    0x9DB3A2, 0x8AAAB0, 0x7898B8, 0x7A86C0,           // Dsa-Dsd dry-summer continental
    0x56B9A8, 0x47A6B4, 0x4A8CC4, 0x6A78CC,           // Dwa-Dwd dry-winter continental
    0x4CB7AA, 0x3AA3BB, 0x3F86C6, 0x6474CF,           // Dfa-Dfd humid continental into taiga
    0xA4A6E0, 0xE8EEFF,                               // ET tundra, EF ice
]

// 1. Read the map and classify every pixel (0 = sea / no data, drawn white in the source).
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let sw = img.width, sh = img.height
var px = [UInt8](repeating: 0, count: sw * sh * 4)
let ctx = CGContext(data: &px, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: sw * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: sw, height: sh))
var cls = [UInt8](repeating: 0, count: sw * sh)
for i in 0..<(sw * sh) {
    let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2])
    if r > 250 && g > 250 && b > 250 { continue }
    var best = Int.max, bi = 0
    for (k, c) in legend.enumerated() {
        let d = (r - c.0) * (r - c.0) + (g - c.1) * (g - c.1) + (b - c.2) * (b - c.2)
        if d < best { best = d; bi = k + 1 }
    }
    cls[i] = UInt8(bi)
}

// 2. Down to the output grid: the most common climate under each output pixel.
var grid = [UInt8](repeating: 0, count: w * h)
for y in 0..<h {
    let y0 = y * sh / h, y1 = max(y0 + 1, (y + 1) * sh / h)
    for x in 0..<w {
        let x0 = x * sw / w, x1 = max(x0 + 1, (x + 1) * sw / w)
        var count = [Int](repeating: 0, count: 31)
        for yy in y0..<y1 { for xx in x0..<x1 { count[Int(cls[yy * sw + xx])] += 1 } }
        count[0] = 0
        if let m = count.indices.max(by: { count[$0] < count[$1] }), count[m] > 0 { grid[y * w + x] = UInt8(m) }
    }
}

// 3. Spread climates into the sea (nearest first, wrapping in longitude), so coastal dots and small islands
//    the land mask keeps always find a color.
var queue: [Int] = (0..<(w * h)).filter { grid[$0] != 0 }
var head = 0
while head < queue.count {
    let i = queue[head]; head += 1
    let x = i % w, y = i / w
    for (nx, ny) in [((x + 1) % w, y), ((x + w - 1) % w, y), (x, y + 1), (x, y - 1)] where ny >= 0 && ny < h {
        let j = ny * w + nx
        if grid[j] == 0 { grid[j] = grid[i]; queue.append(j) }
    }
}

// 4. Colors in OKLab, blurred a little (σ ≈ 0.4°), then back to sRGB.
func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
func gam(_ c: Double) -> Double { c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055 }
func toLab(_ hex: UInt32) -> (Double, Double, Double) {
    let r = lin(Double((hex >> 16) & 255) / 255), g = lin(Double((hex >> 8) & 255) / 255), b = lin(Double(hex & 255) / 255)
    let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
}
func toRGB(_ L: Double, _ A: Double, _ B: Double) -> (UInt8, UInt8, UInt8) {
    let l = pow(L + 0.3963377774 * A + 0.2158037573 * B, 3)
    let m = pow(L - 0.1055613458 * A - 0.0638541728 * B, 3)
    let s = pow(L - 0.0894841775 * A - 1.2914855480 * B, 3)
    let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    func q(_ v: Double) -> UInt8 { UInt8(max(0, min(255, (gam(max(0, min(1, v))) * 255).rounded()))) }
    return (q(r), q(g), q(b))
}
let labs = palette.map(toLab)
var lab = [[Double]](repeating: [Double](repeating: 0, count: w * h), count: 3)
for i in 0..<(w * h) { let c = labs[Int(grid[i]) - 1]; lab[0][i] = c.0; lab[1][i] = c.1; lab[2][i] = c.2 }
let sigma = 1.2, radius = 3
let kernel = (-radius...radius).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
let ksum = kernel.reduce(0, +)
for ch in 0..<3 {
    var tmp = [Double](repeating: 0, count: w * h)
    for y in 0..<h { for x in 0..<w {
        var s = 0.0
        for (k, wt) in kernel.enumerated() { s += lab[ch][y * w + (x + k - radius + w) % w] * wt }
        tmp[y * w + x] = s / ksum
    } }
    for y in 0..<h { for x in 0..<w {
        var s = 0.0
        for (k, wt) in kernel.enumerated() { s += tmp[min(h - 1, max(0, y + k - radius)) * w + x] * wt }
        lab[ch][y * w + x] = s / ksum
    } }
}

var out = [UInt8](repeating: 255, count: w * h * 4)
for i in 0..<(w * h) {
    let (r, g, b) = toRGB(lab[0][i], lab[1][i], lab[2][i])
    out[i * 4] = r; out[i * 4 + 1] = g; out[i * 4 + 2] = b
}
let octx = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/dots_climate.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, octx.makeImage()!, nil)
CGImageDestinationFinalize(dst)
print("dots_climate.png \(w)x\(h)")
