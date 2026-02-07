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

                    dataTable
                        .frame(minHeight: 260)
                }

                GlassSection(title: "日志") {
                    LogsView(showsHeader: true, embedded: true)
                        .frame(minHeight: 360)
                }
            }
            .padding()
        }
        .navigationTitle("监控与诊断")
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
                Table(mediaItems) {
                    TableColumn("文件名") { item in
                        Text(item.fileURL.lastPathComponent)
                    }
                    TableColumn("类型") { item in
                        Text(item.type == .image ? "图片" : "视频")
                    }
                    TableColumn("大小") { item in
                        Text(item.sizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "-")
                    }
                    TableColumn("创建时间") { item in
                        Text(dateFormatter.string(from: item.createdAt))
                    }
                }
            case .albums:
                Table(albums) {
                    TableColumn("名称") { album in
                        Text(album.name)
                    }
                    TableColumn("素材数量") { album in
                        Text("\(album.items.count)")
                    }
                }
            case .rules:
                Table(rules) {
                    TableColumn("名称") { rule in
                        Text(rule.name ?? "未命名")
                    }
                    TableColumn("作用范围") { rule in
                        Text(rule.scopeRaw)
                    }
                    TableColumn("优先级") { rule in
                        Text("\(rule.priority)")
                    }
                    TableColumn("启用") { rule in
                        Text(rule.enabled ? "是" : "否")
                    }
                }
            case .history:
                Table(histories) {
                    TableColumn("时间") { history in
                        Text(dateFormatter.string(from: history.appliedAt))
                    }
                    TableColumn("屏幕") { history in
                        Text(history.screenID)
                    }
                    TableColumn("结果") { history in
                        Text(history.result)
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
