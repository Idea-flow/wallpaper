import SwiftUI // SwiftUI 界面
import UniformTypeIdentifiers // UTType

// LogsView：日志中心页面
struct LogsView: View { // 日志视图
    @State private var logCenter = LogCenter.shared // 日志中心
    @State private var searchText = "" // 搜索关键字
    @State private var selectedLevel: LogLevel? = nil // 过滤级别
    @State private var isExporting = false // 导出面板
    @State private var exportText = "" // 导出文本
    @State private var exportName = "wallpaper-logs" // 默认文件名

    var body: some View { // 主体
        VStack(spacing: 12) { // 垂直布局
            header // 顶部工具区
            logList // 日志列表
        }
        .padding() // 内边距
        .fileExporter( // 导出文件
            isPresented: $isExporting, // 是否显示
            document: TextDocument(text: exportText), // 文档
            contentType: .plainText, // 默认 txt
            defaultFilename: exportName // 默认名
        ) { result in
            switch result { // 处理结果
            case .success:
                LogCenter.log("[日志] 导出成功：\(exportName)") // 成功日志
            case .failure(let error):
                LogCenter.log("[日志] 导出失败：\(error.localizedDescription)", level: .error) // 失败日志
            }
        }
    }

    private var header: some View { // 顶部操作
        HStack(spacing: 12) { // 横向布局
            Text("日志") // 标题
                .font(.title2) // 标题字号
                .bold() // 加粗

            Spacer() // 占位

            Picker("级别", selection: $selectedLevel) { // 级别筛选
                Text("全部").tag(LogLevel?.none) // 全部
                ForEach(LogLevel.allCases) { level in // 遍历级别
                    Text(level.rawValue).tag(Optional(level)) // 选项
                }
            }
            .pickerStyle(.menu) // 菜单样式

            TextField("搜索日志", text: $searchText) // 搜索框
                .textFieldStyle(.roundedBorder) // 圆角输入框
                .frame(width: 200) // 固定宽度

            Menu("导出") { // 导出菜单
                Button("导出为 TXT") { // TXT
                    exportText = exportPlainText() // 文本
                    exportName = "wallpaper-logs.txt" // 文件名
                    isExporting = true // 打开导出
                }
                Button("导出为 Markdown") { // Markdown
                    exportText = exportMarkdown() // Markdown
                    exportName = "wallpaper-logs.md" // 文件名
                    isExporting = true // 打开导出
                }
            }

            Button("清空") { // 清空按钮
                logCenter.clear() // 清空日志
                LogCenter.log("[日志] 已清空日志", level: .info) // 记录日志
            }
        }
    }

    private var logList: some View { // 日志列表
        List(filteredEntries) { entry in // 列表
            VStack(alignment: .leading, spacing: 6) { // 垂直布局
                HStack(spacing: 8) { // 横向布局
                    Text(entry.level.rawValue) // 级别
                        .font(.caption) // 小字
                        .padding(.horizontal, 8) // 横向内边距
                        .padding(.vertical, 2) // 纵向内边距
                        .background(levelColor(entry.level).opacity(0.15)) // 颜色背景
                        .foregroundStyle(levelColor(entry.level)) // 级别颜色
                        .clipShape(.rect(cornerRadius: 6)) // 圆角

                    Text(formattedDate(entry.date)) // 时间
                        .font(.caption) // 小字
                        .foregroundStyle(.secondary) // 次级颜色
                }

                Text(entry.message) // 日志内容
                    .font(.body) // 正文字号
                    .textSelection(.enabled) // 可复制
            }
            .padding(.vertical, 6) // 行内边距
        }
        .listStyle(.inset) // 列表样式
        .overlay { // 无内容占位
            if filteredEntries.isEmpty { // 空列表
                ContentUnavailableView("暂无日志", systemImage: "doc.text.magnifyingglass") // 占位
            }
        }
    }

    private var filteredEntries: [LogEntry] { // 过滤日志
        logCenter.entries.filter { entry in // 过滤
            if let selectedLevel { // 级别过滤
                if entry.level != selectedLevel { return false } // 不匹配
            }
            if searchText.isEmpty { return true } // 无搜索
            return entry.message.localizedStandardContains(searchText) // 文本匹配
        }
    }

    private func levelColor(_ level: LogLevel) -> Color { // 级别颜色
        switch level { // 匹配
        case .info: return .blue // 信息
        case .warning: return .orange // 警告
        case .error: return .red // 错误
        }
    }

    private func formattedDate(_ date: Date) -> String { // 格式化时间
        let formatter = DateFormatter() // 格式化器
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // 时间格式
        return formatter.string(from: date) // 返回
    }

    private func exportPlainText() -> String { // 导出为 TXT
        filteredEntries.map { entry in // 逐条拼接
            "[\(formattedDate(entry.date))] [\(entry.level.rawValue)] \(entry.message)" // 文本格式
        }
        .joined(separator: "\n") // 换行
    }

    private func exportMarkdown() -> String { // 导出为 Markdown
        var lines: [String] = [] // 行集合
        lines.append("# wallpaper 日志") // 标题
        lines.append("") // 空行
        for entry in filteredEntries { // 遍历日志
            let line = "- \(formattedDate(entry.date)) `\(entry.level.rawValue)` \(entry.message)" // Markdown 行
            lines.append(line) // 添加行
        }
        return lines.joined(separator: "\n") // 合并
    }
}

// TextDocument：文本导出文档
struct TextDocument: FileDocument { // 文档类型
    static var readableContentTypes: [UTType] { [.plainText] } // 支持纯文本
    var text: String // 文本

    init(text: String) { // 初始化
        self.text = text // 保存文本
    }

    init(configuration: ReadConfiguration) throws { // 读取
        self.text = "" // 不需要读取
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { // 写出
        let data = Data(text.utf8) // 转为数据
        return .init(regularFileWithContents: data) // 返回文件
    }
}
