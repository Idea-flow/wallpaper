import AppKit // 使用 NSWorkspace 设置壁纸
import UniformTypeIdentifiers // 判断文件类型

// WallpaperService：设置系统图片壁纸
struct WallpaperService {
    // WallpaperError：壁纸相关错误
    enum WallpaperError: Error {
        case invalidImage(String) // 图片无效
        case notSupported // 功能不支持
        case setFailed(String) // 设置失败
    }

    // applyImage：设置图片壁纸
    static func applyImage(url: URL, to screen: NSScreen?, fitMode: FitMode) throws {
        LogCenter.log("[壁纸] 准备设置图片壁纸：\(url.lastPathComponent)") // 关键步骤日志

        guard FileManager.default.fileExists(atPath: url.path) else { // 判断文件是否存在
            throw WallpaperError.invalidImage("文件不存在或不可访问。") // 抛出错误
        }

        let type = UTType(filenameExtension: url.pathExtension) // 获取文件类型
        guard type?.conforms(to: .image) == true else { // 判断是否为图片
            throw WallpaperError.invalidImage("当前文件不是有效的图片格式。") // 抛出错误
        }

        let targetScreens = screen.map { [$0] } ?? NSScreen.screens // 选择目标屏幕
        for target in targetScreens { // 遍历所有屏幕
            do {
                let options = desktopOptions(for: fitMode) // 生成适配选项
                try NSWorkspace.shared.setDesktopImageURL(url, for: target, options: options) // 设置壁纸
            } catch {
                throw WallpaperError.setFailed(error.localizedDescription) // 抛出系统错误
            }
        }

        LogCenter.log("[壁纸] 图片壁纸设置完成") // 关键步骤日志
    }

    // applyVideoPlaceholder：视频壁纸占位
    static func applyVideoPlaceholder() throws {
        throw WallpaperError.notSupported // 暂不支持
    }

    // desktopOptions：根据适配模式生成系统选项
    private static func desktopOptions(for fitMode: FitMode) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        let scaling: NSImageScaling // 图片缩放方式
        let allowClipping: Bool // 是否裁剪

        switch fitMode { // 根据模式选择
        case .fill:
            scaling = .scaleProportionallyUpOrDown // 等比缩放
            allowClipping = true // 允许裁剪
        case .fit:
            scaling = .scaleProportionallyUpOrDown // 等比缩放
            allowClipping = false // 不裁剪
        case .stretch:
            scaling = .scaleAxesIndependently // 拉伸
            allowClipping = true // 允许裁剪
        case .center:
            scaling = .scaleNone // 不缩放
            allowClipping = false // 不裁剪
        case .tile:
            scaling = .scaleNone // 不缩放
            allowClipping = true // 近似平铺
        }

        // NSWorkspace 需要 NSNumber（否则会触发 __SwiftValue integerValue 异常）
        return [
            .imageScaling: NSNumber(value: scaling.rawValue),
            .allowClipping: NSNumber(value: allowClipping),
        ]
    }
}

// LocalizedError：提供中文错误描述
extension WallpaperService.WallpaperError: LocalizedError {
    var errorDescription: String? { // 返回错误提示
        switch self { // 按错误类型返回
        case .invalidImage(let message):
            return message // 无效图片提示
        case .notSupported:
            return "当前功能暂不支持。" // 功能不支持提示
        case .setFailed(let message):
            return "系统设置壁纸失败：\(message)" // 设置失败提示
        }
    }
}
