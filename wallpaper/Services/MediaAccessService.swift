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
        guard let bookmarkData = item.bookmarkData else { // 没有书签时直接使用原路径
            return try action(item.fileURL) // 执行访问逻辑
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
        } catch { // 解析失败时回退
            return try action(item.fileURL) // 使用原路径尝试
        }
    }

    // loadImage：读取图片并返回 NSImage
    static func loadImage(for item: MediaItem) -> NSImage? {
        do { // 捕获读取错误
            return try withResolvedURL(for: item) { url in // 使用安全访问读取
                if let image = NSImage(contentsOf: url) { // 直接用 URL 读取
                    return image // 返回图片
                }
                if let data = try? Data(contentsOf: url) { // 读取文件数据
                    return NSImage(data: data) // 从数据生成图片
                }
                return nil // 读取失败
            }
        } catch { // 捕获任何异常
            return nil // 返回空
        }
    }

    // beginAccess：保持安全访问，用于视频播放等长期任务
    static func beginAccess(for item: MediaItem) throws -> AccessToken {
        guard let bookmarkData = item.bookmarkData else { // 没有书签
            return AccessToken(url: item.fileURL, stopAccess: {}) // 直接返回原路径
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
            return AccessToken(url: item.fileURL, stopAccess: {}) // 返回原路径
        }
    }
}
