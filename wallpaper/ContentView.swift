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

    @State private var selectionID: UUID? // 选中素材的 ID
    private var selectedItem: MediaItem? { items.first { $0.id == selectionID } } // 通过 ID 找到素材
    @State private var sidebarSelection: SidebarSection = .library // 当前侧栏选择
    @State private var showingImporter = false // 是否展示导入弹窗
    @State private var alertMessage: String? // 提示消息
    @State private var isSettingWallpaper = false // 是否在设置壁纸
    @State private var selectedFitMode: FitMode = .fill // 预览/设置适配模式

    var body: some View { // 主界面
        NavigationSplitView { // 三栏布局
            List(SidebarSection.allCases, selection: $sidebarSelection) { section in // 侧栏列表
                Label(section.rawValue, systemImage: section.systemImage) // 侧栏行
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220) // 侧栏宽度
        } content: { // 中间栏内容
            switch sidebarSelection { // 根据侧栏切换
            case .library:
                libraryList // 素材库
            case .albums:
                placeholderView(title: "Albums", subtitle: "Create collections for different moods.") // 占位
            case .rules:
                placeholderView(title: "Rules", subtitle: "Schedule and automation live here.") // 占位
            case .settings:
                placeholderView(title: "Settings", subtitle: "System integration and preferences.") // 占位
            }
        } detail: { // 右侧详情
            detailView // 详情视图
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

    private var libraryList: some View { // 素材库列表
        List(selection: $selectionID) { // 列表与选择绑定
            ForEach(items) { item in // 遍历素材
                MediaRow(item: item) // 列表行
                    .tag(item.id) // 用 ID 标记
            }
            .onDelete(perform: deleteItems) // 支持删除
        }
        .toolbar { // 工具栏
            Button {
                showingImporter = true // 打开导入弹窗
            } label: {
                Label("导入素材", systemImage: "plus") // 导入按钮
            }
        }
    }

    private var detailView: some View { // 详情区域
        Group {
            if let item = selectedItem { // 有选中素材
                MediaDetailView( // 详情视图
                    item: item, // 素材
                    fitMode: $selectedFitMode, // 适配模式绑定
                    isSettingWallpaper: $isSettingWallpaper // 设置状态绑定
                ) {
                    applyWallpaper(for: item, fitMode: selectedFitMode) // 执行设置壁纸
                }
            } else {
                ContentUnavailableView("请选择一张图片", systemImage: "photo") // 无选择占位
            }
        }
        .padding() // 内边距
    }

    private func placeholderView(title: String, subtitle: String) -> some View { // 占位视图
        VStack(spacing: 12) { // 垂直布局
            Text(title) // 标题
                .font(.title) // 标题字号
            Text(subtitle) // 副标题
                .foregroundStyle(.secondary) // 次要颜色
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 占满空间
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

    private func deleteItems(offsets: IndexSet) { // 删除素材
        for index in offsets { // 遍历删除索引
            modelContext.delete(items[index]) // 删除对象
        }
    }

    private func applyWallpaper(for item: MediaItem, fitMode: FitMode) { // 设置壁纸
        isSettingWallpaper = true // 标记开始
        defer { isSettingWallpaper = false } // 结束时恢复

        do {
            if item.type == .image { // 图片壁纸
                try MediaAccessService.withResolvedURL(for: item) { url in // 使用安全路径
                    try WallpaperService.applyImage(url: url, to: nil, fitMode: fitMode) // 设置壁纸
                }
                alertMessage = "已应用到所有屏幕。" // 提示成功
            } else if item.type == .video { // 视频壁纸
                try VideoWallpaperService.shared.applyVideo(item: item, fitMode: fitMode) // 启动视频壁纸
                alertMessage = "视频壁纸已启动。" // 提示成功
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
        let result = MediaAccessService.loadImageResult(for: item) // 读取结果
        ZStack { // 叠放
            if item.type == .image { // 图片类型
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
    let item: MediaItem // 素材
    @Binding var fitMode: FitMode // 适配模式
    @Binding var isSettingWallpaper: Bool // 设置中状态
    let onApply: () -> Void // 设置壁纸回调

    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 16) { // 垂直布局
            if item.type == .image { // 仅图片显示模式选择
                fitModePicker // 适配模式选择器
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // 布局
    }

    private var preview: some View { // 预览区域
        let result = MediaAccessService.loadImageResult(for: item) // 读取结果
        return Group {
            if item.type == .image { // 图片预览
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
                    .clipShape(.rect(cornerRadius: 12)) // 圆角
            } else {
                ContentUnavailableView("无法预览", systemImage: "photo") // 预览失败
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260) // 预览区域高度
        .glassSurface(cornerRadius: 12) // 玻璃容器
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
        case .stretch:
            Image(nsImage: image) // 图片
                .resizable() // 可拉伸
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 填满
                .clipped() // 裁剪
        case .center:
            Image(nsImage: image) // 图片
                .resizable() // 可拉伸
                .scaledToFit() // 适应
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // 居中
        case .tile:
            GeometryReader { proxy in // 获取尺寸
                let tileSize = CGSize(width: min(200, proxy.size.width / 3), height: min(200, proxy.size.height / 3)) // 平铺尺寸
                let columns = max(Int(proxy.size.width / tileSize.width), 1) // 列数
                let rows = max(Int(proxy.size.height / tileSize.height), 1) // 行数
                let imageView = Image(nsImage: image) // 图片
                    .resizable() // 可拉伸
                    .scaledToFill() // 填充
                    .frame(width: tileSize.width, height: tileSize.height) // 单元尺寸
                    .clipped() // 裁剪
                VStack(spacing: 0) { // 垂直平铺
                    ForEach(0..<rows, id: \.self) { _ in // 行
                        HStack(spacing: 0) { // 行内平铺
                            ForEach(0..<columns, id: \.self) { _ in // 列
                                imageView // 单元图片
                            }
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height) // 填满区域
                .clipped() // 裁剪溢出
            }
            .clipped() // 裁剪溢出
        }
    }
}

#Preview { // 预览
    ContentView() // 预览内容
        .modelContainer(for: MediaItem.self, inMemory: true) // 使用内存模型
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
