import AppKit // 使用 NSImage
import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据
import UniformTypeIdentifiers // 文件类型识别

// ContentView：主界面，包含侧栏、列表和详情预览
struct ContentView: View {
    // SidebarSection：侧栏分类
    enum SidebarSection: String, CaseIterable, Identifiable {
        case library = "素材库" // 素材库
        case albums = "相册" // 相册
        case rules = "规则" // 规则
        case settings = "设置" // 设置

        var id: String { rawValue } // 用字符串作为唯一标识
        var systemImage: String { // 侧栏图标
            switch self { // 根据分类返回图标
            case .library: return "photo.on.rectangle" // 素材库图标
            case .albums: return "rectangle.stack" // 相册图标
            case .rules: return "clock.arrow.circlepath" // 规则图标
            case .settings: return "gearshape" // 设置图标
            }
        }
    }

    @Environment(\.modelContext) private var modelContext // SwiftData 上下文
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var items: [MediaItem] // 素材列表

    @State private var selectionIDs: Set<UUID> = [] // 选中素材的 ID 集合
    private var selectedItem: MediaItem? { // 当前单选素材
        guard selectionIDs.count == 1, let id = selectionIDs.first else { return nil } // 仅单选
        return items.first { $0.id == id } // 查找素材
    }
    @Query(sort: \Album.name, order: .forward) private var albums: [Album] // 相册列表
    @State private var selectedAlbumID: UUID? // 选中相册 ID
    private var selectedAlbum: Album? { albums.first { $0.id == selectedAlbumID } } // 当前相册
    @Query(sort: \Rule.priority, order: .reverse) private var rules: [Rule] // 规则列表
    @State private var selectedRuleID: UUID? // 选中规则 ID
    private var selectedRule: Rule? { rules.first { $0.id == selectedRuleID } } // 当前规则
    @State private var sidebarSelection: SidebarSection = .library // 当前侧栏选择
    @State private var columnVisibility: NavigationSplitViewVisibility = .all // 列显示
    @State private var showingImporter = false // 是否展示导入弹窗
    @State private var alertMessage: String? // 提示消息
    @State private var isSettingWallpaper = false // 是否在设置壁纸
    @State private var selectedFitMode: FitMode = .fill // 预览/设置适配模式
    @State private var selectedScreenID: String = "all" // 选择屏幕（all 表示全部）
    @State private var searchText = "" // 搜索文本
    @State private var filterType: MediaType? = nil // 类型筛选
    @State private var showFavoritesOnly = false // 仅收藏

    var body: some View { // 主界面
        NavigationSplitView(columnVisibility: $columnVisibility) { // 三栏布局
            List(SidebarSection.allCases, selection: $sidebarSelection) { section in // 侧栏列表
                Label(section.rawValue, systemImage: section.systemImage) // 侧栏行
                    .tag(section) // 绑定选择
                    .contentShape(Rectangle()) // 扩大可点击区域
            }
            .listStyle(.sidebar) // 侧栏样式
            .navigationSplitViewColumnWidth(min: 180, ideal: 220) // 侧栏宽度
        } content: { // 中间栏内容
            contentColumn // 内容列
        } detail: { // 右侧详情
            detailColumn // 详情列
        }
        .onAppear { // 初始化列显示
            updateColumnVisibility(for: sidebarSelection) // 更新列显示
        }
        .onChange(of: sidebarSelection) { newValue in // 监听切换
            updateColumnVisibility(for: newValue) // 更新列显示
        }
        .fileImporter( // 导入文件弹窗
            isPresented: $showingImporter, // 是否显示
            allowedContentTypes: [.image, .movie], // 允许图片和视频
            allowsMultipleSelection: true // 允许多选
        ) { result in
            handleImport(result) // 处理导入结果
        }
        .alert("", isPresented: Binding( // 弹窗提示
            get: { alertMessage != nil }, // 是否显示
            set: { _ in alertMessage = nil } // 关闭时清空
        )) {
            Button("好") { alertMessage = nil } // 确认按钮
        } message: {
            Text(alertMessage ?? "") // 显示提示内容
        }
    }

