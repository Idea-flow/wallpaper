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
            RulesView() // 规则列表
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
                ContentUnavailableView("请选择规则", systemImage: "clock.arrow.circlepath") // 规则占位
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
struct ThumbnailView: View {
    let item: MediaItem // 素材

    var body: some View { // 视图
        ZStack { // 叠放
            if item.type == .image { // 图片类型
                let result = MediaAccessService.loadImageResult(for: item) // 读取结果
                if let image = result.image { // 读取成功
                    Image(nsImage: image) // 显示图片
                        .resizable() // 可拉伸
                        .scaledToFill() // 填充
                } else { // 读取失败
                    Rectangle() // 占位背景
                        .fill(.quaternary) // 次级颜色
                    VStack(spacing: 4) { // 垂直布局
                        Image(systemName: "photo") // 图标
                            .foregroundStyle(.secondary) // 次级颜色
                        Text(item.fileURL.lastPathComponent) // 文件名
                            .font(.caption2) // 小字号
                            .foregroundStyle(.secondary) // 次级颜色
                            .lineLimit(1) // 单行
                    }
                    .onAppear { // 进入时打印日志
                        if let reason = result.reason { // 有原因
                            NSLog("[预览-列表] \(reason)") // 日志
                        }
                    }
                }
            } else { // 非图片（视频或其他）
                Rectangle() // 占位背景
                    .fill(.quaternary) // 次级颜色
                Image(systemName: item.type == .video ? "film" : "photo") // 图标
                    .foregroundStyle(.secondary) // 次级颜色
            }
        }
    }
}

// MediaDetailView：素材详情与预览
struct MediaDetailView: View {
    @Bindable var item: MediaItem // 素材（可编辑）
    @Binding var fitMode: FitMode // 适配模式
    @Binding var selectedScreenID: String // 选择屏幕
    @Binding var isSettingWallpaper: Bool // 设置中状态
    let onApply: () -> Void // 设置壁纸回调

    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 16) { // 垂直布局
            if item.type == .image || item.type == .video { // 图片/视频显示屏幕与模式选择
                screenPicker // 屏幕选择
                if item.type == .image { // 仅图片显示适配模式
                    fitModePicker // 适配模式选择器
                }
            }
            preview // 预览区域
            HStack { // 按钮区域
                Button {
                    onApply() // 点击设置壁纸
                } label: {
                    Label(isSettingWallpaper ? "设置中..." : "设为壁纸", systemImage: "sparkles") // 按钮文案
                }
                .glassActionButtonStyle() // 玻璃样式
                .disabled(isSettingWallpaper) // 设置中禁用

                Spacer() // 占位

                if item.isFavorite { // 已收藏
                    Label("已收藏", systemImage: "heart.fill") // 收藏标识
                        .foregroundStyle(.red) // 红色
                }
            }

            metadata // 元信息
            editPanel // 编辑区域
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // 布局
    }

    private var preview: some View { // 预览区域
        return Group {
            if item.type == .image { // 图片预览
                let result = MediaAccessService.loadImageResult(for: item) // 读取结果
                if let image = result.image { // 有图片
                    imagePreview(image) // 按模式预览
                        .clipShape(.rect(cornerRadius: 12)) // 圆角
                } else { // 读取失败
                    VStack(spacing: 8) { // 垂直布局
                        Image(systemName: "photo") // 图标
                            .font(.system(size: 40)) // 图标大小
                            .foregroundStyle(.secondary) // 次级颜色
                        Text("无法预览") // 文案
                            .font(.headline) // 标题
                        Text(item.fileURL.lastPathComponent) // 文件名
                            .font(.subheadline) // 副标题
                            .foregroundStyle(.secondary) // 次级颜色
                            .lineLimit(2) // 最多两行
                            .multilineTextAlignment(.center) // 居中
                            .padding(.horizontal, 16) // 左右内边距
                        if let reason = result.reason { // 有原因
                            Text(reason) // 原因说明
                                .font(.caption) // 小字
                                .foregroundStyle(.secondary) // 次级颜色
                                .multilineTextAlignment(.center) // 居中
                                .padding(.horizontal, 16) // 左右内边距
                                .lineLimit(3) // 最多三行
                        }
                    }
                    .onAppear { // 进入时打印日志
                        if let reason = result.reason { // 有原因
                            NSLog("[预览-详情] \(reason)") // 日志
                        }
                    }
                }
            } else if item.type == .video { // 视频预览
                VideoPlayerView(item: item, isMuted: true) // 视频预览
                    .id(item.id) // 强制在切换时刷新
                    .clipShape(.rect(cornerRadius: 12)) // 圆角
            } else {
                ContentUnavailableView("无法预览", systemImage: "photo") // 预览失败
            }
        }
        .frame(maxWidth: .infinity) // 预览区域宽度
        .frame(height: 360) // 固定高度，避免影响全局布局
        .glassSurface(cornerRadius: 12) // 玻璃容器
        .clipped() // 裁剪溢出，避免撑高页面
    }

    private var fitModePicker: some View { // 适配模式选择器
        HStack(spacing: 12) { // 横向布局
            Text("适配模式") // 标题
                .foregroundStyle(.secondary) // 次级颜色
            Picker("", selection: $fitMode) { // 选择器
                Text("填充").tag(FitMode.fill) // 填充
                Text("适应").tag(FitMode.fit) // 适应
                Text("拉伸").tag(FitMode.stretch) // 拉伸
                Text("居中").tag(FitMode.center) // 居中
                Text("平铺").tag(FitMode.tile) // 平铺
            }
            .pickerStyle(.segmented) // 分段样式
        }
    }

    private var screenPicker: some View { // 屏幕选择器
        let options = ScreenHelper.screenOptions() // 屏幕选项
        return HStack(spacing: 12) { // 横向布局
            Text("应用屏幕") // 标题
                .foregroundStyle(.secondary) // 次级颜色
            Picker("", selection: $selectedScreenID) { // 选择器
                Text("所有屏幕").tag("all") // 默认全部
                ForEach(options) { option in // 遍历屏幕
                    Text(option.title).tag(option.id) // 屏幕名称
                }
            }
            .pickerStyle(.segmented) // 分段样式
        }
    }

    private var metadata: some View { // 元信息
        VStack(alignment: .leading, spacing: 6) { // 垂直布局
            Text(item.fileURL.lastPathComponent) // 文件名
                .font(.headline) // 标题样式

            HStack(spacing: 12) { // 横向排列
                if let width = item.width, let height = item.height { // 有尺寸
                    Text("\(Int(width)) x \(Int(height))") // 显示尺寸
                }
                if let duration = item.duration { // 有时长
                    Text("\(formatDuration(duration))") // 显示时长
                }
                if let sizeBytes = item.sizeBytes { // 有大小
                    Text(byteCount(sizeBytes)) // 显示大小
                }
            }
            .foregroundStyle(.secondary) // 次级颜色
        }
    }

    private var editPanel: some View { // 编辑区域
        VStack(alignment: .leading, spacing: 8) { // 垂直布局
            Toggle("收藏", isOn: $item.isFavorite) // 收藏开关
            Stepper("评分：\(item.rating)", value: $item.rating, in: 0...5) // 评分
            TextField("标签（逗号分隔）", text: $item.tags) // 标签输入
                .textFieldStyle(.roundedBorder) // 输入框样式
        }
    }

    private func formatDuration(_ duration: Double) -> String { // 格式化时长
        let total = Int(duration) // 总秒数
        let minutes = total / 60 // 分钟
        let seconds = total % 60 // 秒
        return String(format: "%d:%02d", minutes, seconds) // 返回字符串
    }

    private func byteCount(_ bytes: Int64) -> String { // 格式化文件大小
        let formatter = ByteCountFormatter() // 创建格式化器
        formatter.allowedUnits = [.useMB, .useGB] // 只显示 MB/GB
        formatter.countStyle = .file // 文件样式
        return formatter.string(fromByteCount: bytes) // 返回字符串
    }

    @ViewBuilder
    private func imagePreview(_ image: NSImage) -> some View { // 图片预览
        switch fitMode { // 根据模式显示
        case .fill:
            Image(nsImage: image) // 图片
                .resizable() // 可拉伸
                .scaledToFill() // 填充
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 填满
                .clipped() // 裁剪
        case .fit:
            Image(nsImage: image) // 图片
                .resizable() // 可拉伸
                .scaledToFit() // 适应
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 填满
        case .stretch:
            Image(nsImage: image) // 图片
                .resizable() // 可拉伸
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 填满
                .clipped() // 裁剪
        case .center:
            Image(nsImage: image) // 图片
                .resizable() // 可拉伸
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // 居中
                .clipped() // 裁剪
        case .tile:
            TiledImageView(image: image) // 原生平铺
                .clipped() // 裁剪溢出
        }
    }
}

