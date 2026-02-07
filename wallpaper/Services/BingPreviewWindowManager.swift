import AppKit // NSWindow
import SwiftUI // SwiftUI
import SwiftData // SwiftData

// BingPreviewWindowManager：管理 Bing 预览窗口
final class BingPreviewWindowManager: NSObject { // 管理器
    static let shared = BingPreviewWindowManager() // 单例

    private var windows: [String: NSWindow] = [:] // 窗口缓存
    private var delegates: [String: WindowDelegate] = [:] // 代理缓存

    // show：打开预览窗口
    func show(item: BingWallpaperItem, store: BingWallpaperStore, modelContext: ModelContext) { // 打开窗口
        if let existing = windows[item.id] { // 已存在
            existing.makeKeyAndOrderFront(nil) // 置前
            NSApp.activate(ignoringOtherApps: true) // 激活应用
            return // 结束
        }

        let rootView = BingWallpaperPreviewView(store: store, item: item) // 预览视图
            .environment(\.modelContext, modelContext) // 注入数据上下文

        let hosting = NSHostingView(rootView: rootView) // 宿主视图
        let window = NSWindow( // 创建窗口
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), // 初始大小
            styleMask: [.titled, .closable, .resizable, .miniaturizable], // 窗口样式
            backing: .buffered, // 缓冲
            defer: false // 立即创建
        )
        window.title = item.displayTitle // 标题
        window.contentView = hosting // 设置内容
        window.center() // 居中
        window.isReleasedWhenClosed = false // 关闭不释放

        let delegate = WindowDelegate { [weak self] in // 关闭回调
            self?.windows[item.id] = nil // 清理窗口
            self?.delegates[item.id] = nil // 清理代理
        }
        window.delegate = delegate // 绑定代理

        windows[item.id] = window // 缓存窗口
        delegates[item.id] = delegate // 缓存代理

        window.makeKeyAndOrderFront(nil) // 显示窗口
        NSApp.activate(ignoringOtherApps: true) // 激活应用
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