    private func updateColumnVisibility(for section: SidebarSection) { // 更新列显示
        switch section { // 根据模块
        case .settings:
            columnVisibility = .detailOnly // 显示侧栏 + 中间列
        default:
            columnVisibility = .all // 显示三栏
        }
    }

    @ViewBuilder
    private var contentColumn: some View { // 中间栏内容
        switch sidebarSelection { // 根据侧栏切换
        case .library:
            LibraryView( // 素材库视图
                selectionIDs: $selectionIDs, // 选中绑定
                searchText: $searchText, // 搜索绑定
                filterType: $filterType, // 类型绑定
                showFavoritesOnly: $showFavoritesOnly // 收藏绑定
            ) { // 导入回调
                showingImporter = true // 打开导入
            }
        case .albums:
            AlbumsView(selectedAlbumID: $selectedAlbumID) // 相册列表
        case .rules:
            RulesView(selectedRuleID: $selectedRuleID) // 规则列表
        case .settings:
            SettingsView() // 设置放在中间列
        }
    }

    @ViewBuilder
    private var detailColumn: some View { // 详情列
        detailView // 详情视图
    }

    private var detailView: some View { // 详情区域
        Group {
            switch sidebarSelection { // 按模块显示详情
            case .library:
                if let item = selectedItem { // 有选中素材（单选）
                    MediaDetailView( // 详情视图
                        item: item, // 素材
                        fitMode: $selectedFitMode, // 适配模式绑定
                        selectedScreenID: $selectedScreenID, // 选择屏幕绑定
                        isSettingWallpaper: $isSettingWallpaper // 设置状态绑定
                    ) {
                        applyWallpaper(for: item, fitMode: selectedFitMode, screenID: selectedScreenID) // 执行设置壁纸
                    }
                } else if !selectionIDs.isEmpty { // 多选时提示
                    ContentUnavailableView("已选择 \(selectionIDs.count) 项，可在中间栏进行批量操作", systemImage: "checkmark.circle") // 多选提示
                } else {
                    ContentUnavailableView("请选择一张图片", systemImage: "photo") // 无选择占位
                }
            case .albums:
                if let album = selectedAlbum { // 有选中相册
                    AlbumDetailView(album: album) // 相册详情
                } else {
                    ContentUnavailableView("请选择相册", systemImage: "rectangle.stack") // 无选择占位
                }
            case .rules:
                if let rule = selectedRule { // 有选中规则
                    RuleDetailView(rule: rule, albums: albums) // 规则详情
                } else {
                    ContentUnavailableView("请选择规则", systemImage: "clock.arrow.circlepath") // 规则占位
                }
            case .settings:
                EmptyView() // 设置不在详情列显示
            }
        }
        .padding() // 内边距
    }

    private func handleImport(_ result: Result<[URL], Error>) { // 处理导入
        switch result { // 根据结果处理
        case .success(let urls):
            print("[导入] 选择了 \(urls.count) 个文件") // 关键步骤日志
            for url in urls { // 遍历导入
                importOne(url) // 导入单个
            }
        case .failure(let error):
            alertMessage = "导入失败：\(error.localizedDescription)" // 提示失败
        }
    }

    private func importOne(_ url: URL) { // 导入单个文件
        do {
            let result = try MediaImportService.importMedia(from: url) // 调用导入服务
            modelContext.insert(result.item) // 写入数据库
        } catch {
            alertMessage = "导入失败：\(url.lastPathComponent)" // 提示失败
        }
    }

