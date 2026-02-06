import AppKit // NSOpenPanel
import UniformTypeIdentifiers // UTType
import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// MediaDetailView：素材详情与预览（可复用）
struct MediaDetailView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Bindable var item: MediaItem // 素材（可编辑）
    @Binding var fitMode: FitMode // 适配模式
    @Binding var selectedScreenID: String // 选择屏幕
    @Binding var isSettingWallpaper: Bool // 设置中状态
    let onApply: () -> Void // 设置壁纸回调

    var body: some View { // 主体
        ScrollView { // 支持更多内容
            VStack(alignment: .leading, spacing: 20) { // 垂直布局
                headerSection // 标题区
                preview // 预览区域
                controlSection // 屏幕/适配控制
                infoSection // 元信息
                editSection // 编辑区
            }
            .frame(maxWidth: .infinity, alignment: .leading) // 布局
            .padding(20) // 统一内边距
        }
        .scrollIndicators(.hidden) // 隐藏滚动条
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
                            if isPermissionIssue(reason) { // 权限问题
                                Button("重新授权文件") { // 重新授权
                                    reselectFile() // 重新选择
                                }
                            }
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
        .frame(height: 360) // 固定高度
        .glassSurface(cornerRadius: 12) // 玻璃容器
        .clipped() // 裁剪溢出
    }

    private var headerSection: some View { // 标题区
        VStack(alignment: .leading, spacing: 8) { // 垂直布局
            HStack(alignment: .top, spacing: 12) { // 标题与操作
                VStack(alignment: .leading, spacing: 6) { // 标题内容
                    Text(item.fileURL.lastPathComponent) // 文件名
                        .font(.title2) // 标题字号
                        .bold() // 加粗
                        .lineLimit(1) // 单行
                        .truncationMode(.middle) // 中间省略
                    HStack(spacing: 10) { // 状态信息
                        Label(typeText, systemImage: typeIcon) // 类型
                            .font(.subheadline) // 字号
                            .foregroundStyle(.secondary) // 次级色
                        Text(item.createdAt, format: .dateTime.year().month().day()) // 创建时间
                            .font(.subheadline) // 字号
                            .foregroundStyle(.secondary) // 次级色
                        if item.isFavorite { // 收藏
                            Label("已收藏", systemImage: "heart.fill") // 收藏标识
                                .font(.subheadline) // 字号
                                .foregroundStyle(.red) // 红色
                        }
                    }
                }
                Spacer() // 占位
                Button {
                    onApply() // 点击设置壁纸
                } label: {
                    Label(isSettingWallpaper ? "设置中..." : "设为壁纸", systemImage: "sparkles") // 文案
                }
                .glassActionButtonStyle() // 玻璃样式
                .disabled(isSettingWallpaper) // 设置中禁用
            }
        }
    }

    private var controlSection: some View { // 屏幕与适配控制
        VStack(alignment: .leading, spacing: 12) { // 垂直布局
            if item.type == .image || item.type == .video { // 图片/视频显示屏幕选择
                screenPicker // 屏幕选择
            }
            if item.type == .image { // 仅图片显示适配模式
                fitModePicker // 适配模式选择器
            }
        }
        .padding(12) // 内边距
        .glassSurface(cornerRadius: 14) // 玻璃容器
    }

    private var infoSection: some View { // 元信息
        VStack(alignment: .leading, spacing: 10) { // 垂直布局
            Text("信息") // 标题
                .font(.headline) // 标题字号
            VStack(spacing: 8) { // 信息列表
                infoRow(title: "分辨率", value: resolutionText)
                infoRow(title: "时长", value: durationText)
                infoRow(title: "大小", value: sizeText)
                infoRow(title: "帧率", value: frameRateText)
                infoRow(title: "最近使用", value: lastUsedText)
            }
            .font(.subheadline) // 字号
        }
        .padding(12) // 内边距
        .glassSurface(cornerRadius: 14) // 玻璃容器
    }

    private var editSection: some View { // 编辑区域
        VStack(alignment: .leading, spacing: 10) { // 垂直布局
            Text("编辑") // 标题
                .font(.headline) // 标题字号
            Toggle("收藏", isOn: $item.isFavorite) // 收藏开关
            LabeledContent("评分") { // 评分
                Stepper(value: $item.rating, in: 0...5) { // 步进器
                    Text("\(item.rating)") // 当前评分
                }
                .frame(maxWidth: 140, alignment: .leading) // 控件宽度
            }
            LabeledContent("标签") { // 标签
                TextField("逗号分隔", text: $item.tags) // 标签输入
                    .textFieldStyle(.roundedBorder) // 输入框样式
                    .frame(maxWidth: 240) // 控件宽度
            }
            if item.type == .video { // 视频权限按钮
                Button("重新授权视频文件") { // 重新授权
                    reselectFile() // 重新选择
                }
            }
        }
        .padding(12) // 内边距
        .glassSurface(cornerRadius: 14) // 玻璃容器
    }

    private var fitModePicker: some View { // 适配模式选择器
        VStack(alignment: .leading, spacing: 8) { // 垂直布局
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

    @ViewBuilder
    private var screenPicker: some View { // 屏幕选择器
        let options = ScreenHelper.screenOptions() // 屏幕选项
        VStack(alignment: .leading, spacing: 8) { // 垂直布局
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

    private func infoRow(title: String, value: String?) -> some View { // 信息行
        LabeledContent(title) { // 标题与值
            Text(value ?? "—") // 空值占位
                .foregroundStyle(.secondary) // 次级颜色
        }
    }

    private var typeText: String { // 类型文本
        switch item.type { // 类型
        case .image: return "图片" // 图片
        case .video: return "视频" // 视频
        }
    }

    private var typeIcon: String { // 类型图标
        switch item.type { // 类型
        case .image: return "photo" // 图片图标
        case .video: return "video" // 视频图标
        }
    }

    private var resolutionText: String? { // 分辨率文本
        guard let width = item.width, let height = item.height else { return nil } // 无尺寸
        return "\(Int(width)) × \(Int(height))" // 尺寸文本
    }

    private var durationText: String? { // 时长文本
        guard let duration = item.duration else { return nil } // 无时长
        return formatDuration(duration) // 格式化
    }

    private var sizeText: String? { // 大小文本
        guard let sizeBytes = item.sizeBytes else { return nil } // 无大小
        return byteCount(sizeBytes) // 格式化
    }

    private var frameRateText: String? { // 帧率文本
        guard let frameRate = item.frameRate, frameRate > 0 else { return nil } // 无帧率
        return String(format: "%.2f fps", frameRate) // 帧率
    }

    private var lastUsedText: String? { // 最近使用
        guard let lastUsedAt = item.lastUsedAt else { return nil } // 无记录
        return DateFormatter.localizedString(from: lastUsedAt, dateStyle: .medium, timeStyle: .short) // 格式化
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

    private func isPermissionIssue(_ reason: String) -> Bool { // 判断权限问题
        reason.contains("权限") || reason.contains("不可读") || reason.contains("安全访问失败")
    }

    private func reselectFile() { // 重新选择文件
        let panel = NSOpenPanel() // 打开面板
        panel.canChooseFiles = true // 可选文件
        panel.canChooseDirectories = false // 不选目录
        panel.allowsMultipleSelection = false // 单选
        if item.type == .image { // 图片
            panel.allowedContentTypes = [.image] // 允许图片
        } else if item.type == .video { // 视频
            panel.allowedContentTypes = [.movie] // 允许视频
        }
        if panel.runModal() == .OK, let url = panel.url { // 用户选择
            do {
                try MediaImportService.updateItem(item, from: url) // 更新素材
                try? modelContext.save() // 保存
                NSLog("[权限] 重新授权成功：\(url.lastPathComponent)") // 日志
            } catch {
                NSLog("[权限] 重新授权失败：\(error.localizedDescription)") // 日志
            }
        }
    }
}
