import AppKit // 使用 AppKit
import Foundation // 使用 Foundation
import SwiftData // 使用 SwiftData
import UniformTypeIdentifiers

// MenuBarActions：菜单栏动作集合（模块化）
enum MenuBarActions { // 枚举作为命名空间
    static func showMainWindow() { // 显示主窗口
        LogCenter.log("[菜单栏] 显示主窗口") // 日志
        NSApp.activate(ignoringOtherApps: true) // 激活应用
        if let window = mainWindow() { // 找到主窗口
            window.makeKeyAndOrderFront(nil) // 置前
            window.deminiaturize(nil) // 还原最小化
        } else {
            NSApp.windows.first?.makeKeyAndOrderFront(nil) // 兜底
        }
    } // 结束

    static func quitApp() { // 退出应用
        LogCenter.log("[菜单栏] 退出应用") // 日志
        NSApp.terminate(nil) // 退出
    } // 结束

    static func stopVideoWallpaper() { // 停止视频壁纸
        LogCenter.log("[菜单栏] 停止视频壁纸") // 日志
        VideoWallpaperService.shared.stopAll() // 停止播放
    } // 结束

    static func importMedia(in context: ModelContext) { // 导入素材
        LogCenter.log("[菜单栏] 打开导入面板") // 日志
        NSApp.activate(ignoringOtherApps: true) // 激活应用
        showMainWindow() // 打开主窗口
        let panel = NSOpenPanel() // 创建面板
        panel.canChooseFiles = true // 可选文件
        panel.canChooseDirectories = false // 不选目录
        panel.allowsMultipleSelection = true // 允许多选
        panel.allowedContentTypes = [.image, .movie] // 允许图片和视频
        if let window = NSApp.keyWindow ?? mainWindow() { // 有主窗口
            panel.beginSheetModal(for: window) { response in
                handlePanelResponse(response, panel: panel, context: context)
            }
        } else { // 无窗口时直接弹出
            let result = panel.runModal() // 显示面板
            handlePanelResponse(result, panel: panel, context: context)
        }
    } // 结束

    private static func handlePanelResponse(_ response: NSApplication.ModalResponse, panel: NSOpenPanel, context: ModelContext) {
        if response == .OK { // 用户确认
            let urls = panel.urls // 获取选择
            LogCenter.log("[菜单栏] 选择文件数量：\(urls.count)") // 日志
            for url in urls { // 遍历导入
                do { // 捕获错误
                    let result = try MediaImportService.importMedia(from: url) // 导入
                    context.insert(result.item) // 保存
                    LogCenter.log("[菜单栏] 导入成功：\(url.lastPathComponent)") // 成功日志
                } catch { // 导入失败
                    LogCenter.log("[菜单栏] 导入失败：\(url.lastPathComponent) \(error.localizedDescription)", level: .error) // 失败日志
                } // 结束
            } // 结束
            try? context.save() // 保存
        } else { // 用户取消
            LogCenter.log("[菜单栏] 导入取消") // 日志
        } // 结束
    }

    private static func mainWindow() -> NSWindow? { // 获取主窗口
        let candidates = NSApp.windows.filter { window in
            window.styleMask.contains(.titled) && !window.isSheet
        }
        if let key = candidates.first(where: { $0.isKeyWindow }) {
            return key
        }
        if let visible = candidates.first(where: { $0.isVisible }) {
            return visible
        }
        return candidates.first
    }

    // 上一张/下一张 已移除
} // 结束
