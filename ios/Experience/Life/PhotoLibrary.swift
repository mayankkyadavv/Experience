import CoreLocation
import ExperienceCore
import Photos
import UIKit
import UniformTypeIdentifiers

/// Reading the Photos library to bring in past Experiences. Everything here runs on the phone: photos are grouped by
/// day and place, and an Experience links to them where they already live (nothing is copied or uploaded).
enum PhotoLibrary {
    /// Asked for only when someone chooses to bring in their past, never before.
    static func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    static var status: PHAuthorizationStatus { PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    static var canRead: Bool { status == .authorized || status == .limited }

    // MARK: Albums

    struct Album: Identifiable, Hashable {
        let id: String
        let title: String
        let count: Int
        let first: Date?
        let last: Date?
        /// How many Experiences grouping is likely to find, from time alone. Shown as an estimate.
        let estimate: Int
    }

    /// The person's own albums, biggest first, with what grouping would roughly make of each.
    static func albums() -> [Album] {
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var out: [Album] = []
        result.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: Self.byDate)
            guard assets.count > 0 else { return }
            var dates: [Date] = []
            assets.enumerateObjects { a, _, _ in if let d = a.creationDate { dates.append(d) } }
            out.append(Album(id: collection.localIdentifier, title: collection.localizedTitle ?? "Untitled album", count: assets.count,
                             first: dates.first, last: dates.last, estimate: roughGroups(dates)))
        }
        return out.sorted { $0.count > $1.count }
    }

    static func assets(inAlbum id: String) -> [PHAsset] {
        guard let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject else { return [] }
        return list(PHAsset.fetchAssets(in: collection, options: byDate))
    }

    static func assets(_ ids: [String]) -> [PHAsset] {
        list(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: byDate))
    }

    /// Photos and videos from the last few days, without screenshots.
    static func recent(days: Int) -> [PHAsset] {
        let options = byDate
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND NOT ((mediaSubtype & %d) != 0)", since as NSDate,
                                        PHAssetMediaSubtype.photoScreenshot.rawValue)
        return list(PHAsset.fetchAssets(with: options))
    }

    private static var byDate: PHFetchOptions {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        return o
    }

    private static func list(_ result: PHFetchResult<PHAsset>) -> [PHAsset] {
        var out: [PHAsset] = []
        result.enumerateObjects { a, _, _ in out.append(a) }
        return out
    }

    // MARK: Grouping

    /// A new Experience starts after this long without a photo, on a new day, or this far from the last photo.
    static let gap: TimeInterval = 3 * 3600
    static let apart: CLLocationDistance = 1500

    /// Linked shots for library assets, skipping any already in an Experience.
    static func shots(_ assets: [PHAsset], skipping linked: Set<String>) -> [TrayShot] {
        assets.compactMap { a in
            guard !linked.contains(a.localIdentifier) else { return nil }
            let video = a.mediaType == .video
            let type = PHAssetResource.assetResources(for: a).first.flatMap { UTType($0.uniformTypeIdentifier)?.preferredMIMEType }
            return TrayShot(id: UUID(), kind: video ? .video : .photo, fileName: "", takenAt: a.creationDate ?? Date(),
                            duration: video ? a.duration : nil, width: a.pixelWidth, height: a.pixelHeight,
                            contentType: type ?? (video ? "video/quicktime" : "image/heic"),
                            lat: a.location?.coordinate.latitude, lng: a.location?.coordinate.longitude,
                            fromPhotos: true, libraryRef: a.localIdentifier)
        }
    }

    /// Splits shots into drafts by time, day and place, in the order they were taken.
    static func group(_ shots: [TrayShot]) -> [TrayDraft] {
        var drafts: [TrayDraft] = []
        var lastSpot: CLLocation?
        for shot in shots.sorted(by: { $0.takenAt < $1.takenAt }) {
            let spot = shot.lat.flatMap { lat in shot.lng.map { CLLocation(latitude: lat, longitude: $0) } }
            if let current = drafts.last, let last = current.shots.last,
               shot.takenAt.timeIntervalSince(last.takenAt) < gap,
               Calendar.current.isDate(shot.takenAt, inSameDayAs: last.takenAt),
               spot == nil || lastSpot == nil || spot!.distance(from: lastSpot!) < apart {
                drafts[drafts.count - 1].shots.append(shot)
            } else {
                drafts.append(TrayDraft(shots: [shot]))
            }
            if let spot { lastSpot = spot }
        }
        return drafts
    }

    /// Time-only grouping over dates, for the album list's estimate.
    private static func roughGroups(_ dates: [Date]) -> Int {
        var count = 0
        var last: Date?
        for d in dates {
            if let l = last, d.timeIntervalSince(l) < gap, Calendar.current.isDate(d, inSameDayAs: l) {} else { count += 1 }
            last = d
        }
        return count
    }

    // MARK: Pictures

    /// A picture of a linked photo or video, from the library (iCloud included). Nil if it's gone from the library.
    static func image(_ ref: String, size: CGFloat) async -> UIImage? {
        guard canRead, let asset = PHAsset.fetchAssets(withLocalIdentifiers: [ref], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { c in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: size, height: size), contentMode: .aspectFill,
                                                  options: options) { image, _ in c.resume(returning: image) }
        }
    }

    #if LOCAL_BACKEND && targetEnvironment(simulator)
    /// UI tests only (`-seedPhotosAlbum`): files the April 2024 test photos, added with `simctl addmedia`, into an
    /// album called "Philly weekend", so the album import can be walked on a simulator.
    static func seedTestAlbum() async {
        guard ProcessInfo.processInfo.arguments.contains("-seedPhotosAlbum"), canRead else { return }
        let title = "Philly weekend"
        var exists = false
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).enumerateObjects { c, _, stop in
            if c.localizedTitle == title { exists = true; stop.pointee = true }
        }
        guard !exists else { return }
        let o = PHFetchOptions()
        let cal = Calendar.current
        o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                  cal.date(from: DateComponents(year: 2024, month: 4, day: 1))! as NSDate,
                                  cal.date(from: DateComponents(year: 2024, month: 5, day: 1))! as NSDate)
        let assets = PHAsset.fetchAssets(with: o)
        try? await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title).addAssets(assets)
        }
    }
    #endif
}
