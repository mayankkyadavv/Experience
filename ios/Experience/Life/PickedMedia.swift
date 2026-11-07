import CoreTransferable
import ExperienceCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension CollectionChoice {
    init(collectionId: UUID) { self.init(collectionId: collectionId, newTitle: nil, newKind: nil) }
}

extension LifeMedia {
    /// Copies each picked file into the app's originals, untouched, and reads when it was taken.
    static func importPicked(_ items: [PhotosPickerItem]) async -> (media: [PendingMedia], failed: Int) {
        var media: [PendingMedia] = []
        var failed = 0
        for item in items {
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let clientId = UUID()
            do {
                let url: URL
                if isVideo {
                    guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { failed += 1; continue }
                    url = movie.url
                } else {
                    guard let data = try await item.loadTransferable(type: Data.self) else { failed += 1; continue }
                    let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                    url = LifeFiles.original("\(clientId.uuidString.lowercased()).\(ext)")
                    try data.write(to: url, options: .atomic)
                }
                let facts = await facts(of: url, kind: isVideo ? .video : .photo)
                media.append(PendingMedia(clientId: clientId, kind: facts.kind, fileName: url.lastPathComponent, takenAt: facts.takenAt,
                                          duration: facts.duration, width: facts.width, height: facts.height, contentType: facts.contentType,
                                          lat: facts.lat, lng: facts.lng))
            } catch {
                failed += 1
            }
        }
        return (media, failed)
    }
}

/// A picked video, copied into the app's originals as soon as the picker hands it over.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = LifeFiles.original("\(UUID().uuidString.lowercased()).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}
