import Foundation

struct MediaAccessService {
    static func withResolvedURL<T>(for item: MediaItem, _ action: (URL) throws -> T) throws -> T {
        guard let bookmarkData = item.bookmarkData else {
            return try action(item.fileURL)
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            return try action(url)
        } catch {
            return try action(item.fileURL)
        }
    }
}
