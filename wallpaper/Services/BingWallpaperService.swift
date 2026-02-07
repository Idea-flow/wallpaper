import Foundation // 基础能力

// BingWallpaperService：负责拉取 Bing 壁纸数据
struct BingWallpaperService { // 服务结构体
    // fetchWallpapers：拉取壁纸列表
    static func fetchWallpapers(market: String, index: Int, count: Int) async throws -> [BingWallpaperItem] { // 拉取方法
        let url = buildArchiveURL(market: market, index: index, count: count) // 构建接口 URL
        let (data, response) = try await URLSession.shared.data(from: url) // 请求数据
        guard let http = response as? HTTPURLResponse else { // 校验响应
            throw NSError(domain: "BingWallpaperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效的网络响应"]) // 抛出错误
        }
        guard (200...299).contains(http.statusCode) else { // 校验状态码
            throw NSError(domain: "BingWallpaperService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "请求失败：HTTP \(http.statusCode)"]) // 抛出错误
        }
        let decoded = try JSONDecoder().decode(BingArchiveResponse.self, from: data) // 解码 JSON
        return decoded.images.map { image in // 映射为模型
            let fullURL = buildFullURL(image.url) // 1080p 地址
            let link = buildCopyrightLink(image.copyrightlink) // 版权链接
            let id = makeID(urlBase: image.urlbase, startDate: image.startdate) // 生成唯一 ID
            return BingWallpaperItem( // 创建模型
                id: id, // 唯一 ID
                title: image.title ?? "", // 标题
                startDate: image.startdate, // 开始日期
                endDate: image.enddate, // 结束日期
                url: fullURL, // 1080p
                urlBase: image.urlbase, // 基础地址
                copyright: image.copyright, // 版权信息
                copyrightLink: link, // 版权链接
                market: market, // 市场
                isWallpaper: image.wp ?? true // 是否壁纸
            )
        }
    }

    // downloadImage：下载图片数据（优先 4K，失败回退）
    static func downloadImage(for item: BingWallpaperItem, preferUHD: Bool) async throws -> (data: Data, usedUHD: Bool) { // 下载方法
        if preferUHD { // 优先 4K
            if let data = try? await fetchData(from: item.uhdImageURL) { // 尝试 4K
                return (data, true) // 返回 4K
            }
        }
        let data = try await fetchData(from: item.fullImageURL) // 回退 1080p
        return (data, false) // 返回 1080p
    }

    // buildArchiveURL：构建接口地址
    private static func buildArchiveURL(market: String, index: Int, count: Int) -> URL { // 拼接 URL
        var components = URLComponents() // 组件
        components.scheme = "https" // 协议
        components.host = "www.bing.com" // 主机
        components.path = "/HPImageArchive.aspx" // 路径
        components.queryItems = [ // 参数
            URLQueryItem(name: "format", value: "js"), // JSON 格式
            URLQueryItem(name: "idx", value: String(index)), // 起始天数
            URLQueryItem(name: "n", value: String(count)), // 数量
            URLQueryItem(name: "mkt", value: market) // 市场
        ]
        return components.url! // 返回 URL
    }

    // buildFullURL：拼接完整地址
    private static func buildFullURL(_ path: String) -> URL { // 拼接
        if path.hasPrefix("http") { // 已是完整 URL
            return URL(string: path)! // 直接返回
        }
        let full = "https://www.bing.com\(path)" // 拼接完整地址
        return URL(string: full)! // 返回 URL
    }

    // buildCopyrightLink：构建版权链接
    private static func buildCopyrightLink(_ link: String?) -> URL? { // 构建链接
        guard let link, !link.isEmpty else { return nil } // 空链接
        if link.hasPrefix("javascript") { return nil } // 过滤无效链接
        return buildFullURL(link) // 构建完整链接
    }

    // makeID：生成稳定 ID
    private static func makeID(urlBase: String, startDate: String) -> String { // 生成 ID
        let name = urlBase.replacingOccurrences(of: "/th?id=", with: "") // 去掉前缀
        let clean = name.split(separator: "&").first.map(String.init) ?? name // 去掉参数
        return "\(startDate)_\(clean)" // 组合 ID
    }

    // fetchData：下载数据并检查状态码
    private static func fetchData(from url: URL) async throws -> Data { // 下载数据
        let (data, response) = try await URLSession.shared.data(from: url) // 请求
        guard let http = response as? HTTPURLResponse else { // 校验响应
            throw NSError(domain: "BingWallpaperService", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效的网络响应"]) // 错误
        }
        guard (200...299).contains(http.statusCode) else { // 状态码检查
            throw NSError(domain: "BingWallpaperService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "下载失败：HTTP \(http.statusCode)"]) // 错误
        }
        return data // 返回数据
    }
}

// BingArchiveResponse：接口返回结构
private struct BingArchiveResponse: Decodable { // 解码结构
    let images: [BingArchiveImage] // 图片列表
}

// BingArchiveImage：单条图片信息
private struct BingArchiveImage: Decodable { // 解码模型
    let url: String // 1080p 路径
    let urlbase: String // 基础路径
    let title: String? // 标题
    let startdate: String // 开始日期
    let enddate: String? // 结束日期
    let copyright: String // 版权
    let copyrightlink: String? // 版权链接
    let wp: Bool? // 是否可用作壁纸
}
