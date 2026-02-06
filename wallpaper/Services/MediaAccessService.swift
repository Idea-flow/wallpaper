import AppKit // 使用 NSImage
import Foundation // 基础类型

// MediaAccessService：负责处理安全作用域书签访问与素材读取
struct MediaAccessService {
    // AccessToken：保存安全访问的 URL 和释放访问的方法
    struct AccessToken {
        let url: URL // 实际可访问的文件地址
        let stopAccess: () -> Void // 结束安全访问的闭包
    }

    // withResolvedURL：解析安全书签并执行访问逻辑
    static func withResolvedURL<T>(for item: MediaItem, _ action: (URL) throws -> T) throws -> T {
        // 如果没有书签，优先尝试直接对 fileURL 启动安全访问（如果可能）并执行操作
        guard let bookmarkData = item.bookmarkData else {
            // 尝试对原始路径启动安全访问（在某些情况下 fileURL 本身可能是带权限的 URL）
            let didAccess = item.fileURL.startAccessingSecurityScopedResource()
            if didAccess {
                defer { item.fileURL.stopAccessingSecurityScopedResource() }
            }
            return try action(item.fileURL)
        }

        do { // 捕获书签解析错误
            var isStale = false // 是否过期
            let url = try URL( // 解析书签为可用 URL
                resolvingBookmarkData: bookmarkData, // 书签数据
                options: [.withSecurityScope], // 使用安全作用域
                relativeTo: nil, // 不依赖相对路径
                bookmarkDataIsStale: &isStale // 返回是否过期
            )

            let didAccess = url.startAccessingSecurityScopedResource() // 开始安全访问
            defer { // 函数结束时释放访问
                if didAccess { // 确保曾成功开启
                    url.stopAccessingSecurityScopedResource() // 停止访问
                }
            }

            return try action(url) // 执行访问逻辑
        } catch {
            // 如果解析书签失败，尝试作为回退：对原始 fileURL 启动安全访问并执行操作
            // 这样能在书签损坏或不适用时，仍然尝试读取文件（在非沙盒或 fileURL 保持可访问的情况下有效）
            NSLog("[MediaAccessService] 解析书签失败，回退到原始路径访问：\(error.localizedDescription)")
            let didAccess = item.fileURL.startAccessingSecurityScopedResource()
            if didAccess {
                defer { item.fileURL.stopAccessingSecurityScopedResource() }
            }
            return try action(item.fileURL)
        }
    }

    // ImageLoadResult：图片读取结果
    struct ImageLoadResult {
        let image: NSImage? // 读取到的图片
        let reason: String? // 失败原因（可为空）
    }

    // loadImage：读取图片并返回 NSImage
    static func loadImage(for item: MediaItem) -> NSImage? {
        loadImageResult(for: item).image // 复用带原因的方法
    }

    // loadImageResult：读取图片，并返回失败原因
    static func loadImageResult(for item: MediaItem) -> ImageLoadResult {
        let fileURL = item.fileURL // 原始路径

        if !FileManager.default.fileExists(atPath: fileURL.path) { // 判断文件是否存在
            let reason = "文件不存在：\(fileURL.lastPathComponent)" // 原因
            NSLog("[MediaAccessService] \(reason)") // 日志
            return ImageLoadResult(image: nil, reason: reason) // 返回失败
        }

        if !FileManager.default.isReadableFile(atPath: fileURL.path) { // 判断是否可读
            let reason = "没有读取权限（可能是沙盒权限）：\(fileURL.lastPathComponent)" // 原因
            NSLog("[MediaAccessService] \(reason)") // 日志
            return ImageLoadResult(image: nil, reason: reason) // 返回失败
        }

        do { // 尝试安全访问路径读取
            let image = try withResolvedURL(for: item) { url in
                if let image = NSImage(contentsOf: url) { // 直接读取
                    return image // 成功
                }
                if let data = try? Data(contentsOf: url), let image = NSImage(data: data) { // 用数据读取
                    return image // 成功
                }
                throw NSError(domain: "MediaAccessService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"]) // 失败
            }
            return ImageLoadResult(image: image, reason: nil) // 返回成功
        } catch { // withResolvedURL 抛错
            let reason = "安全访问失败：\(error.localizedDescription)" // 原因
            NSLog("[MediaAccessService] \(reason)") // 日志
            return ImageLoadResult(image: nil, reason: reason) // 返回失败
        }
    }

    // beginAccess：保持安全访问，用于视频播放等长期任务
    static func beginAccess(for item: MediaItem) throws -> AccessToken {
        let fileURL = item.fileURL // 原始路径
        if !FileManager.default.fileExists(atPath: fileURL.path) { // 文件不存在
            NSLog("[MediaAccessService] beginAccess: 文件不存在：\(fileURL.path)") // 日志
        }
        if !FileManager.default.isReadableFile(atPath: fileURL.path) { // 文件不可读
            NSLog("[MediaAccessService] beginAccess: 文件不可读（可能是权限问题）：\(fileURL.path)") // 日志
        }

        guard let bookmarkData = item.bookmarkData else { // 没有书签
            let didAccess = fileURL.startAccessingSecurityScopedResource() // 尝试安全访问
            return AccessToken(url: fileURL, stopAccess: { // 返回令牌
                if didAccess { // 确保访问成功
                    fileURL.stopAccessingSecurityScopedResource() // 停止访问
                }
            })
        }

        do { // 捕获书签解析错误
            var isStale = false // 是否过期
            let url = try URL( // 解析书签
                resolvingBookmarkData: bookmarkData, // 书签数据
                options: [.withSecurityScope], // 安全作用域
                relativeTo: nil, // 不使用相对路径
                bookmarkDataIsStale: &isStale // 返回是否过期
            )
            let didAccess = url.startAccessingSecurityScopedResource() // 开始安全访问
            return AccessToken(url: url, stopAccess: { // 返回访问令牌
                if didAccess { // 确保开启成功
                    url.stopAccessingSecurityScopedResource() // 停止访问
                }
            })
        } catch { // 解析失败时回退
            NSLog("[MediaAccessService] beginAccess: 解析书签失败，回退使用 fileURL：\(error.localizedDescription)")
            let didAccess = fileURL.startAccessingSecurityScopedResource() // 尝试安全访问
            return AccessToken(url: fileURL, stopAccess: { // 返回原路径
                if didAccess { // 确保访问成功
                    fileURL.stopAccessingSecurityScopedResource() // 停止访问
                }
            })
        }
    }
}
