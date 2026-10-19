// On-screen text for video frames using Apple's Vision framework (on-device, free).
// Usage: ocr <image> [<image> ...]  →  JSON array on stdout.
// Compiled on demand by video.ts into build/ocr.

import Foundation
import ImageIO
import Vision

struct Line: Codable {
    let text: String
    let confidence: Float
}

struct FileResult: Codable {
    let file: String
    let lines: [Line]
}

var results: [FileResult] = []

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        results.append(FileResult(file: path, lines: []))
        continue
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.automaticallyDetectsLanguage = true

    try? VNImageRequestHandler(cgImage: image).perform([request])

    let lines = (request.results ?? []).compactMap { observation -> Line? in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        return Line(text: candidate.string, confidence: candidate.confidence)
    }
    results.append(FileResult(file: path, lines: lines))
}

FileHandle.standardOutput.write(try JSONEncoder().encode(results))
