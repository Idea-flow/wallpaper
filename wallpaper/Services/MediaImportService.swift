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

        LogCenter.log("[导入] 开始导入：\(url.lastPathComponent)") // 关键步骤日志

        let localURL = try copyToAppLibraryIfNeeded(from: url) // 复制到应用目录
        let type = detectType(for: localURL) // 检测素材类型
        let sizeBytes = (try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) // 读取文件大小
            .map { Int64($0) } // 转成 Int64

        switch type { // 根据素材类型处理
        case .image:
            let image = NSImage(contentsOf: localURL) // 读取图片
            let width = image.map { Double($0.size.width) } // 宽度
            let height = image.map { Double($0.size.height) } // 高度
            let item = MediaItem( // 创建素材模型
                type: .image, // 类型：图片
                fileURL: localURL, // 文件路径
                bookmarkData: nil, // 应用目录无需书签
                width: width, // 宽度
                height: height, // 高度
                sizeBytes: sizeBytes // 文件大小
            )
            LogCenter.log("[导入] 图片完成：\(localURL.lastPathComponent)") // 关键步骤日志
            return ImportResult(item: item) // 返回导入结果
        case .video:
            let asset = AVAsset(url: localURL) // 创建视频资源
            let duration = asset.duration.seconds // 时长
            let track = asset.tracks(withMediaType: .video).first // 获取视频轨
            let frameRate = track?.nominalFrameRate // 帧率
            let size = track?.naturalSize // 尺寸
            let item = MediaItem( // 创建素材模型
                type: .video, // 类型：视频
                fileURL: localURL, // 文件路径
                bookmarkData: nil, // 应用目录无需书签
                width: size.map { Double($0.width) }, // 宽度
                height: size.map { Double($0.height) }, // 高度
                duration: duration.isFinite ? duration : nil, // 时长
                frameRate: frameRate.map { Double($0) }, // 帧率
                sizeBytes: sizeBytes // 文件大小
            )
            LogCenter.log("[导入] 视频完成：\(localURL.lastPathComponent)") // 关键步骤日志
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

        LogCenter.log("[导入] 更新素材：\(url.lastPathComponent)") // 关键步骤日志

        let localURL = try copyToAppLibraryIfNeeded(from: url) // 复制到应用目录
        let type = detectType(for: localURL) // 检测素材类型
        let sizeBytes = (try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) // 读取文件大小
            .map { Int64($0) } // 转成 Int64

        item.fileURL = localURL // 更新路径
        item.bookmarkData = nil // 应用目录无需书签
        item.type = type // 更新类型
        item.sizeBytes = sizeBytes // 更新大小

        switch type { // 根据素材类型处理
        case .image:
            let image = NSImage(contentsOf: localURL) // 读取图片
            item.width = image.map { Double($0.size.width) } // 宽度
            item.height = image.map { Double($0.size.height) } // 高度
            item.duration = nil // 清空视频时长
            item.frameRate = nil // 清空帧率
            LogCenter.log("[导入] 图片更新完成：\(localURL.lastPathComponent)") // 关键步骤日志
        case .video:
            let asset = AVAsset(url: localURL) // 创建视频资源
            let duration = asset.duration.seconds // 时长
            let track = asset.tracks(withMediaType: .video).first // 获取视频轨
            let frameRate = track?.nominalFrameRate // 帧率
            let size = track?.naturalSize // 尺寸
            item.width = size.map { Double($0.width) } // 宽度
            item.height = size.map { Double($0.height) } // 高度
            item.duration = duration.isFinite ? duration : nil // 时长
            item.frameRate = frameRate.map { Double($0) } // 帧率
            LogCenter.log("[导入] 视频更新完成：\(localURL.lastPathComponent)") // 关键步骤日志
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

    // copyToAppLibraryIfNeeded：把文件复制到应用目录
    private static func copyToAppLibraryIfNeeded(from url: URL) throws -> URL { // 复制文件
        let targetDirectory = try appMediaDirectory() // 获取应用目录
        if url.path.hasPrefix(targetDirectory.path) { // 已在应用目录
            return url // 直接返回
        }
        let fileManager = FileManager.default // 文件管理器
        let baseName = url.deletingPathExtension().lastPathComponent // 文件名
        let ext = url.pathExtension // 扩展名
        var destination = targetDirectory.appendingPathComponent(baseName).appendingPathExtension(ext) // 目标路径
        var index = 1 // 序号
        while fileManager.fileExists(atPath: destination.path) { // 重名处理
            let newName = "\(baseName)_\(index)" // 新名称
            destination = targetDirectory.appendingPathComponent(newName).appendingPathExtension(ext) // 新路径
            index += 1 // 递增
        }
        try fileManager.copyItem(at: url, to: destination) // 复制文件
        LogCenter.log("[导入] 已复制到应用目录：\(destination.lastPathComponent)") // 日志
        return destination // 返回新路径
    }

    // appMediaDirectory：应用内部素材目录
    private static func appMediaDirectory() throws -> URL { // 获取目录
        let fileManager = FileManager.default // 文件管理器
        let base = try fileManager.url( // 获取 Application Support
            for: .applicationSupportDirectory, // 目录类型
            in: .userDomainMask, // 用户域
            appropriateFor: nil, // 无需参考
            create: true // 自动创建
        )
        let folder = base.appendingPathComponent("wallpaper", isDirectory: true) // 应用子目录
        let mediaFolder = folder.appendingPathComponent("MediaLibrary", isDirectory: true) // 媒体目录
        if !fileManager.fileExists(atPath: mediaFolder.path) { // 不存在就创建
            try fileManager.createDirectory(at: mediaFolder, withIntermediateDirectories: true) // 创建目录
        }
        return mediaFolder // 返回目录
    }
}
