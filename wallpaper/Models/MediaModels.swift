import Foundation // 基础类型
import SwiftData // SwiftData 模型

// MediaType：素材类型
enum MediaType: String, Codable, CaseIterable {
    case image // 图片
    case video // 视频
}

// FitMode：适配模式
enum FitMode: String, Codable, CaseIterable {
    case fill // 填充
    case fit // 适应
    case stretch // 拉伸
    case center // 居中
    case tile // 平铺
}

extension FitMode {
    var displayName: String { // macOS 原生墙纸模式名称
        switch self {
        case .fill: return "充满屏幕"
        case .fit: return "适应于屏幕"
        case .stretch: return "拉伸以充满屏幕"
        case .center: return "居中显示"
        case .tile: return "拼贴"
        }
    }
}

// RuleScope：规则作用范围
enum RuleScope: String, Codable, CaseIterable {
    case global // 全局
    case screen // 单屏幕
}

// RandomStrategy：随机策略
enum RandomStrategy: String, Codable, CaseIterable {
    case uniform // 均匀
    case weighted // 权重
    case avoidRecent // 避免近期重复
}

// MediaItem：素材模型（图片/视频）
@Model
final class MediaItem {
    var id: UUID // 唯一 ID
    var typeRaw: String // 类型字符串
    var fileURL: URL // 文件路径
    var bookmarkData: Data? // 安全书签
    var createdAt: Date // 创建时间
    var lastUsedAt: Date? // 最近使用时间

    var width: Double? // 宽度
    var height: Double? // 高度
    var duration: Double? // 时长
    var frameRate: Double? // 帧率
    var sizeBytes: Int64? // 文件大小

    var tags: String // 标签
    var rating: Int // 评分
    var isFavorite: Bool // 收藏

    init( // 初始化
        id: UUID = UUID(), // 默认 ID
        type: MediaType, // 类型
        fileURL: URL, // 路径
        bookmarkData: Data? = nil, // 书签
        createdAt: Date = Date(), // 创建时间
        lastUsedAt: Date? = nil, // 最近使用
        width: Double? = nil, // 宽度
        height: Double? = nil, // 高度
        duration: Double? = nil, // 时长
        frameRate: Double? = nil, // 帧率
        sizeBytes: Int64? = nil, // 大小
        tags: String = "", // 标签
        rating: Int = 0, // 评分
        isFavorite: Bool = false // 收藏
    ) {
        self.id = id // 赋值
        self.typeRaw = type.rawValue // 赋值
        self.fileURL = fileURL // 赋值
        self.bookmarkData = bookmarkData // 赋值
        self.createdAt = createdAt // 赋值
        self.lastUsedAt = lastUsedAt // 赋值
        self.width = width // 赋值
        self.height = height // 赋值
        self.duration = duration // 赋值
        self.frameRate = frameRate // 赋值
        self.sizeBytes = sizeBytes // 赋值
        self.tags = tags // 赋值
        self.rating = rating // 赋值
        self.isFavorite = isFavorite // 赋值
    }

    var type: MediaType { // 类型转换
        get { MediaType(rawValue: typeRaw) ?? .image } // 读取
        set { typeRaw = newValue.rawValue } // 写入
    }
}

// Album：相册模型
@Model
final class Album {
    var id: UUID // 唯一 ID
    var name: String // 名称
    @Relationship(deleteRule: .nullify) var items: [MediaItem] // 关联素材

    init(id: UUID = UUID(), name: String, items: [MediaItem] = []) { // 初始化
        self.id = id // 赋值
        self.name = name // 赋值
        self.items = items // 赋值
    }
}

// Rule：规则模型
@Model
final class Rule {
    var id: UUID // 唯一 ID
    var name: String? // 规则名称
    var scopeRaw: String // 作用范围
    var screenID: String? // 目标屏幕 ID（仅单屏）
    var priority: Int // 优先级
    var enabled: Bool // 是否启用
    var intervalMinutes: Int? // 切换间隔（分钟）
    var weekdaysRaw: String // 工作日配置
    var startMinutes: Int? // 开始时间
    var endMinutes: Int? // 结束时间
    var randomStrategyRaw: String // 随机策略
    var mediaMixRatio: Double // 图片/视频比例
    @Relationship(deleteRule: .nullify) var album: Album? // 关联相册

