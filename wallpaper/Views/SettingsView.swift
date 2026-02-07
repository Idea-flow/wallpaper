import SwiftUI // SwiftUI 界面

// SettingsView：全局设置
struct SettingsView: View {
    @AppStorage("autoLaunchEnabled") private var autoLaunchEnabled = false // 开机自启
    @AppStorage("menuBarEnabled") private var menuBarEnabled = false // 菜单栏
    @AppStorage("reduceVideoPower") private var reduceVideoPower = true // 低功耗
    @AppStorage("pauseVideoWhenLowPower") private var pauseVideoWhenLowPower = true // 低电/遮挡暂停
    @AppStorage("themeColorHex") private var themeColorHex = ThemeColor.defaultHex // 主题色
    @AppStorage("themeMode") private var themeMode = "system" // 主题模式
    @AppStorage("sidebarSelectionStyle") private var sidebarSelectionStyle = "custom" // 侧栏选中样式
    @State private var alertMessage: String? // 错误提示
    @State private var showingClearCacheConfirm = false // 清理确认弹窗
    @State private var showingCustomPicker = false // 自定义颜色

    var body: some View { // 主体
        ScrollView {
            VStack(spacing: 20) {
                // 系统设置
                GlassSection(title: "系统偏好") {
                    capsuleToggle(
                        title: "开机自启",
                        isOn: Binding(
                            get: { autoLaunchEnabled },
                            set: { newValue in
                                setAutoLaunch(newValue)
                            }
                        )
                    )
                    Divider().background(.white.opacity(0.1))
                    capsuleToggle(title: "显示菜单栏图标", isOn: $menuBarEnabled)
                }

                // 性能设置
                GlassSection(title: "性能优化") {
                    VStack(alignment: .leading, spacing: 10) {
                        capsuleToggle(title: "低功耗模式", isOn: $reduceVideoPower)
                        Text("启用后将减少视频壁纸的帧率以节省电量。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        capsuleToggle(title: "低电/遮挡时暂停视频，保留静帧", isOn: $pauseVideoWhenLowPower)
                        Text("默认开启，低电或壁纸不可见时自动暂停，降低解码与 GPU 占用。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("缩略图缓存") // 标题
                            Spacer()
                            Text(cacheSizeText) // 缓存大小
                                .foregroundStyle(.secondary)
                        }
                        Button("清理缓存") { // 清理缓存
                            showingClearCacheConfirm = true // 显示确认
                        }
                        .glassCapsuleBackground()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 外观设置
                GlassSection(title: "界面外观") {
                    capsuleToggle(title: "侧栏选中使用主题色", isOn: Binding(
                        get: { sidebarSelectionStyle == "custom" },
                        set: { sidebarSelectionStyle = $0 ? "custom" : "system" }
                    ))
                    HStack {
                        Text("主题模式")
                        Spacer()
                        ThemeModeSelector(selection: $themeMode)
                    }
                    Divider().background(.white.opacity(0.1))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("主题主色调")
                            .font(.subheadline)
                        LazyVGrid(columns: themeColumns, spacing: 12) {
                            ForEach(themePresets, id: \.self) { hex in
                                themeSwatch(hex)
                            }
                            Button {
                                showingCustomPicker.toggle()
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "eyedropper.halffull")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                        }
            if showingCustomPicker {
                            ColorPicker("自定义颜色", selection: themeColorBinding, supportsOpacity: true)
                                .padding(.vertical, 4)
                        }
                    }
                }

                // 说明
                GlassSection(title: "关于") {
                    Text("Wallpaper Pro Max")
                        .font(.headline)
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)

//                     if autoLaunchEnabled {
//                         Text("开机自启已启用")
//                             .font(.caption)
//                             .foregroundStyle(.green)
//                             .padding(.top, 4)
//                     } else {
//                          Text("开机自启需要系统批准，可在系统设置 > 登录项中查看。")
//                             .font(.caption)
//                             .foregroundStyle(.secondary)
//                             .padding(.top, 4)
//                     }
                }
            }
            .padding()
        }
        .background(Color.clear)
        .onAppear { // 进入时同步状态
            autoLaunchEnabled = AutoLaunchService.isEnabled() // 同步开机自启
        }
        .alert("设置失败", isPresented: Binding( // 错误弹窗
            get: { alertMessage != nil }, // 是否显示
            set: { _ in alertMessage = nil } // 关闭清空
        )) {
            Button("好") { alertMessage = nil } // 确认
        } message: {
            Text(alertMessage ?? "") // 错误内容
        }
        .alert("确认清理缓存？", isPresented: $showingClearCacheConfirm) { // 清理确认
            Button("清理", role: .destructive) { // 确认清理
                ThumbnailCache.shared.clear() // 清空缓存
                LogCenter.log("[设置] 已清理缩略图缓存") // 日志
            }
            Button("取消", role: .cancel) { } // 取消
        } message: {
            Text("将清空本地缩略图缓存。") // 提示
        }
    }

    private func setAutoLaunch(_ enabled: Bool) { // 设置开机自启
        // ... (保持不变)
        do {
            try AutoLaunchService.setEnabled(enabled) // 调用系统 API
            autoLaunchEnabled = AutoLaunchService.isEnabled() // 读取真实状态
            LogCenter.log("[设置] 开机自启状态：\(autoLaunchEnabled)") // 日志
        } catch {
            alertMessage = "开机自启设置失败：\(error.localizedDescription)" // 提示错误
            autoLaunchEnabled = AutoLaunchService.isEnabled() // 回滚状态
            LogCenter.log("[设置] 开机自启失败：\(error.localizedDescription)", level: .error) // 日志
        }
    }

    private var themeColorBinding: Binding<Color> { // 主题色绑定
        // ... (保持不变)
        Binding( // 创建绑定
            get: { ThemeColor.color(from: themeColorHex) }, // 读取颜色
            set: { newColor in // 设置颜色
                themeColorHex = ThemeColor.hex(from: newColor) // 保存主题色
                LogCenter.log("[设置] 主题色更新：\(themeColorHex)") // 日志
            }
        )
    }

    private var cacheSizeText: String { // 缓存大小文本
        let bytes = ThumbnailCache.shared.estimatedSizeBytes() // 估算大小
        let formatter = ByteCountFormatter() // 格式化
        formatter.allowedUnits = [.useKB, .useMB, .useGB] // 单位
        formatter.countStyle = .file // 文件样式
        return formatter.string(fromByteCount: Int64(bytes)) // 返回
    }
}

// GlassSection：复用玻璃容器组件
struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassPanel(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct ThemeModeSelector: View {
    @Binding var selection: String

    private let options: [(String, String)] = [
        ("system", "系统"),
        ("light", "明亮"),
        ("dark", "暗黑"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { key, title in
                Button {
                    withAnimation(Glass.animation) {
                        selection = key
                    }
                } label: {
                    Text(title)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 44)
                        .foregroundStyle(selection == key ? .primary : .secondary)
                        .background {
                            if selection == key {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.18))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .glassCapsuleBackground()
    }
}

extension SettingsView {
    private func capsuleToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .glassCapsuleBackground()
    }

    private var themePresets: [String] { // 预设主题色
        [
            "#0A84FF", // 蓝
            "#34C759", // 绿
            "#FF9500", // 橙
            "#FF2D55", // 粉
            "#AF52DE", // 紫
            "#FFD60A", // 黄
            "#64D2FF", // 青
            "#A2845E", // 棕
        ]
    }

    private var themeColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 36), spacing: 12)]
    }

    private func themeSwatch(_ hex: String) -> some View {
        let color = ThemeColor.color(from: hex)
        return Button {
            themeColorHex = hex
            LogCenter.log("[设置] 主题色更新：\(themeColorHex)")
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                if themeColorHex.uppercased() == hex.uppercased() {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                }
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
