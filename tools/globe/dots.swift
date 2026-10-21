// Builds the Dots earth's land mask: a signed distance field to the coastline, 2048x1024 equirectangular, 8-bit gray.
// 0.5 is the coast, brighter is inland, darker is sea; 0 and 1 are ±`range` degrees of great-circle distance.
// The shader decides land per dot from this and shrinks dots near the coast.
// Usage: swift tools/globe/dots.swift <dir with shallow_2048.jpg> ios/Experience/Resources/Globe
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let inDir = args[1], outDir = args[2]
let w = 2048, h = 1024
let range = 2.0 // degrees mapped to the full 0...1 span either side of the coast

// 1. Land mask from the flat-ocean Blue Marble (ocean is blue-dominant).
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: "\(inDir)/shallow_2048.jpg") as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
var land = [Bool](repeating: false, count: w * h)
for i in 0..<(w * h) {
    let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2])
    land[i] = !(b > r + 18 && b >= g - 6)
}
// The Antarctic interior and its ice shelves read bluish in the imagery; south of 78°S is all ice.
for y in Int(Double(h) * (90 + 78) / 180)..<h { for x in 0..<w { land[y * w + x] = true } }

// Fill small lakes: at dot scale they read as holes. Water bodies under `minLake` pixels (~50,000 km² mid-latitude) become land.
let minLake = 200
var seen = [Bool](repeating: false, count: w * h)
for start in 0..<(w * h) where !land[start] && !seen[start] {
    var stack = [start], comp: [Int] = []
    seen[start] = true
    while let i = stack.popLast() {
        comp.append(i)
        let x = i % w, y = i / w
        for (nx, ny) in [((x + 1) % w, y), ((x + w - 1) % w, y), (x, y + 1), (x, y - 1)] where ny >= 0 && ny < h {
            let j = ny * w + nx
            if !land[j] && !seen[j] { seen[j] = true; stack.append(j) }
        }
    }
    if comp.count < minLake { for i in comp { land[i] = true } }
}

// 2. Distance to the nearest pixel of the other kind, measured on the sphere (x shrinks by cos(lat)), wrapping in longitude.
let degPerPx = 180.0 / Double(h)
let reachY = Int((range / degPerPx).rounded(.up)) + 1
let out = UnsafeMutablePointer<UInt8>.allocate(capacity: w * h)
DispatchQueue.concurrentPerform(iterations: h) { y in
    let lat = 90 - (Double(y) + 0.5) * degPerPx
    let c = max(cos(lat * .pi / 180), 0.02)
    let reachX = min(w / 2, Int((Double(reachY) / c).rounded(.up)))
    for x in 0..<w {
        let me = land[y * w + x]
        var best = range * range
        for dy in -reachY...reachY {
            let yy = y + dy
            guard yy >= 0, yy < h else { continue }
            let fy = Double(dy) * degPerPx
            if fy * fy >= best { continue }
            let latY = 90 - (Double(yy) + 0.5) * degPerPx
            let cy = cos(latY * .pi / 180)
            let row = yy * w
            for dx in -reachX...reachX {
                let xx = (x + dx + w) % w
                if land[row + xx] == me { continue }
                let fx = Double(dx) * degPerPx * (c + cy) * 0.5
                let d = fx * fx + fy * fy
                if d < best { best = d }
            }
        }
        // Distance to the boundary sits halfway between the two pixel centers.
        let d = max(0, sqrt(best) - degPerPx * 0.5)
        let s = (me ? d : -d) / range * 0.5 + 0.5
        let v = UInt8(max(0, min(255, (s * 255).rounded())))
        out[y * w + x] = v
    }
}

let gray = CGContext(data: out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/dots_land.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, gray.makeImage()!, nil)
CGImageDestinationFinalize(dst)
print("dots_land.png \(w)x\(h)")
