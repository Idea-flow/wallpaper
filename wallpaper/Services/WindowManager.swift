import AppKit

enum WindowManager {
    static let diagnosticsTitle = "监控与诊断"

    static func mainWindow() -> NSWindow? {
        let candidates = NSApp.windows.filter { window in
            window.styleMask.contains(.titled) && window.title != diagnosticsTitle
        }
        if let key = candidates.first(where: { $0.isKeyWindow }) {
            return key
        }
        if let visible = candidates.first(where: { $0.isVisible }) {
            return visible
        }
        return candidates.first
    }

    static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow() {
            window.makeKeyAndOrderFront(nil)
            window.deminiaturize(nil)
        }
    }
}
