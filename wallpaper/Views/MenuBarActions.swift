import AppKit // 使用 AppKit
import Foundation // 使用 Foundation
import SwiftData // 使用 SwiftData
import UniformTypeIdentifiers
import UniformTypeIdentifiers

// MenuBarActions：菜单栏动作集合（模块化）
enum MenuBarActions { // 枚举作为命名空间
    static func showMainWindow() { // 显示主窗口
        NSLog("[菜单栏] 显示主窗口") // 日志
        NSApp.activate(ignoringOtherApps: true) // 激活应用
        NSApp.windows.first?.makeKeyAndOrderFront(nil) // 打开窗口
    } // 结束

    static func quitApp() { // 退出应用
        NSLog("[菜单栏] 退出应用") // 日志
        NSApp.terminate(nil) // 退出
    } // 结束

    static func stopVideoWallpaper() { // 停止视频壁纸
        NSLog("[菜单栏] 停止视频壁纸") // 日志
        VideoWallpaperService.shared.stopAll() // 停止播放
    } // 结束

    static func importMedia(in context: ModelContext) { // 导入素材
        NSLog("[菜单栏] 打开导入面板") // 日志
        let panel = NSOpenPanel() // 创建面板
        panel.canChooseFiles = true // 可选文件
        panel.canChooseDirectories = false // 不选目录
        panel.allowsMultipleSelection = true // 允许多选
        panel.allowedContentTypes = [.image, .movie] // 允许图片和视频
        let result = panel.runModal() // 显示面板
        if result == .OK { // 用户确认
            let urls = panel.urls // 获取选择
            NSLog("[菜单栏] 选择文件数量：\(urls.count)") // 日志
            for url in urls { // 遍历导入
                do { // 捕获错误
                    let result = try MediaImportService.importMedia(from: url) // 导入
                    context.insert(result.item) // 保存
                    NSLog("[菜单栏] 导入成功：\(url.lastPathComponent)") // 成功日志
                } catch { // 导入失败
                    NSLog("[菜单栏] 导入失败：\(url.lastPathComponent) \(error.localizedDescription)") // 失败日志
                } // 结束
            } // 结束
            try? context.save() // 保存
        } else { // 用户取消
            NSLog("[菜单栏] 导入取消") // 日志
        } // 结束
    } // 结束

    // 上一张/下一张 已移除
} // 结束
