import AppKit // 使用 AppKit
import Foundation // 使用 Foundation
import SwiftData // 使用 SwiftData
import UniformTypeIdentifiers

// MenuBarActions：菜单栏动作集合（模块化）
enum MenuBarActions { // 枚举作为命名空间
    static func showMainWindow() { // 显示主窗口
        LogCenter.log("[菜单栏] 显示主窗口") // 日志
        WindowManager.showMainWindow()
    } // 结束

    static func quitApp() { // 退出应用
        LogCenter.log("[菜单栏] 退出应用") // 日志
        NSApp.terminate(nil) // 退出
    } // 结束

    static func stopVideoWallpaper() { // 停止视频壁纸
        LogCenter.log("[菜单栏] 停止视频壁纸") // 日志
        VideoWallpaperService.shared.stopAll() // 停止播放
    } // 结束

    static func pauseVideoWallpaper() { // 暂停视频壁纸
        LogCenter.log("[菜单栏] 暂停视频壁纸") // 日志
        VideoWallpaperService.shared.pauseAll()
    }

    static func resumeVideoWallpaper() { // 恢复视频壁纸
        LogCenter.log("[菜单栏] 恢复视频壁纸") // 日志
        VideoWallpaperService.shared.resumeAll()
    }

    static func importMedia(in context: ModelContext) { // 导入素材
        LogCenter.log("[菜单栏] 打开导入面板") // 日志
        NSApp.activate(ignoringOtherApps: true) // 激活应用
        showMainWindow() // 打开主窗口
        let panel = NSOpenPanel() // 创建面板
        panel.canChooseFiles = true // 可选文件
        panel.canChooseDirectories = false // 不选目录
        panel.allowsMultipleSelection = true // 允许多选
        panel.allowedContentTypes = [.image, .movie] // 允许图片和视频
        if let window = NSApp.keyWindow ?? WindowManager.mainWindow() { // 有主窗口
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

    static func applyRandomWallpaper(in context: ModelContext) { // 随机壁纸
        do { // 捕获错误
            let items = try context.fetch(FetchDescriptor<MediaItem>()) // 获取素材
            guard let item = items.randomElement() else { // 无素材
                LogCenter.log("[菜单栏] 随机壁纸失败：素材库为空", level: .warning) // 日志
                return // 结束
            }
            LogCenter.log("[菜单栏] 随机选择：\(item.fileURL.lastPathComponent)") // 日志
            if item.type == .image { // 图片
                VideoWallpaperService.shared.stopAll() // 停止视频壁纸
                try MediaAccessService.withResolvedURL(for: item) { url in // 安全访问
                    try WallpaperService.applyImage(url: url, to: nil, fitMode: .fill) // 应用图片
                }
                LogCenter.log("[菜单栏] 随机图片已应用") // 成功日志
            } else if item.type == .video { // 视频
                try VideoWallpaperService.shared.applyVideo(item: item, fitMode: .fill, screenID: nil) // 应用视频
                LogCenter.log("[菜单栏] 随机视频已应用") // 成功日志
            } else { // 其他类型
                LogCenter.log("[菜单栏] 随机壁纸失败：不支持的素材类型", level: .warning) // 日志
            }
        } catch { // 失败处理
            LogCenter.log("[菜单栏] 随机壁纸失败：\(error.localizedDescription)", level: .error) // 日志
        }
    }

    // 上一张/下一张 已移除
} // 结束
