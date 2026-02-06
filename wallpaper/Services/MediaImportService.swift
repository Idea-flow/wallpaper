import AppKit // 用于读取图片尺寸
import AVFoundation // 用于读取视频信息
import UniformTypeIdentifiers // 用于识别文件类型

// MediaImportService：导入图片/视频素材并创建 MediaItem
struct MediaImportService {
    // ImportResult：导入结果
    struct ImportResult {
        let item: MediaItem // 导入后的素材对象
    }

    // importMedia：导入指定 URL 的素材
    static func importMedia(from url: URL) throws -> ImportResult {
        let didAccess = url.startAccessingSecurityScopedResource() // 开始安全访问
        defer { // 函数结束时释放
            if didAccess { // 确保访问已开启
                url.stopAccessingSecurityScopedResource() // 停止访问
            }
        }

        print("[导入] 开始导入：\(url.lastPathComponent)") // 关键步骤日志

        let type = detectType(for: url) // 检测素材类型
        let bookmarkData = try? url.bookmarkData( // 生成安全书签
            options: [.withSecurityScope], // 安全作用域
            includingResourceValuesForKeys: nil, // 不额外请求资源键
            relativeTo: nil // 不使用相对路径
        )
        let sizeBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) // 读取文件大小
            .map { Int64($0) } // 转成 Int64

        switch type { // 根据素材类型处理
        case .image:
            let image = NSImage(contentsOf: url) // 读取图片
            let width = image.map { Double($0.size.width) } // 宽度
            let height = image.map { Double($0.size.height) } // 高度
            let item = MediaItem( // 创建素材模型
                type: .image, // 类型：图片
                fileURL: url, // 文件路径
                bookmarkData: bookmarkData, // 书签
                width: width, // 宽度
                height: height, // 高度
                sizeBytes: sizeBytes // 文件大小
            )
            print("[导入] 图片完成：\(url.lastPathComponent)") // 关键步骤日志
            return ImportResult(item: item) // 返回导入结果
        case .video:
            let asset = AVAsset(url: url) // 创建视频资源
            let duration = asset.duration.seconds // 时长
            let track = asset.tracks(withMediaType: .video).first // 获取视频轨
            let frameRate = track?.nominalFrameRate // 帧率
            let size = track?.naturalSize // 尺寸
            let item = MediaItem( // 创建素材模型
                type: .video, // 类型：视频
                fileURL: url, // 文件路径
                bookmarkData: bookmarkData, // 书签
                width: size.map { Double($0.width) }, // 宽度
                height: size.map { Double($0.height) }, // 高度
                duration: duration.isFinite ? duration : nil, // 时长
                frameRate: frameRate.map { Double($0) }, // 帧率
                sizeBytes: sizeBytes // 文件大小
            )
            print("[导入] 视频完成：\(url.lastPathComponent)") // 关键步骤日志
            return ImportResult(item: item) // 返回导入结果
        }
    }

    // updateItem：用新的 URL 更新已有素材
    static func updateItem(_ item: MediaItem, from url: URL) throws {
        let didAccess = url.startAccessingSecurityScopedResource() // 开始安全访问
        defer { // 函数结束时释放
            if didAccess { // 确保访问已开启
                url.stopAccessingSecurityScopedResource() // 停止访问
            }
        }

        print("[导入] 更新素材：\(url.lastPathComponent)") // 关键步骤日志

        let type = detectType(for: url) // 检测素材类型
        let bookmarkData = try? url.bookmarkData( // 生成安全书签
            options: [.withSecurityScope], // 安全作用域
            includingResourceValuesForKeys: nil, // 不额外请求资源键
            relativeTo: nil // 不使用相对路径
        )
        let sizeBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) // 读取文件大小
            .map { Int64($0) } // 转成 Int64

        item.fileURL = url // 更新路径
        item.bookmarkData = bookmarkData // 更新书签
        item.type = type // 更新类型
        item.sizeBytes = sizeBytes // 更新大小

        switch type { // 根据素材类型处理
        case .image:
            let image = NSImage(contentsOf: url) // 读取图片
            item.width = image.map { Double($0.size.width) } // 宽度
            item.height = image.map { Double($0.size.height) } // 高度
            item.duration = nil // 清空视频时长
            item.frameRate = nil // 清空帧率
            print("[导入] 图片更新完成：\(url.lastPathComponent)") // 关键步骤日志
        case .video:
            let asset = AVAsset(url: url) // 创建视频资源
            let duration = asset.duration.seconds // 时长
            let track = asset.tracks(withMediaType: .video).first // 获取视频轨
            let frameRate = track?.nominalFrameRate // 帧率
            let size = track?.naturalSize // 尺寸
            item.width = size.map { Double($0.width) } // 宽度
            item.height = size.map { Double($0.height) } // 高度
            item.duration = duration.isFinite ? duration : nil // 时长
            item.frameRate = frameRate.map { Double($0) } // 帧率
            print("[导入] 视频更新完成：\(url.lastPathComponent)") // 关键步骤日志
        }
    }

    // detectType：根据扩展名识别类型
    static func detectType(for url: URL) -> MediaType {
        let type = UTType(filenameExtension: url.pathExtension) // 识别扩展名
        if type?.conforms(to: .movie) == true { // 判断是否为视频
            return .video // 返回视频类型
        }
        return .image // 默认图片
    }
}
