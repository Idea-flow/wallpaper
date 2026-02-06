import AppKit
import UniformTypeIdentifiers

struct WallpaperService {
    enum WallpaperError: Error {
        case invalidImage(String)
        case notSupported
        case setFailed(String)
    }

    static func applyImage(url: URL, to screen: NSScreen?, fitMode: FitMode) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WallpaperError.invalidImage("文件不存在或不可访问。")
        }

        let type = UTType(filenameExtension: url.pathExtension)
        guard type?.conforms(to: .image) == true else {
            throw WallpaperError.invalidImage("当前文件不是有效的图片格式。")
        }

        let options = desktopOptions(for: fitMode)
        let targetScreens = screen.map { [$0] } ?? NSScreen.screens
        for target in targetScreens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: target, options: options)
            } catch {
                throw WallpaperError.setFailed(error.localizedDescription)
            }
        }
    }

    static func applyVideoPlaceholder() throws {
        throw WallpaperError.notSupported
    }

    private static func desktopOptions(for fitMode: FitMode) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        let scaling: NSImageScaling
        let allowClipping: Bool

        switch fitMode {
        case .fill:
            scaling = .scaleProportionallyUpOrDown
            allowClipping = true
        case .fit:
            scaling = .scaleProportionallyUpOrDown
            allowClipping = false
        case .stretch:
            scaling = .scaleAxesIndependently
            allowClipping = true
        case .center:
            scaling = .scaleNone
            allowClipping = false
        case .tile:
            scaling = .scaleNone
            allowClipping = true
        }

        return [
            .imageScaling: NSNumber(value: scaling.rawValue),
            .allowClipping: NSNumber(value: allowClipping),
        ]
    }
}

extension WallpaperService.WallpaperError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidImage(let message):
            return message
        case .notSupported:
            return "当前功能暂不支持。"
        case .setFailed(let message):
            return "系统设置壁纸失败：\(message)"
        }
    }
}
