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

    @ViewBuilder
    private var screenPicker: some View { // 屏幕选择器
        let options = ScreenHelper.screenOptions() // 屏幕选项
        HStack(spacing: 12) { // 横向布局
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
            if item.type == .video { // 视频权限按钮
                Button("重新授权视频文件") { // 重新授权
                    reselectFile() // 重新选择
                }
            }
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
