import Foundation // 基础能力
import Observation // @Observable
import SwiftData // SwiftData

// BingWallpaperStore：Bing 壁纸状态与逻辑
@MainActor
@Observable
final class BingWallpaperStore { // 状态类
    var items: [BingWallpaperItem] = [] // 壁纸列表
    var market: String = "zh-CN" // 默认市场
    var dayIndex: Int = 0 // 0=今天
    var count: Int = 8 // 默认数量
    var preferUHD: Bool = true // 默认使用 4K
    var isLoading: Bool = false // 加载状态
    var errorMessage: String? // 错误信息
    var lastUpdated: Date? // 最近更新时间
    var downloadingIDs: Set<String> = [] // 正在下载的 ID

    let markets: [BingMarketOption] = [ // 市场选项
        BingMarketOption(id: "zh-CN", name: "中国"), // 中国
        BingMarketOption(id: "en-US", name: "美国"), // 美国
        BingMarketOption(id: "ja-JP", name: "日本"), // 日本
        BingMarketOption(id: "en-GB", name: "英国"), // 英国
        BingMarketOption(id: "de-DE", name: "德国"), // 德国
        BingMarketOption(id: "fr-FR", name: "法国"), // 法国
        BingMarketOption(id: "es-ES", name: "西班牙"), // 西班牙
        BingMarketOption(id: "it-IT", name: "意大利") // 意大利
    ]

    var dayLabel: String { // 日期标签
        switch dayIndex { // 判断索引
        case 0: return "今天" // 今天
        case 1: return "昨天" // 昨天
        case 2: return "前天" // 前天
        default: return "\(dayIndex) 天前" // 更早
        }
    }

    // load：拉取壁纸
    func load() async { // 拉取方法
        if isLoading { return } // 避免重复
        isLoading = true // 标记加载
        errorMessage = nil // 清空错误
        LogCenter.log("[Bing] 开始拉取：mkt=\(market) idx=\(dayIndex) n=\(count)") // 日志
        do { // 捕获错误
            let data = try await BingWallpaperService.fetchWallpapers(market: market, index: dayIndex, count: count) // 拉取
            items = data // 赋值
            lastUpdated = Date() // 更新时间
            LogCenter.log("[Bing] 拉取成功：\(items.count) 张") // 日志
        } catch { // 失败处理
            errorMessage = error.localizedDescription // 错误信息
            LogCenter.log("[Bing] 拉取失败：\(error.localizedDescription)", level: .error) // 日志
        }
        isLoading = false // 结束加载
    }

    // downloadToLibrary：下载并保存到素材库
    func downloadToLibrary(_ item: BingWallpaperItem, modelContext: ModelContext) async { // 下载方法
        if downloadingIDs.contains(item.id) { return } // 避免重复
        downloadingIDs.insert(item.id) // 标记下载
        defer { downloadingIDs.remove(item.id) } // 结束移除

        LogCenter.log("[Bing] 开始下载：\(item.displayTitle)") // 日志
        do { // 捕获错误
            let result = try await BingWallpaperService.downloadImage(for: item, preferUHD: preferUHD) // 下载
            let fileName = makeFileName(for: item, usedUHD: result.usedUHD) // 生成文件名
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName) // 临时文件
            try result.data.write(to: tempURL, options: .atomic) // 写入文件
            let importResult = try MediaImportService.importMedia(from: tempURL) // 导入素材
            modelContext.insert(importResult.item) // 写入数据库
            try? modelContext.save() // 保存数据
            try? FileManager.default.removeItem(at: tempURL) // 删除临时文件
            if result.usedUHD { // 4K 成功
                LogCenter.log("[Bing] 下载成功（4K）：\(fileName)") // 日志
            } else { // 回退 1080p
                LogCenter.log("[Bing] 4K 不可用，回退 1080p：\(fileName)", level: .warning) // 日志
            }
        } catch { // 失败处理
            LogCenter.log("[Bing] 下载失败：\(error.localizedDescription)", level: .error) // 日志
        }
    }

    // makeFileName：生成文件名
    private func makeFileName(for item: BingWallpaperItem, usedUHD: Bool) -> String { // 文件名
        let title = safeFileNameBase(from: item.displayTitle) // 可读标题
        let suffix = usedUHD ? "4k" : "1080" // 分辨率后缀
        return "\(title)_\(item.startDate)_\(suffix).jpg" // 文件名
    }

    private func safeFileNameBase(from title: String) -> String { // 清理文件名
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Bing壁纸" }
        return trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}
