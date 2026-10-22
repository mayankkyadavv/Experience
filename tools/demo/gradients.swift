// Renders the sample profile's placeholder "photos": soft gradients with a glow, by theme, in the style of the
// design mockups (DESIGN.md). Abstract on purpose: nobody should mistake them for real photos.
// Writes tools/demo/.images/<theme>-<n>.jpg (1200 px long side) and <theme>-<n>.thumb.jpg (600 px).
// Usage (on the Mac): swift tools/demo/gradients.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: "tools/demo/.images", isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

typealias RGB = (Double, Double, Double)
func hex(_ v: UInt32) -> RGB { (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255) }

/// Each theme: background stops (top → bottom) and glow colors.
let themes: [String: (stops: [[UInt32]], glows: [UInt32])] = [
    "food": ([[0xF39A5A, 0xD2564C, 0x4A2B5C], [0xFFCF5C, 0xE0683A, 0x5A1E1E], [0xE2B48F, 0xA46A4A, 0x3D2318], [0xF6C177, 0xC2553D, 0x2B1420]],
             [0xFFD29A, 0xFFE3B8, 0xFFB46B]),
    "night": ([[0x1B0B3C, 0x2A0F4F, 0x05030F], [0x2A0707, 0x3B0A2A, 0x070102], [0x0B1E3D, 0x341A5E, 0x05040C], [0x14062B, 0x5B0E4E, 0x090313]],
              [0xFF5FD2, 0x55D6FF, 0xFF3B6B, 0xB46BFF]),
    "sights": ([[0x9CC6E8, 0x5B86B5, 0x2B3F63], [0xE8D9C2, 0xB49A7A, 0x5C4A3A], [0xBFD8EA, 0x7FA6C9, 0x3A4E6E], [0xF2E2CC, 0xC9A27E, 0x6E4E3A]],
               [0xFFF3D6, 0xFFFFFF, 0xFFE2B0]),
    "festival": ([[0x1B0B3C, 0x05030F, 0x120626], [0x0B0630, 0x2B0B4F, 0x02010A], [0x1A0533, 0x003B5C, 0x02010A]],
                 [0xFF5FD2, 0x55D6FF, 0xFFE15A, 0x8BFF7A]),
    "sea": ([[0xA7E0E8, 0x3FA7C4, 0x0D4C6B], [0xF6E3C0, 0x8FD3D9, 0x1C6E8C], [0xFFD3A8, 0x5BB8C8, 0x0B3D57]],
            [0xFFF6DD, 0xFFFFFF]),
    "city": ([[0x0B1E3D, 0x1E3A6E, 0x05080F], [0x2B1A3D, 0x6E3A2E, 0x0B0608], [0x10243F, 0xC26B3A, 0x1A0E0A]],
             [0xFFB46B, 0x6BC7FF, 0xFFE3B8]),
    "nature": ([[0xBFE3B0, 0x5FA36B, 0x1E4A2E], [0xD9EFC2, 0x7FB58A, 0x2A5A3E], [0x0B1A33, 0x1E6B5A, 0x041014]],
               [0xFFF6C8, 0x7DFFB0, 0xB0FFE0]),
    "home": ([[0x6B3D1E, 0x3A2214, 0x140A06], [0x8A5A3A, 0x4A2E1E, 0x1A0E08], [0x5A3A2A, 0x2E1A12, 0x0E0806]],
             [0xFFC27A, 0xFFE0B0]),
]

var rng = SystemRandomNumberGenerator()
struct Seeded: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
}

func render(width: Int, height: Int, stops: [UInt32], glows: [UInt32], seed: UInt64) -> CGImage {
    var r = Seeded(s: seed)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let colors = stops.map { let c = hex($0); return CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1) } as CFArray
    let grad = CGGradient(colorsSpace: space, colors: colors, locations: nil)!
    let angle = Double.random(in: -0.5...0.5, using: &r)
    let w = Double(width), h = Double(height)
    ctx.drawLinearGradient(grad, start: CGPoint(x: w / 2 + sin(angle) * h / 2, y: h), end: CGPoint(x: w / 2 - sin(angle) * h / 2, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // Two or three soft glows, like light in a photo: a window, a lamp, a stage.
    // Screen blending adds light the way light does, so overlapping glows stay bright instead of turning grey.
    ctx.setBlendMode(.screen)
    for _ in 0..<Int.random(in: 2...3, using: &r) {
        let g = hex(glows.randomElement(using: &r)!)
        let c = CGPoint(x: Double.random(in: 0.15...0.85, using: &r) * w, y: Double.random(in: 0.35...0.9, using: &r) * h)
        let radius = Double.random(in: 0.22...0.45, using: &r) * max(w, h)
        let glow = CGGradient(colorsSpace: space, colors: [CGColor(red: g.0, green: g.1, blue: g.2, alpha: Double.random(in: 0.45...0.8, using: &r)),
                                                          CGColor(red: g.0, green: g.1, blue: g.2, alpha: 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    }
    ctx.setBlendMode(.normal)
    // A whisper of grain so large areas don't band.
    for _ in 0..<(width * height / 90) {
        let v = Double.random(in: 0...1, using: &r)
        ctx.setFillColor(CGColor(gray: v, alpha: 0.035))
        ctx.fill(CGRect(x: Int.random(in: 0..<width, using: &r), y: Int.random(in: 0..<height, using: &r), width: 2, height: 2))
    }
    return ctx.makeImage()!
}

func writeJPEG(_ image: CGImage, to url: URL, maxSide: Int? = nil) {
    var img = image
    if let maxSide, max(image.width, image.height) > maxSide {
        let scale = Double(maxSide) / Double(max(image.width, image.height))
        let w = Int(Double(image.width) * scale), h = Int(Double(image.height) * scale)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: image.colorSpace!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        img = ctx.makeImage()!
    }
    let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dst, img, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
    CGImageDestinationFinalize(dst)
}

var count = 0
for (name, theme) in themes.sorted(by: { $0.key < $1.key }) {
    for n in 1...8 {
        let portrait = n % 3 != 0 // two portrait for each landscape, like a phone's camera roll
        let (w, h) = portrait ? (900, 1200) : (1200, 900)
        let stops = theme.stops[(n - 1) % theme.stops.count]
        let image = render(width: w, height: h, stops: stops, glows: theme.glows, seed: UInt64(n * 7919 + name.hashValue & 0xFFFF))
        writeJPEG(image, to: out.appending(path: "\(name)-\(n).jpg"))
        writeJPEG(image, to: out.appending(path: "\(name)-\(n).thumb.jpg"), maxSide: 600)
        count += 1
    }
}
print("rendered \(count) placeholder images into \(out.path)")
