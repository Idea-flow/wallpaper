import AppKit // 创建桌面窗口
import AVFoundation // 播放视频
import CoreGraphics // 使用桌面窗口层级

// VideoWallpaperService：管理视频壁纸的桌面播放
final class VideoWallpaperService {
    static let shared = VideoWallpaperService() // 单例实例

    // Entry：记录每个屏幕的窗口与播放器
    struct Entry {
        let window: NSWindow // 承载视频的窗口
        let player: AVPlayer // 视频播放器
        let endObserver: Any // 循环播放监听
    }

    private var entries: [ObjectIdentifier: Entry] = [:] // 屏幕对应的播放条目
    private var accessToken: MediaAccessService.AccessToken? // 长期安全访问令牌
    private var currentItem: MediaItem? // 当前视频素材
    private var currentFitMode: FitMode = .fill // 当前适配模式
    private var currentScreenID: String? // 当前目标屏幕
    private var screenObserver: Any? // 屏幕变化监听
    private var isReapplying = false // 防止重复重建

    private init() {} // 禁止外部初始化

    // applyVideo：将视频应用为桌面壁纸
    func applyVideo(item: MediaItem, fitMode: FitMode, screenID: String?) throws {
        print("[视频壁纸] 启动视频壁纸：\(item.fileURL.lastPathComponent)") // 关键步骤日志
        print("[视频壁纸] 目标屏幕ID：\(screenID ?? "all")") // 关键步骤日志

        let token = try MediaAccessService.beginAccess(for: item) // 开始安全访问
        let screens = NSScreen.screens // 获取所有屏幕
        print("[视频壁纸] 当前屏幕数量：\(screens.count)") // 关键步骤日志
        for screen in screens { // 打印屏幕详情
            print("[视频壁纸] 屏幕：\(screen.localizedName) | id=\(screenIdentifier(screen)) | frame=\(screen.frame)") // 关键步骤日志
        }
        let targetScreens = screenID == nil ? screens : screens.filter { screenIdentifier($0) == screenID } // 目标屏幕
        print("[视频壁纸] 目标屏幕数量：\(targetScreens.count)") // 关键步骤日志

        stopAll() // 启动前清理旧的播放
        accessToken = token // 保存访问令牌
        currentItem = item // 保存当前素材
        currentFitMode = fitMode // 保存当前模式
        currentScreenID = screenID // 保存当前目标
        startScreenObserver() // 监听屏幕变化

        for screen in targetScreens { // 遍历目标屏幕
            let gravity = videoGravity(for: fitMode) // 计算视频适配方式
            let window = makeWindow(for: screen) // 创建桌面窗口

            let asset = AVURLAsset(url: token.url) // 创建视频资源
            let playerItem = AVPlayerItem(asset: asset) // 创建播放条目
            let player = AVPlayer(playerItem: playerItem) // 创建播放器
            player.actionAtItemEnd = .none // 播放结束不自动停止

            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size)) // 创建容器视图
            view.wantsLayer = true // 启用图层
            view.autoresizingMask = [.width, .height] // 自适应窗口大小

            let layer = AVPlayerLayer(player: player) // 创建播放图层
            layer.videoGravity = gravity // 设置适配模式
            layer.frame = view.bounds // 设置图层大小
            view.layer = layer // 把图层挂在视图上

            window.contentView = view // 设置窗口内容
            window.orderBack(nil) // 放到桌面层
            player.play() // 播放视频
            NSLog("[视频壁纸] 视图大小：\(view.bounds) layer=\(layer.frame)") // 日志

            let endObserver = NotificationCenter.default.addObserver( // 监听播放结束
                forName: .AVPlayerItemDidPlayToEndTime, // 播放结束通知
                object: playerItem, // 仅监听当前条目
                queue: .main // 主线程
            ) { _ in
                player.seek(to: .zero) // 回到起点
                player.play() // 继续播放
            }

