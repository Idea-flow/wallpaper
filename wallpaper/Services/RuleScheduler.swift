import AppKit // 屏幕与运行循环
import SwiftData // 数据访问

// RuleScheduler：规则调度与自动切换
@MainActor
final class RuleScheduler {
    static let shared = RuleScheduler() // 单例

    private var timer: Timer? // 定时器
    private var lastAppliedAt: Date? // 上次执行时间

    private init() {}

    // start：启动调度
    func start(container: ModelContainer) {
        stop() // 先停止旧任务
        let context = ModelContext(container) // 创建上下文
        applyOnce(context: context) // 立即执行一次
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.applyOnce(context: context) // 每分钟检查
            }
        }
        RunLoop.main.add(timer!, forMode: .common) // 加入运行循环
        LogCenter.log("[规则] 调度器已启动") // 日志
    }

    // stop：停止调度
    func stop() {
        timer?.invalidate() // 停止定时器
        timer = nil // 释放
    }

    // applyOnce：执行一次规则匹配
    private func applyOnce(context: ModelContext) {
        let now = Date() // 当前时间
        if let last = lastAppliedAt, now.timeIntervalSince(last) < 30 {
            return // 防止过于频繁
        }

        let rules = fetchRules(context) // 获取规则
        let activeRules = rules.filter { isRuleActive($0, at: now) } // 过滤有效规则
        let sorted = activeRules.sorted { $0.priority > $1.priority } // 按优先级排序

        guard let rule = sorted.first else { // 没有可用规则
            return
        }

        if let last = lastAppliedAt { // 根据规则间隔判断
            let minutes = rule.intervalMinutes ?? 60
            let interval = TimeInterval(max(minutes, 1) * 60)
            if now.timeIntervalSince(last) < interval {
                return
            }
        }

        apply(rule: rule, context: context) // 执行规则
        lastAppliedAt = now // 更新执行时间
    }

    private func fetchRules(_ context: ModelContext) -> [Rule] { // 读取规则
        let descriptor = FetchDescriptor<Rule>() // 描述符
        return (try? context.fetch(descriptor)) ?? [] // 返回
    }

    private func isRuleActive(_ rule: Rule, at date: Date) -> Bool { // 判断规则是否生效
        guard rule.enabled else { return false } // 必须启用

        let calendar = Calendar.current // 日历
        let weekday = calendar.component(.weekday, from: date) // 星期（1-7）
        if !rule.weekdays.isEmpty, !rule.weekdays.contains(weekday) { // 工作日限制
            return false
        }

        if let start = rule.startMinutes, let end = rule.endMinutes { // 时间段限制
            let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
            if start <= end {
                if minutes < start || minutes > end { return false }
            } else { // 跨夜
                if minutes > end && minutes < start { return false }
            }
        }

        return true
    }

    private func apply(rule: Rule, context: ModelContext) { // 执行规则
        let items = pickCandidates(rule: rule, context: context) // 获取候选
        guard let item = pickOne(rule: rule, items: items) else { return } // 选择素材

        let targetScreen = rule.scope == .screen ? rule.screenID : nil // 目标屏幕

        do {
            if item.type == .image {
                VideoWallpaperService.shared.stopAll() // 切换到图片时停止视频壁纸
                try MediaAccessService.withResolvedURL(for: item) { url in
                    let screen = targetScreen == nil ? nil : ScreenHelper.screenByID(targetScreen!)
                    try WallpaperService.applyImage(url: url, to: screen, fitMode: .fill)
                }
                LogCenter.log("[规则] 已应用图片壁纸：\(item.fileURL.lastPathComponent)")
                CurrentWallpaperStore.shared.setCurrent(item: item) // 标记当前壁纸
            } else if item.type == .video {
                try VideoWallpaperService.shared.applyVideo(item: item, fitMode: .fill, screenID: targetScreen)
                LogCenter.log("[规则] 已应用视频壁纸：\(item.fileURL.lastPathComponent)")
                CurrentWallpaperStore.shared.setCurrent(item: item) // 标记当前壁纸
            }
            item.lastUsedAt = Date() // 更新使用时间
            try? context.save() // 保存
        } catch {
            LogCenter.log("[规则] 应用失败：\(error.localizedDescription)", level: .error)
        }
    }

    private func pickCandidates(rule: Rule, context: ModelContext) -> [MediaItem] { // 候选素材
        if let album = rule.album { // 有相册
            return album.items
        }
        let descriptor = FetchDescriptor<MediaItem>() // 全部素材
        return (try? context.fetch(descriptor)) ?? []
    }

    private func pickOne(rule: Rule, items: [MediaItem]) -> MediaItem? { // 选择素材
        guard !items.isEmpty else { return nil }

        let imageItems = items.filter { $0.type == .image }
        let videoItems = items.filter { $0.type == .video }

        let useVideo = Double.random(in: 0...1) < rule.mediaMixRatio
        let pool: [MediaItem]
        if useVideo, !videoItems.isEmpty {
            pool = videoItems
        } else if !imageItems.isEmpty {
            pool = imageItems
        } else {
            pool = items
        }

        switch rule.randomStrategy {
        case .uniform:
            return pool.randomElement()
        case .weighted:
            return weightedRandom(from: pool)
        case .avoidRecent:
            let recentCutoff = Date().addingTimeInterval(-3600 * 24) // 24 小时
            let filtered = pool.filter { ($0.lastUsedAt ?? .distantPast) < recentCutoff }
            return (filtered.isEmpty ? pool : filtered).randomElement()
        }
    }

    private func weightedRandom(from items: [MediaItem]) -> MediaItem? { // 权重随机
        let weights = items.map { item -> Double in
            var weight = 1.0
            weight += Double(item.rating)
            if item.isFavorite { weight += 2.0 }
            return weight
        }
        let total = weights.reduce(0, +)
        let threshold = Double.random(in: 0...total)
        var sum = 0.0
        for (index, weight) in weights.enumerated() {
            sum += weight
            if threshold <= sum { return items[index] }
        }
        return items.first
    }
}
