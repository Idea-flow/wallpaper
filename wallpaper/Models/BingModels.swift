import Foundation // 基础能力

// BingMarketOption：Bing 市场选项
struct BingMarketOption: Identifiable, Hashable { // 市场选项模型
    let id: String // 唯一 ID
    let name: String // 展示名称
}

// BingWallpaperItem：Bing 壁纸数据
struct BingWallpaperItem: Identifiable, Hashable { // 壁纸模型
    let id: String // 唯一 ID
    let title: String // 标题
    let startDate: String // 开始日期（yyyyMMdd）
    let endDate: String? // 结束日期
    let url: URL // 1080p 图片地址
    let urlBase: String // 基础地址（用于拼接 UHD）
    let copyright: String // 版权信息
    let copyrightLink: URL? // 版权链接
    let market: String // 市场
    let isWallpaper: Bool // 是否可用作壁纸

    var displayTitle: String { // 展示标题
        if !title.isEmpty { // 有标题
            return title // 用标题
        }
        return "Bing 壁纸" // 兜底标题
    }

    var displayDate: String { // 展示日期
        guard let date = parsedDate else { return startDate } // 解析失败回退
        return displayDateFormatter.string(from: date) // 格式化日期
    }

    var fullImageURL: URL { // 1080p 图片
        url // 返回原始 url
    }

    var uhdImageURL: URL { // 4K 图片
        let full = "https://www.bing.com\(urlBase)_UHD.jpg" // 拼接 UHD 地址
        return URL(string: full) ?? url // 失败回退原图
    }

    private var parsedDate: Date? { // 解析日期
        return parseDateFormatter.date(from: startDate) // 解析日期
    }

    private var parseDateFormatter: DateFormatter { // 解析格式器
        let formatter = DateFormatter() // 创建格式器
        formatter.dateFormat = "yyyyMMdd" // Bing 日期格式
        return formatter // 返回
    }

    private var displayDateFormatter: DateFormatter { // 展示格式器
        let formatter = DateFormatter() // 创建格式器
        formatter.locale = Locale(identifier: "zh_CN") // 中文区域
        formatter.dateFormat = "yyyy年M月d日" // 展示格式
        return formatter // 返回
    }
}
