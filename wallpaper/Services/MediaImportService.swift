import AppKit
import AVFoundation
import UniformTypeIdentifiers

struct MediaImportService {
    struct ImportResult {
        let item: MediaItem
    }

    static func importMedia(from url: URL) throws -> ImportResult {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let type = detectType(for: url)
        let bookmarkData = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        let sizeBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }

        switch type {
        case .image:
            let image = NSImage(contentsOf: url)
            // map on the optional image, not on CGFloat
            let width = image.map { Double($0.size.width) }
            let height = image.map { Double($0.size.height) }
            let item = MediaItem(
                type: .image,
                fileURL: url,
                bookmarkData: bookmarkData,
                width: width,
                height: height,
                sizeBytes: sizeBytes
            )
            return ImportResult(item: item)
        case .video:
            let asset = AVAsset(url: url)
            let duration = asset.duration.seconds
            let track = asset.tracks(withMediaType: .video).first
            let frameRate = track?.nominalFrameRate
            let size = track?.naturalSize
            // map on the optional CGSize
            let item = MediaItem(
                type: .video,
                fileURL: url,
                bookmarkData: bookmarkData,
                width: size.map { Double($0.width) },
                height: size.map { Double($0.height) },
                duration: duration.isFinite ? duration : nil,
                frameRate: frameRate.map { Double($0) },
                sizeBytes: sizeBytes
            )
            return ImportResult(item: item)
        }
    }

    static func detectType(for url: URL) -> MediaType {
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .movie) == true {
            return .video
        }
        return .image
    }
}