    private func applyWallpaper(for item: MediaItem, fitMode: FitMode, screenID: String) { // 设置壁纸
        isSettingWallpaper = true // 标记开始
        defer { isSettingWallpaper = false } // 结束时恢复

        do {
            if item.type == .image { // 图片壁纸
                VideoWallpaperService.shared.stopAll() // 切换到图片时停止视频壁纸
                let targetScreen = screenID == "all" ? nil : ScreenHelper.screenByID(screenID) // 目标屏幕
                if screenID != "all" && targetScreen == nil { // 未找到目标屏幕
                    NSLog("[壁纸] 未找到目标屏幕，screenID=\(screenID)") // 日志
                }
                try MediaAccessService.withResolvedURL(for: item) { url in // 使用安全路径
                    try WallpaperService.applyImage(url: url, to: targetScreen, fitMode: fitMode) // 设置壁纸
                }
                alertMessage = screenID == "all" ? "已应用到所有屏幕。" : "已应用到指定屏幕。" // 提示成功
            } else if item.type == .video { // 视频壁纸
                let targetScreenID = screenID == "all" ? nil : screenID // 目标屏幕 ID
                try VideoWallpaperService.shared.applyVideo(item: item, fitMode: fitMode, screenID: targetScreenID) // 启动视频壁纸
                alertMessage = screenID == "all" ? "视频壁纸已启动（所有屏幕）。" : "视频壁纸已启动（指定屏幕）。" // 提示成功
            } else {
                try WallpaperService.applyVideoPlaceholder() // 其他类型占位
            }
        } catch {
            alertMessage = item.type == .video
                ? "视频壁纸设置失败：\(error.localizedDescription)" // 视频失败
                : "设置壁纸失败：\(error.localizedDescription)" // 图片失败
        }
    }
}

// MediaRow：素材列表行
struct MediaRow: View {
    let item: MediaItem // 素材

    var body: some View { // 行布局
        HStack(spacing: 12) { // 横向布局
            ThumbnailView(item: item) // 缩略图
                .frame(width: 48, height: 36) // 尺寸
                .clipShape(.rect(cornerRadius: 6)) // 圆角

            VStack(alignment: .leading, spacing: 4) { // 垂直布局
                Text(item.fileURL.lastPathComponent) // 文件名
                    .lineLimit(1) // 单行
                Text(detailText) // 详情文字
                    .font(.caption) // 小字
                    .foregroundStyle(.secondary) // 次要颜色
            }
        }
        .padding(.vertical, 4) // 上下内边距
    }

    private var detailText: String { // 详情文字
        switch item.type { // 按类型显示
        case .image:
            let width = item.width.map { Int($0) } // 宽度
            let height = item.height.map { Int($0) } // 高度
            if let width, let height { // 同时存在
                return "图片 · \(width)x\(height)" // 展示尺寸
            }
            return "图片" // 无尺寸
        case .video:
            if let duration = item.duration { // 有时长
                return "视频 · \(formatDuration(duration))" // 展示时长
            }
            return "视频" // 无时长
        }
    }

    private func formatDuration(_ duration: Double) -> String { // 格式化时间
        let total = Int(duration) // 总秒数
        let minutes = total / 60 // 分钟
        let seconds = total % 60 // 秒
        return String(format: "%d:%02d", minutes, seconds) // 返回字符串
    }
}

// ThumbnailView：素材缩略图
// ThumbnailView 移到 MediaComponents.swift

#Preview { // 预览
    ContentView() // 预览内容
        .modelContainer(for: MediaItem.self, inMemory: true) // 使用内存模型
}

// View 扩展：封装 Liquid Glass 样式
extension View {
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = 16) -> some View { // 玻璃容器
        if #available(macOS 26, *) { // Liquid Glass
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius)) // 原生玻璃
        } else {
            self.background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial) // 磨砂背景
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5) // 柔和阴影
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5) // 精致描边
            }
        }
    }

    @ViewBuilder
    func glassActionButtonStyle() -> some View { // 玻璃按钮样式
        if #available(macOS 26, *) { // Liquid Glass
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(GlassButtonStyle())
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(configuration.isPressed ? .thickMaterial : .regularMaterial)
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MediaCard 移到 MediaComponents.swift

// TiledImageView 移到 MediaComponents.swift