    init( // 初始化
        id: UUID = UUID(), // 默认 ID
        name: String? = "新规则", // 名称
        scope: RuleScope = .global, // 作用范围
        screenID: String? = nil, // 屏幕 ID
        priority: Int = 0, // 优先级
        enabled: Bool = true, // 是否启用
        intervalMinutes: Int? = 60, // 间隔
        weekdaysRaw: String = "", // 工作日
        startMinutes: Int? = nil, // 开始时间
        endMinutes: Int? = nil, // 结束时间
        randomStrategy: RandomStrategy = .uniform, // 随机策略
        mediaMixRatio: Double = 0.5, // 比例
        album: Album? = nil // 相册
    ) {
        self.id = id // 赋值
        self.name = name // 赋值
        self.scopeRaw = scope.rawValue // 赋值
        self.screenID = screenID // 赋值
        self.priority = priority // 赋值
        self.enabled = enabled // 赋值
        self.intervalMinutes = intervalMinutes // 赋值
        self.weekdaysRaw = weekdaysRaw // 赋值
        self.startMinutes = startMinutes // 赋值
        self.endMinutes = endMinutes // 赋值
        self.randomStrategyRaw = randomStrategy.rawValue // 赋值
        self.mediaMixRatio = mediaMixRatio // 赋值
        self.album = album // 赋值
    }

    var scope: RuleScope { // 作用范围
        get { RuleScope(rawValue: scopeRaw) ?? .global } // 读取
        set { scopeRaw = newValue.rawValue } // 写入
    }

    var randomStrategy: RandomStrategy { // 随机策略
        get { RandomStrategy(rawValue: randomStrategyRaw) ?? .uniform } // 读取
        set { randomStrategyRaw = newValue.rawValue } // 写入
    }

    var weekdays: [Int] { // 工作日数组（1-7）
        get {
            weekdaysRaw
                .split(separator: ",")
                .compactMap { Int($0) }
        }
        set {
            weekdaysRaw = newValue.map(String.init).joined(separator: ",")
        }
    }
}

// ScreenProfile：屏幕偏好模型
@Model
final class ScreenProfile {
    var id: UUID // 唯一 ID
    var screenID: String // 屏幕标识
    var preferredFitModeRaw: String // 偏好适配模式
    @Relationship(deleteRule: .nullify) var preferredAlbum: Album? // 偏好相册

    init( // 初始化
        id: UUID = UUID(), // 默认 ID
        screenID: String, // 屏幕标识
        preferredFitMode: FitMode = .fill, // 适配模式
        preferredAlbum: Album? = nil // 相册
    ) {
        self.id = id // 赋值
        self.screenID = screenID // 赋值
        self.preferredFitModeRaw = preferredFitMode.rawValue // 赋值
        self.preferredAlbum = preferredAlbum // 赋值
    }

    var preferredFitMode: FitMode { // 适配模式
        get { FitMode(rawValue: preferredFitModeRaw) ?? .fill } // 读取
        set { preferredFitModeRaw = newValue.rawValue } // 写入
    }
}

// History：壁纸应用历史记录
@Model
final class History {
    var id: UUID // 唯一 ID
    @Relationship(deleteRule: .nullify) var media: MediaItem? // 关联素材
    var screenID: String // 屏幕 ID
    var appliedAt: Date // 应用时间
    var result: String // 结果
    var error: String? // 错误信息

    init( // 初始化
        id: UUID = UUID(), // 默认 ID
        media: MediaItem? = nil, // 素材
        screenID: String, // 屏幕 ID
        appliedAt: Date = Date(), // 应用时间
        result: String, // 结果
        error: String? = nil // 错误
    ) {
        self.id = id // 赋值
        self.media = media // 赋值
        self.screenID = screenID // 赋值
        self.appliedAt = appliedAt // 赋值
        self.result = result // 赋值
        self.error = error // 赋值
    }
}
