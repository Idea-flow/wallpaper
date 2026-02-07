import AppKit // NSWorkspace
import SwiftData // SwiftData
import SwiftUI // SwiftUI

// DiagnosticsView：监控与诊断
struct DiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var mediaItems: [MediaItem] // 素材
    @Query(sort: \Album.name, order: .forward) private var albums: [Album] // 相册
    @Query(sort: \Rule.priority, order: .reverse) private var rules: [Rule] // 规则
    @Query(sort: \History.appliedAt, order: .reverse) private var histories: [History] // 历史

    @State private var fixResultMessage: String? // 修复结果提示
    @State private var isFixingMissing = false // 修复中
    @State private var selectedTable: DiagnosticsTable = .media // 当前表
    @State private var selectedRowDetail: DiagnosticsDetail? // 详情弹窗
    @State private var searchText = "" // 搜索
    @State private var mediaSortOrder: [KeyPathComparator<MediaItem>] = [KeyPathComparator(\.createdAt, order: .reverse)]
    @State private var albumSortOrder: [KeyPathComparator<Album>] = [KeyPathComparator(\.name, order: .forward)]
    @State private var ruleSortOrder: [KeyPathComparator<Rule>] = [KeyPathComparator(\.priority, order: .reverse)]
    @State private var historySortOrder: [KeyPathComparator<History>] = [KeyPathComparator(\.appliedAt, order: .reverse)]
    @State private var visibleMediaColumns = Set(MediaColumn.allCases)
    @State private var visibleAlbumColumns = Set(AlbumColumn.allCases)
    @State private var visibleRuleColumns = Set(RuleColumn.allCases)
    @State private var visibleHistoryColumns = Set(HistoryColumn.allCases)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GlassSection(title: "总览") {
                    HStack {
                        Text("当前版本")
                        Spacer()
                        Text("\(UpdateService.currentVersionString()) (\(UpdateService.currentBuildNumber()))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("素材总数")
                        Spacer()
                        Text("\(mediaItems.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("图片 / 视频")
                        Spacer()
                        Text("\(imageCount) / \(videoCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("相册 / 规则 / 历史")
                        Spacer()
                        Text("\(albums.count) / \(rules.count) / \(histories.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                GlassSection(title: "SwiftData 数据库") {
                    HStack {
                        Text("数据库路径")
                        Spacer()
                        Text(swiftDataStorePath ?? "未找到")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    if let sizeText {
                        HStack {
                            Text("文件大小")
                            Spacer()
                            Text(sizeText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let modifiedText {
                        HStack {
                            Text("最后修改")
                            Spacer()
                            Text(modifiedText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 8) {
                        Button("打开所在文件夹") { openSwiftDataFolder() }
                            .glassCapsuleBackground()
                        Button("打开数据库文件") { openSwiftDataFile() }
                            .glassCapsuleBackground()
                        Button("复制路径") { copySwiftDataPath() }
                            .glassCapsuleBackground()
                    }
                }

                GlassSection(title: "素材库健康") {
                    HStack {
                        Text("最近导入")
                        Spacer()
                        Text(latestImportText ?? "无")
                            .foregroundStyle(.secondary)
                    }
                    Button(isFixingMissing ? "修复中…" : "扫描并移除丢失文件记录") {
                        Task { await fixMissingFiles() }
                    }
                    .disabled(isFixingMissing)
                    .glassCapsuleBackground()
                    if let fixResultMessage {
                        Text(fixResultMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GlassSection(title: "SwiftData 数据内容") {
                    Picker("表", selection: $selectedTable) {
                        ForEach(DiagnosticsTable.allCases) { table in
                            Text(table.title).tag(table)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        TextField("搜索（支持文件名/路径/字段）", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                        Spacer()
                        columnMenu
                        Button("显示全部列") {
                            showAllColumns()
                        }
                        .glassCapsuleBackground()
                    }

                    ScrollView(.horizontal) {
                        dataTable
                            .frame(minHeight: 260)
                            .frame(minWidth: 1200)
                    }
                }

                GlassSection(title: "日志") {
                    LogsView(showsHeader: true, embedded: true)
                        .frame(minHeight: 360)
                }
            }
            .padding()
        }
        .navigationTitle("监控与诊断")
        .sheet(item: $selectedRowDetail) { detail in
            DiagnosticsDetailSheet(detail: detail.text)
        }
    }

    private var imageCount: Int {
        mediaItems.filter { $0.type == .image }.count
    }

    private var videoCount: Int {
        mediaItems.filter { $0.type == .video }.count
    }

    private var latestImportText: String? {
        guard let latest = mediaItems.first?.createdAt else { return nil }
        return dateFormatter.string(from: latest)
    }

    private var swiftDataStorePath: String? {
        swiftDataStoreURL?.path
    }

    private var swiftDataStoreURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        if let contents = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            if let store = contents.first(where: { $0.pathExtension == "store" }) {
                return store
            }
        }
        let fallback = appSupport.appendingPathComponent("default.store")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    private var sizeText: String? {
        guard let url = swiftDataStoreURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file)
    }

    private var modifiedText: String? {
        guard let url = swiftDataStoreURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return nil }
        return dateFormatter.string(from: date)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }

    private var dataTable: some View {
        Group {
            switch selectedTable {
            case .media:
                Table(filteredMediaItems.sorted(using: mediaSortOrder), sortOrder: $mediaSortOrder) {
                    if visibleMediaColumns.contains(.fileName) {
                        TableColumn("文件名") { item in
                            Text(item.fileURL.lastPathComponent)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleMediaColumns.contains(.type) {
                        TableColumn("类型") { item in
                            Text(item.type == .image ? "图片" : "视频")
                                .textSelection(.enabled)
                        }
                    }
                    if visibleMediaColumns.contains(.createdAt) {
                        TableColumn("创建时间") { item in
                            Text(dateFormatter.string(from: item.createdAt))
                                .textSelection(.enabled)
                        }
                    }
                    if visibleMediaColumns.contains(.path) {
                        TableColumn("路径") { item in
                            Text(item.fileURL.path)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleMediaColumns.contains(.detail) {
                        TableColumn("详情") { item in
                            let detail = mediaDetailText(item)
                            HStack(spacing: 8) {
                                Text(detail)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .textSelection(.enabled)
                                Button("查看") {
                                    selectedRowDetail = DiagnosticsDetail(text: detail)
                                }
                                .buttonStyle(.plain)
                            }
                            .contextMenu {
                                Button("复制详情") { copyText(detail) }
                                Button("复制路径") { copyText(item.fileURL.path) }
                                Button("复制文件名") { copyText(item.fileURL.lastPathComponent) }
                            }
                        }
                    }
                }
            case .albums:
                Table(filteredAlbums.sorted(using: albumSortOrder), sortOrder: $albumSortOrder) {
                    if visibleAlbumColumns.contains(.id) {
                        TableColumn("ID") { album in
                            Text(album.id.uuidString)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleAlbumColumns.contains(.name) {
                        TableColumn("名称") { album in
                            Text(album.name)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleAlbumColumns.contains(.count) {
                        TableColumn("素材数量") { album in
                            Text("\(album.items.count)")
                                .textSelection(.enabled)
                        }
                    }
                }
                .contextMenu {
                    if let first = filteredAlbums.first {
                        Button("复制名称") { copyText(first.name) }
                        Button("复制ID") { copyText(first.id.uuidString) }
                    }
                }
            case .rules:
                Table(filteredRules.sorted(using: ruleSortOrder), sortOrder: $ruleSortOrder) {
                    if visibleRuleColumns.contains(.name) {
                        TableColumn("名称") { rule in
                            Text(rule.name ?? "未命名")
                                .textSelection(.enabled)
                        }
                    }
                    if visibleRuleColumns.contains(.scope) {
                        TableColumn("作用范围") { rule in
                            Text(rule.scopeRaw)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleRuleColumns.contains(.priority) {
                        TableColumn("优先级") { rule in
                            Text("\(rule.priority)")
                                .textSelection(.enabled)
                        }
                    }
                    if visibleRuleColumns.contains(.enabled) {
                        TableColumn("启用") { rule in
                            Text(rule.enabled ? "是" : "否")
                                .textSelection(.enabled)
                        }
                    }
                    if visibleRuleColumns.contains(.detail) {
                        TableColumn("详情") { rule in
                            let detail = ruleDetailText(rule)
                            HStack(spacing: 8) {
                                Text(detail)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .textSelection(.enabled)
                                Button("查看") {
                                    selectedRowDetail = DiagnosticsDetail(text: detail)
                                }
                                .buttonStyle(.plain)
                            }
                            .contextMenu {
                                Button("复制详情") { copyText(detail) }
                                Button("复制名称") { copyText(rule.name ?? "未命名") }
                                Button("复制ID") { copyText(rule.id.uuidString) }
                            }
                        }
                    }
                }
            case .history:
                Table(filteredHistories.sorted(using: historySortOrder), sortOrder: $historySortOrder) {
                    if visibleHistoryColumns.contains(.id) {
                        TableColumn("ID") { history in
                            Text(history.id.uuidString)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleHistoryColumns.contains(.media) {
                        TableColumn("素材") { history in
                            Text(history.media?.fileURL.lastPathComponent ?? "-")
                                .textSelection(.enabled)
                        }
                    }
                    if visibleHistoryColumns.contains(.time) {
                        TableColumn("时间") { history in
                            Text(dateFormatter.string(from: history.appliedAt))
                                .textSelection(.enabled)
                        }
                    }
                    if visibleHistoryColumns.contains(.screen) {
                        TableColumn("屏幕") { history in
                            Text(history.screenID)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleHistoryColumns.contains(.result) {
                        TableColumn("结果") { history in
                            Text(history.result)
                                .textSelection(.enabled)
                        }
                    }
                    if visibleHistoryColumns.contains(.error) {
                        TableColumn("错误") { history in
                            Text(history.error ?? "-")
                                .textSelection(.enabled)
                        }
                    }
                    if visibleHistoryColumns.contains(.detail) {
                        TableColumn("详情") { history in
                            let detail = historyDetailText(history)
                            HStack(spacing: 8) {
                                Text(detail)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .textSelection(.enabled)
                                Button("查看") {
                                    selectedRowDetail = DiagnosticsDetail(text: detail)
                                }
                                .buttonStyle(.plain)
                            }
                            .contextMenu {
                                Button("复制详情") { copyText(detail) }
                                Button("复制ID") { copyText(history.id.uuidString) }
                            }
                        }
                    }
                }
            }
        }
    }

    private enum DiagnosticsTable: String, CaseIterable, Identifiable {
        case media
        case albums
        case rules
        case history

        var id: String { rawValue }
        var title: String {
            switch self {
            case .media: return "素材"
            case .albums: return "相册"
            case .rules: return "规则"
            case .history: return "历史"
            }
        }
    }

    private var columnMenu: some View {
        Menu("列") {
            switch selectedTable {
            case .media:
                ForEach(MediaColumn.allCases) { column in
                    Toggle(column.title, isOn: binding(for: column))
                }
            case .albums:
                ForEach(AlbumColumn.allCases) { column in
                    Toggle(column.title, isOn: binding(for: column))
                }
            case .rules:
                ForEach(RuleColumn.allCases) { column in
                    Toggle(column.title, isOn: binding(for: column))
                }
            case .history:
                ForEach(HistoryColumn.allCases) { column in
                    Toggle(column.title, isOn: binding(for: column))
                }
            }
        }
        .glassCapsuleBackground()
    }

    private func showAllColumns() {
        switch selectedTable {
        case .media:
            visibleMediaColumns = Set(MediaColumn.allCases)
        case .albums:
            visibleAlbumColumns = Set(AlbumColumn.allCases)
        case .rules:
            visibleRuleColumns = Set(RuleColumn.allCases)
        case .history:
            visibleHistoryColumns = Set(HistoryColumn.allCases)
        }
    }

    private func binding(for column: MediaColumn) -> Binding<Bool> {
        Binding(
            get: { visibleMediaColumns.contains(column) },
            set: { isOn in
                toggle(&visibleMediaColumns, column, isOn: isOn)
            }
        )
    }

    private func binding(for column: AlbumColumn) -> Binding<Bool> {
        Binding(
            get: { visibleAlbumColumns.contains(column) },
            set: { isOn in
                toggle(&visibleAlbumColumns, column, isOn: isOn)
            }
        )
    }

    private func binding(for column: RuleColumn) -> Binding<Bool> {
        Binding(
            get: { visibleRuleColumns.contains(column) },
            set: { isOn in
                toggle(&visibleRuleColumns, column, isOn: isOn)
            }
        )
    }

    private func binding(for column: HistoryColumn) -> Binding<Bool> {
        Binding(
            get: { visibleHistoryColumns.contains(column) },
            set: { isOn in
                toggle(&visibleHistoryColumns, column, isOn: isOn)
            }
        )
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T, isOn: Bool) {
        if isOn {
            set.insert(value)
        } else {
            set.remove(value)
        }
    }

    private var filteredMediaItems: [MediaItem] {
        if searchText.isEmpty { return mediaItems }
        return mediaItems.filter { item in
            let detail = mediaDetailText(item)
            return item.fileURL.lastPathComponent.localizedStandardContains(searchText)
                || item.fileURL.path.localizedStandardContains(searchText)
                || item.tags.localizedStandardContains(searchText)
                || detail.localizedStandardContains(searchText)
        }
    }

    private var filteredAlbums: [Album] {
        if searchText.isEmpty { return albums }
        return albums.filter { album in
            album.name.localizedStandardContains(searchText)
        }
    }

    private var filteredRules: [Rule] {
        if searchText.isEmpty { return rules }
        return rules.filter { rule in
            let detail = ruleDetailText(rule)
            return (rule.name ?? "").localizedStandardContains(searchText)
                || detail.localizedStandardContains(searchText)
        }
    }

    private var filteredHistories: [History] {
        if searchText.isEmpty { return histories }
        return histories.filter { history in
            let detail = historyDetailText(history)
            return detail.localizedStandardContains(searchText)
        }
    }

    private func mediaDetailText(_ item: MediaItem) -> String {
        let parts: [String] = [
            "ID: \(item.id.uuidString)",
            "TypeRaw: \(item.typeRaw)",
            "收藏: \(item.isFavorite ? "是" : "否")",
            "评分: \(item.rating)",
            "标签: \(item.tags.isEmpty ? "-" : item.tags)",
            "书签: \(item.bookmarkData == nil ? "无" : "有")",
            "宽: \(item.width.map { "\(Int($0))" } ?? "-")",
            "高: \(item.height.map { "\(Int($0))" } ?? "-")",
            "时长: \(item.duration.map { String(format: "%.1fs", $0) } ?? "-")",
            "帧率: \(item.frameRate.map { String(format: "%.2f", $0) } ?? "-")",
            "大小: \(item.sizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "-")",
            "最近使用: \(item.lastUsedAt.map { dateFormatter.string(from: $0) } ?? "-")"
        ]
        return parts.joined(separator: " | ")
    }

    private func ruleDetailText(_ rule: Rule) -> String {
        let parts: [String] = [
            "ID: \(rule.id.uuidString)",
            "屏幕: \(rule.screenID ?? "-")",
            "间隔: \(rule.intervalMinutes.map { "\($0) 分钟" } ?? "-")",
            "工作日: \(rule.weekdaysRaw.isEmpty ? "-" : rule.weekdaysRaw)",
            "开始: \(rule.startMinutes.map { "\($0)" } ?? "-")",
            "结束: \(rule.endMinutes.map { "\($0)" } ?? "-")",
            "随机策略: \(rule.randomStrategyRaw)",
            "图/视频比例: \(String(format: "%.2f", rule.mediaMixRatio))",
            "相册: \(rule.album?.name ?? "-")"
        ]
        return parts.joined(separator: " | ")
    }

    private func historyDetailText(_ history: History) -> String {
        let parts: [String] = [
            "ID: \(history.id.uuidString)",
            "素材: \(history.media?.fileURL.lastPathComponent ?? "-")",
            "时间: \(dateFormatter.string(from: history.appliedAt))",
            "屏幕: \(history.screenID)",
            "结果: \(history.result)",
            "错误: \(history.error ?? "-")"
        ]
        return parts.joined(separator: " | ")
    }

    private func openSwiftDataFolder() {
        guard let url = swiftDataStoreURL?.deletingLastPathComponent() else { return }
        NSWorkspace.shared.open(url)
    }

    private func openSwiftDataFile() {
        guard let url = swiftDataStoreURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func copySwiftDataPath() {
        guard let path = swiftDataStorePath else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }

    private func copyText(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    @MainActor
    private func fixMissingFiles() async {
        guard !isFixingMissing else { return }
        isFixingMissing = true
        defer { isFixingMissing = false }

        var removed = 0
        var checked = 0
        for item in mediaItems {
            checked += 1
            let exists = FileManager.default.fileExists(atPath: item.fileURL.path)
            if !exists {
                modelContext.delete(item)
                removed += 1
            }
        }
        try? modelContext.save()
        fixResultMessage = "已检查 \(checked) 条记录，移除丢失文件 \(removed) 条。"
        LogCenter.log("[诊断] 扫描丢失文件完成，移除 \(removed) 条 / 检查 \(checked) 条")
    }
}

private struct DiagnosticsDetailSheet: View {
    let detail: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("详情")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                Text(detail)
                    .textSelection(.enabled)
                    .font(.body)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320)
    }
}

private struct DiagnosticsDetail: Identifiable {
    let id = UUID()
    let text: String
}

private enum MediaColumn: String, CaseIterable, Identifiable {
    case fileName
    case type
    case createdAt
    case path
    case detail

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fileName: return "文件名"
        case .type: return "类型"
        case .createdAt: return "创建时间"
        case .path: return "路径"
        case .detail: return "详情"
        }
    }
}

private enum AlbumColumn: String, CaseIterable, Identifiable {
    case id
    case name
    case count

    var id: String { rawValue }
    var title: String {
        switch self {
        case .id: return "ID"
        case .name: return "名称"
        case .count: return "素材数量"
        }
    }
}

private enum RuleColumn: String, CaseIterable, Identifiable {
    case name
    case scope
    case priority
    case enabled
    case detail

    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: return "名称"
        case .scope: return "作用范围"
        case .priority: return "优先级"
        case .enabled: return "启用"
        case .detail: return "详情"
        }
    }
}

private enum HistoryColumn: String, CaseIterable, Identifiable {
    case id
    case media
    case time
    case screen
    case result
    case error
    case detail

    var id: String { rawValue }
    var title: String {
        switch self {
        case .id: return "ID"
        case .media: return "素材"
        case .time: return "时间"
        case .screen: return "屏幕"
        case .result: return "结果"
        case .error: return "错误"
        case .detail: return "详情"
        }
    }
}
