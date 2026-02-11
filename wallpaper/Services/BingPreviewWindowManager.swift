import AppKit // NSWindow
import SwiftUI // SwiftUI
import SwiftData // SwiftData

// BingPreviewWindowManager：管理 Bing 预览窗口
final class BingPreviewWindowManager: NSObject { // 管理器
    static let shared = BingPreviewWindowManager() // 单例

    private var windows: [String: NSWindow] = [:] // 窗口缓存
    private var delegates: [String: WindowDelegate] = [:] // 代理缓存
    private var pendingTasks: [String: Task<Void, Never>] = [:] // 异步任务

    // show：打开预览窗口
    func show(item: BingWallpaperItem, store: BingWallpaperStore, modelContext: ModelContext) { // 打开窗口
        if let existing = windows[item.id] { // 已存在
            existing.makeKeyAndOrderFront(nil) // 置前
            NSApp.activate(ignoringOtherApps: true) // 激活应用
            return // 结束
        }

        if let task = pendingTasks[item.id] { // 已有任务
            task.cancel() // 取消旧任务
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.openWindow(item: item, store: store, modelContext: modelContext)
        }
        pendingTasks[item.id] = task
    }

    @MainActor
    private func openWindow(item: BingWallpaperItem, store: BingWallpaperStore, modelContext: ModelContext) async {
        let targetSize = await preferredWindowSize(for: item)
        let window = NSWindow( // 创建窗口
            contentRect: NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height), // 初始大小
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], // 顶栏按钮覆盖内容
            backing: .buffered, // 缓冲
            defer: false // 立即创建
        )
        window.title = item.displayTitle // 标题
        window.identifier = NSUserInterfaceItemIdentifier("bingPreview") // 标记预览窗口
        window.titleVisibility = .hidden // 隐藏标题文本
        window.titlebarAppearsTransparent = true // 透明标题栏
        window.isMovableByWindowBackground = true // 拖动背景移动
        window.isOpaque = false // 透明
        window.backgroundColor = .clear // 清空背景
        window.hasShadow = true // 阴影

        let rootView = BingWallpaperPreviewView(store: store, item: item) { [weak window] in // 预览视图
            window?.performClose(nil) // 关闭窗口
        }
        .environment(\.modelContext, modelContext) // 注入数据上下文

        let hosting = NSHostingView(rootView: rootView) // 宿主视图
        window.contentView = hosting // 设置内容
        window.center() // 居中
        window.isReleasedWhenClosed = false // 关闭不释放

        let delegate = WindowDelegate { [weak self] in // 关闭回调
            self?.windows[item.id] = nil // 清理窗口
            self?.delegates[item.id] = nil // 清理代理
            self?.pendingTasks[item.id] = nil // 清理任务
        }
        window.delegate = delegate // 绑定代理

        windows[item.id] = window // 缓存窗口
        delegates[item.id] = delegate // 缓存代理
        pendingTasks[item.id] = nil // 清理任务

        window.makeKeyAndOrderFront(nil) // 显示窗口
        NSApp.activate(ignoringOtherApps: true) // 激活应用
    }

    private func preferredWindowSize(for item: BingWallpaperItem) async -> NSSize {
        let defaultSize = NSSize(width: 1100, height: 760)
        guard let imageSize = await fetchImageSize(for: item) else {
            return defaultSize
        }

        let screenFrame = NSScreen.main?.visibleFrame.size ?? defaultSize
        let maxSize = NSSize(width: screenFrame.width * 0.9, height: screenFrame.height * 0.9)
        return fittedSize(for: imageSize, maxSize: maxSize)
    }

    private func fittedSize(for imageSize: NSSize, maxSize: NSSize) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return maxSize }
        let widthRatio = maxSize.width / imageSize.width
        let heightRatio = maxSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio, 1.0)
        return NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func fetchImageSize(for item: BingWallpaperItem) async -> NSSize? {
        let url = item.uhdImageURL
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                return image.size
            }
        } catch {
            // 忽略错误，回退默认尺寸
        }
        if url != item.fullImageURL {
            do {
                let (data, _) = try await URLSession.shared.data(from: item.fullImageURL)
                if let image = NSImage(data: data) {
                    return image.size
                }
            } catch {
                // 忽略错误，回退默认尺寸
            }
        }
        return nil
    }
}

// WindowDelegate：窗口关闭回调
final class WindowDelegate: NSObject, NSWindowDelegate { // 代理类
    private let onClose: () -> Void // 关闭回调

    init(onClose: @escaping () -> Void) { // 初始化
        self.onClose = onClose // 保存回调
    }

    func windowWillClose(_ notification: Notification) { // 窗口关闭
        onClose() // 触发回调
    }
}