            let key = ObjectIdentifier(screen) // 生成屏幕标识
            entries[key] = Entry(window: window, player: player, endObserver: endObserver) // 保存条目
            print("[视频壁纸] 已启动屏幕：\(screen.localizedName) | id=\(screenIdentifier(screen))") // 关键步骤日志
        }
    }

    // stopAll：停止所有视频壁纸
    func stopAll() {
        if !entries.isEmpty { // 仅在有播放时打印
            print("[视频壁纸] 停止所有视频壁纸") // 关键步骤日志
        }
        for entry in entries.values { // 遍历条目
            NotificationCenter.default.removeObserver(entry.endObserver) // 移除监听
            entry.player.pause() // 暂停播放
            entry.window.orderOut(nil) // 隐藏窗口
        }
        entries.removeAll() // 清空条目
        accessToken?.stopAccess() // 释放安全访问
        accessToken = nil // 清空访问令牌
    }

    // makeWindow：创建桌面层窗口
    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let contentRect = NSRect(origin: .zero, size: screen.frame.size) // 内容区域尺寸
        let window = NSWindow( // 创建窗口
            contentRect: contentRect, // 使用屏幕尺寸
            styleMask: [.borderless], // 无边框
            backing: .buffered, // 缓冲方式
            defer: false, // 立即创建
            screen: screen // 目标屏幕
        )
        let desktopLevel = CGWindowLevelForKey(.desktopWindow) // 获取桌面层级
        window.level = NSWindow.Level(rawValue: Int(desktopLevel)) // 设置窗口层级
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary] // 多空间配置
        window.backgroundColor = .clear // 透明背景
        window.isOpaque = false // 非不透明
        window.hasShadow = false // 无阴影
        window.ignoresMouseEvents = true // 不拦截鼠标
        window.isMovable = false // 不允许移动
        window.titleVisibility = .hidden // 隐藏标题
        window.titlebarAppearsTransparent = true // 标题栏透明
        window.isReleasedWhenClosed = false // 避免被系统释放
        window.setFrame(screen.frame, display: true) // 强制设置到屏幕坐标
        NSLog("[视频壁纸] 窗口创建：screen=\(screen.localizedName) frame=\(screen.frame) content=\(contentRect)") // 日志
        return window // 返回窗口
    }

    // videoGravity：根据适配模式选择视频缩放
    private func videoGravity(for fitMode: FitMode) -> AVLayerVideoGravity {
        switch fitMode { // 根据模式选择
        case .fill:
            return .resizeAspectFill // 填充
        case .fit:
            return .resizeAspect // 适应
        case .stretch:
            return .resize // 拉伸
        case .center:
            return .resizeAspect // 近似居中
        case .tile:
            return .resizeAspectFill // 近似平铺
        }
    }

    // screenIdentifier：获取屏幕唯一 ID
    private func screenIdentifier(_ screen: NSScreen) -> String { // 屏幕 ID
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber { // 读取编号
            return number.stringValue // 返回编号
        }
        return screen.localizedName // 回退到名称
    }

    // startScreenObserver：监听屏幕变化并重建视频壁纸
    private func startScreenObserver() { // 屏幕监听
        guard screenObserver == nil else { return } // 避免重复注册
        screenObserver = NotificationCenter.default.addObserver( // 注册监听
            forName: NSApplication.didChangeScreenParametersNotification, // 屏幕变化
            object: nil, // 全局
            queue: .main // 主线程
        ) { [weak self] _ in
            self?.reapplyIfNeeded() // 重新应用
        }
    }

    // reapplyIfNeeded：屏幕变化时重建
    private func reapplyIfNeeded() { // 重新应用
        guard !isReapplying else { return } // 防止递归
        guard let item = currentItem else { return } // 没有视频
        isReapplying = true // 标记
        defer { isReapplying = false } // 结束恢复
        NSLog("[视频壁纸] 屏幕变化，准备重建视频壁纸") // 日志
        do {
            try applyVideo(item: item, fitMode: currentFitMode, screenID: currentScreenID) // 重建
        } catch {
            NSLog("[视频壁纸] 重建失败：\(error.localizedDescription)") // 日志
        }
    }
}
