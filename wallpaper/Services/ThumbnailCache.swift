import AppKit // 使用 NSImage
import Foundation // 基础类型

// ThumbnailCache：缩略图缓存
final class ThumbnailCache {
    static let shared = ThumbnailCache() // 单例
    private let cache = NSCache<NSString, NSImage>() // 内存缓存
    private var totalBytes: Int = 0 // 估算缓存占用

    private init() { // 私有初始化
        cache.countLimit = 300 // 最大缓存数量
    }

    func image(forKey key: String) -> NSImage? { // 获取缓存
        cache.object(forKey: key as NSString) // 返回缓存
    }

    func setImage(_ image: NSImage, forKey key: String) { // 设置缓存
        cache.setObject(image, forKey: key as NSString) // 写入缓存
        totalBytes += estimateBytes(for: image) // 估算大小累加
    }

    func clear() { // 清空缓存
        cache.removeAllObjects() // 清空
        totalBytes = 0 // 重置大小
    }

    func estimatedSizeBytes() -> Int { // 获取估算大小
        totalBytes // 返回估算
    }

    private func estimateBytes(for image: NSImage) -> Int { // 估算大小
        let size = image.size // 图片尺寸
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0 // 缩放
        let width = Int(size.width * scale) // 宽
        let height = Int(size.height * scale) // 高
        return max(width * height * 4, 1) // 估算 RGBA
    }
}
