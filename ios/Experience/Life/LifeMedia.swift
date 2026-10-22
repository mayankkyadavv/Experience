import AVFoundation
import ExperienceCore
import ImageIO
import Supabase
import UIKit
import UniformTypeIdentifiers

/// Where a life's files live on the phone.
/// - Originals: exactly what was picked or shot, kept until (and after) upload. Backed up with the phone.
/// - Outbox: one JSON file per save still waiting to reach the server.
/// - Thumbs: replaceable derivatives (no metadata), safe to purge.
enum LifeFiles {
    static let root = URL.applicationSupportDirectory.appending(path: "Life", directoryHint: .isDirectory)
    static let originals = root.appending(path: "Originals", directoryHint: .isDirectory)
    static let outbox = root.appending(path: "Outbox", directoryHint: .isDirectory)
    static let thumbs = URL.cachesDirectory.appending(path: "Thumbs", directoryHint: .isDirectory)

    static func prepare() {
        for dir in [originals, outbox, thumbs] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                     attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        }
    }

    static func original(_ name: String) -> URL { originals.appending(path: name) }

    /// Where a device file actually is: the originals, or the folder the first in-app camera wrote to (ADR-012).
    static func locate(_ name: String) -> URL? {
        let candidates = [original(name), URL.documentsDirectory.appending(path: "Captures").appending(path: name)]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path()) }
    }
    static func thumb(_ clientId: UUID) -> URL { thumbs.appending(path: "\(clientId.uuidString.lowercased()).jpg") }
}

/// Facts read from a picked file, used to propose (never assert) when it happened.
struct MediaFacts {
    var kind: MediaAsset.Kind
    var takenAt: Date?
    var duration: Double?
    var width: Int?
    var height: Int?
    var contentType: String
}

enum LifeMedia {
    /// Reads capture time and size. For photos, EXIF DateTimeOriginal (with its offset when present);
    /// for videos, the creation date and duration.
    static func facts(of url: URL, kind: MediaAsset.Kind) async -> MediaFacts {
        let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? (kind == .photo ? "image/jpeg" : "video/quicktime")
        if kind == .video {
            let asset = AVURLAsset(url: url)
            let duration = try? await asset.load(.duration).seconds
            let created = try? await asset.load(.creationDate)?.load(.dateValue)
            var size: CGSize?
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let natural = try? await track.load(.naturalSize), let t = try? await track.load(.preferredTransform) {
                let r = CGRect(origin: .zero, size: natural).applying(t)
                size = CGSize(width: abs(r.width), height: abs(r.height))
            }
            return MediaFacts(kind: .video, takenAt: created, duration: duration, width: size.map { Int($0.width) },
                              height: size.map { Int($0.height) }, contentType: type)
        }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return MediaFacts(kind: .photo, contentType: type)
        }
        var w = props[kCGImagePropertyPixelWidth] as? Int, h = props[kCGImagePropertyPixelHeight] as? Int
        if let o = props[kCGImagePropertyOrientation] as? Int, (5...8).contains(o) { swap(&w, &h) }
        var taken: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any], let s = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            if let offset = exif["OffsetTimeOriginal" as CFString] as? String {
                f.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
                taken = f.date(from: s + offset)
            }
            if taken == nil {
                f.dateFormat = "yyyy:MM:dd HH:mm:ss"
                taken = f.date(from: s)
            }
        }
        return MediaFacts(kind: .photo, takenAt: taken, width: w, height: h, contentType: type)
    }

    /// A 900 px JPEG made from pixels only: no EXIF, no location. Videos use a frame a moment in.
    static func makeThumbnail(of url: URL, kind: MediaAsset.Kind) async -> Data? {
        var image: CGImage?
        if kind == .video {
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 900, height: 900)
            image = try? await gen.image(at: CMTime(seconds: 0.4, preferredTimescale: 600)).image
        } else if let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
            image = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 900,
            ] as CFDictionary)
        }
        guard let image else { return nil }
        let data = NSMutableData()
        guard let dst = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dst, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(dst) else { return nil }
        return data as Data
    }
}

/// Thumbnails for cards: memory, then the on-disk cache, then made from the local original,
/// then fetched through a short-lived signed URL (checked by the access policy on the server).
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let memory = NSCache<NSUUID, UIImage>()
    private var inFlight: [UUID: Task<UIImage?, Never>] = [:]

    func image(for asset: MediaAsset, storage: SupabaseStorageClient?) async -> UIImage? {
        if let hit = memory.object(forKey: asset.clientId as NSUUID) { return hit }
        if let task = inFlight[asset.clientId] { return await task.value }
        let task = Task<UIImage?, Never> {
            let file = LifeFiles.thumb(asset.clientId)
            if let data = try? Data(contentsOf: file), let img = UIImage(data: data) { return img }
            if let name = asset.deviceFile, let local = LifeFiles.locate(name),
               let data = await LifeMedia.makeThumbnail(of: local, kind: asset.kind) {
                try? data.write(to: file)
                return UIImage(data: data)
            }
            if let path = asset.thumbPath, let storage,
               let signed = try? await storage.from("media").createSignedURL(path: path, expiresIn: 300),
               let (data, response) = try? await URLSession.shared.data(from: signed),
               (response as? HTTPURLResponse)?.statusCode == 200, let img = UIImage(data: data) {
                try? data.write(to: file)
                return img
            }
            return nil
        }
        inFlight[asset.clientId] = task
        let image = await task.value
        inFlight[asset.clientId] = nil
        if let image { memory.setObject(image, forKey: asset.clientId as NSUUID) }
        return image
    }
}
