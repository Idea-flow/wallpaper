import AppKit

struct WallpaperService {
    enum WallpaperError: Error {
        case invalidImage
        case notSupported
        case setFailed
    }

    static func applyImage(url: URL, to screen: NSScreen?) throws {
        guard NSImage(contentsOf: url) != nil else {
            throw WallpaperError.invalidImage
        }
        let targetScreens = screen.map { [$0] } ?? NSScreen.screens
        for target in targetScreens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: target, options: [:])
            } catch {
                throw WallpaperError.setFailed
            }
        }
    }

    static func applyVideoPlaceholder() throws {
        throw WallpaperError.notSupported
    }
}