#Preview { // 预览
    ContentView() // 预览内容
        .modelContainer(for: MediaItem.self, inMemory: true) // 使用内存模型
}

// ScreenOption：屏幕选项
struct ScreenOption: Identifiable { // 可识别
    let id: String // 屏幕 ID
    let title: String // 显示名称
}

// ScreenHelper：屏幕相关工具
struct ScreenHelper { // 工具结构
    // screenOptions：生成屏幕选项
    static func screenOptions() -> [ScreenOption] { // 返回屏幕列表
        NSScreen.screens.map { screen in // 遍历屏幕
            let id = screenIdentifier(screen) // 屏幕 ID
            let title = "\(screen.localizedName) · \(id)" // 显示名称
            return ScreenOption(id: id, title: title) // 返回选项
        }
    }

    // screenByID：通过 ID 找到屏幕
    static func screenByID(_ id: String) -> NSScreen? { // 通过 ID 查找
        NSScreen.screens.first { screenIdentifier($0) == id } // 匹配 ID
    }

    // screenIdentifier：获取屏幕唯一 ID
    static func screenIdentifier(_ screen: NSScreen) -> String { // 屏幕 ID
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber { // 读取编号
            return number.stringValue // 返回编号
        }
        return screen.localizedName // 回退到名称
    }
}

// View 扩展：封装 Liquid Glass 样式
extension View {
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat) -> some View { // 玻璃容器
        if #available(macOS 26, *) { // macOS 26+ 使用玻璃
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius)) // 玻璃效果
        } else { // 低版本回退
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius)) // 材质背景
        }
    }

    @ViewBuilder
    func glassActionButtonStyle() -> some View { // 玻璃按钮样式
        if #available(macOS 26, *) { // macOS 26+
            self.buttonStyle(.glassProminent) // 玻璃按钮
        } else { // 低版本回退
            self.buttonStyle(.borderedProminent) // 默认按钮
        }
    }
}

// TiledImageView：使用 AppKit 的 patternImage 做原生平铺
struct TiledImageView: NSViewRepresentable {
    let image: NSImage // 平铺图片

    func makeNSView(context: Context) -> NSView { // 创建视图
        let view = NSView() // 创建 NSView
        view.wantsLayer = true // 启用图层
        view.layer?.backgroundColor = NSColor(patternImage: image).cgColor // 平铺背景
        return view // 返回视图
    }

    func updateNSView(_ nsView: NSView, context: Context) { // 更新视图
        nsView.layer?.backgroundColor = NSColor(patternImage: image).cgColor // 更新平铺
    }
}
