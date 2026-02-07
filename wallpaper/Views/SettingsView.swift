import AppKit // NSApp
import SwiftUI // SwiftUI 界面

// SettingsView：全局设置
struct SettingsView: View {
    @AppStorage("autoLaunchEnabled") private var autoLaunchEnabled = false // 开机自启
    @AppStorage("menuBarEnabled") private var menuBarEnabled = false // 菜单栏
    @AppStorage("dockIconHidden") private var dockIconHidden = false // Dock 图标隐藏
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true // 自动检查更新
    @AppStorage("updateFeedURL") private var updateFeedURL = "https://raw.githubusercontent.com/Idea-flow/wallpaper/refs/heads/main/version/version.json" // 更新 JSON 地址
    @AppStorage("lastUpdateCheck") private var lastUpdateCheck = 0.0 // 上次检查时间
    @AppStorage("reduceVideoPower") private var reduceVideoPower = true // 低功耗
    @AppStorage("pauseVideoWhenLowPower") private var pauseVideoWhenLowPower = true // 低电/遮挡暂停
    @AppStorage("themeColorHex") private var themeColorHex = ThemeColor.defaultHex // 主题色
    @AppStorage("themeMode") private var themeMode = "system" // 主题模式
    @AppStorage("sidebarSelectionStyle") private var sidebarSelectionStyle = "custom" // 侧栏选中样式
    @State private var alertMessage: String? // 错误提示
    @State private var showingClearCacheConfirm = false // 清理确认弹窗
    @State private var showingCustomPicker = false // 自定义颜色
    @StateObject private var perfMonitor = PerformanceMonitor() // 性能监控
    @AppStorage("performanceMonitorEnabled") private var performanceMonitorEnabled = false // 性能监控开关
    @State private var isCheckingUpdate = false // 更新检查中
    @State private var isDownloadingUpdate = false // 下载中
    @State private var downloadProgress: Double = 0 // 下载进度
    @State private var updateAlert: UpdateAlertItem? // 更新提示

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
                    capsuleToggle(title: "Dock 无图标", isOn: Binding(
                        get: { dockIconHidden },
                        set: { newValue in
                            dockIconHidden = newValue
                            if newValue { menuBarEnabled = true }
                        }
                    ))
                    Text("开启后应用在 Dock 中不显示图标。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    capsuleToggle(title: "显示菜单栏图标", isOn: Binding(
                        get: { menuBarEnabled },
                        set: { newValue in
                            if dockIconHidden && !newValue { return }
                            menuBarEnabled = newValue
                        }
                    ))
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

                // 数据存储
                GlassSection(title: "数据存储") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("SwiftData 数据库")
                            Spacer()
                            Text(swiftDataStorePath ?? "未找到")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        if swiftDataStorePath != nil {
                            HStack(spacing: 8) {
                                Button("打开所在文件夹") {
                                    openSwiftDataFolder()
                                }
                                .glassCapsuleBackground()

                                Button("打开数据库文件") {
                                    openSwiftDataFile()
                                }
                                .glassCapsuleBackground()

                                Button("复制路径") {
                                    copySwiftDataPath()
                                }
                                .glassCapsuleBackground()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 版本更新
                GlassSection(title: "版本更新") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("当前版本")
                            Spacer()
                            Text("\(UpdateService.currentVersionString())")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("更新地址")
                            Spacer()
                            Text(updateFeedURL)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        Text("更新地址使用 GitHub 托管的 JSON 文件。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("更新 JSON 地址", text: $updateFeedURL)
                            .textFieldStyle(.roundedBorder)
                        capsuleToggle(title: "自动检查更新", isOn: $autoCheckUpdates)
                        if lastUpdateCheck > 0 {
                            HStack {
                                Text("上次检查")
                                Spacer()
                                Text(lastCheckText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button(isCheckingUpdate ? "检查中…" : "检查更新") {
                            LogCenter.log("[更新] 手动检查更新")
                            Task { await checkForUpdates(showNoUpdateAlert: true) }
                        }
                        .disabled(isCheckingUpdate)
                        .glassCapsuleBackground()
                        if isDownloadingUpdate {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("下载进度 \(Int(downloadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: downloadProgress)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 性能状态
                GlassSection(title: "性能状态") {
                    capsuleToggle(title: "开启性能监控", isOn: $performanceMonitorEnabled)
                    Text("关闭时不采集数据，开启后每 1 秒刷新一次。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("进程 ID")
                        Spacer()
                        Text("\(perfMonitor.pid)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("CPU 占用")
                        Spacer()
                        Text(String(format: "%.1f%%", perfMonitor.cpuUsage))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("内存占用")
                        Spacer()
                        Text(byteCount(perfMonitor.memoryBytes))
                            .foregroundStyle(.secondary)
                    }
//                     HStack {
//                         Text("GPU 占用")
//                         Spacer()
//                         Text("不可用")
//                             .foregroundStyle(.secondary)
//                     }
//                     HStack {
//                         Text("耗电量")
//                         Spacer()
//                         Text("不可用")
//                             .foregroundStyle(.secondary)
//                     }
                }

                // 说明
                GlassSection(title: "关于") {
                    Text("Wallpaper")
                        .font(.headline)
                    Text("Version \(UpdateService.currentVersionString())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link("GitHub: https://github.com/Idea-flow/wallpaper", destination: URL(string: "https://github.com/Idea-flow/wallpaper")!)
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
            if performanceMonitorEnabled { perfMonitor.start() } // 按开关启动监控
        }
        .onDisappear {
            perfMonitor.stop()
        }
        .onChange(of: performanceMonitorEnabled) { _, newValue in
            if newValue {
                perfMonitor.start()
            } else {
                perfMonitor.stop()
            }
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
        .alert(item: $updateAlert) { alert in
            if let release = alert.release {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(alert.primaryButton)) {
                        Task { await downloadUpdate(release) }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("好"))
            )
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

    private func byteCount(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private var lastCheckText: String {
        let date = Date(timeIntervalSince1970: lastUpdateCheck)
        return dateFormatter.string(from: date)
    }

    private var dateFormatter: DateFormatter { // 日期格式
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
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
    private func checkForUpdates(showNoUpdateAlert: Bool) async {
        guard let url = URL(string: updateFeedURL), !updateFeedURL.isEmpty else {
            updateAlert = UpdateAlertItem(
                title: "未配置更新地址",
                message: "请在设置中填写更新 JSON 地址。",
                primaryButton: "好",
                release: nil
            )
            return
        }
        isCheckingUpdate = true
        defer { isCheckingUpdate = false }
        do {
            let result = try await UpdateService.checkUpdates(from: url)
            lastUpdateCheck = Date().timeIntervalSince1970
            switch result {
            case .upToDate:
                if showNoUpdateAlert {
                    updateAlert = UpdateAlertItem(
                        title: "已是最新版本",
                        message: "当前已是最新版本。",
                        primaryButton: "好",
                        release: nil
                    )
                }
            case .updateAvailable(let release, let isMandatory):
                let mandatoryText = isMandatory ? "（需要更新）" : ""
                updateAlert = UpdateAlertItem(
                    title: "发现新版本 \(release.version) \(mandatoryText)",
                    message: release.notes.isEmpty ? "点击下载更新。" : release.notes,
                    primaryButton: "下载更新",
                    release: release
                )
            }
        } catch {
            updateAlert = UpdateAlertItem(
                title: "检查失败",
                message: error.localizedDescription,
                primaryButton: "好",
                release: nil
            )
        }
    }

    @MainActor
    private func downloadUpdate(_ release: UpdateService.UpdateRelease) async {
        guard !isDownloadingUpdate else { return }
        isDownloadingUpdate = true
        downloadProgress = 0
        defer { isDownloadingUpdate = false }
        LogCenter.log("[更新] 开始后台下载更新包")
        let result = await UpdateService.downloadUpdate(release) { value in
            downloadProgress = value
        }
        switch result {
        case .success(let fileURL):
            UpdateService.revealInFinder(fileURL)
            if NSApp.isActive {
                updateAlert = UpdateAlertItem(
                    title: "下载完成",
                    message: "已下载更新包，可在 Finder 中手动替换应用。\n目录：\(fileURL.deletingLastPathComponent().path)",
                    primaryButton: "好",
                    release: nil
                )
            } else {
                LogCenter.log("[更新] 下载完成，应用未前台显示，跳过弹窗提示")
            }
        case .failure(let error):
            updateAlert = UpdateAlertItem(
                title: "下载失败",
                message: error.localizedDescription,
                primaryButton: "好",
                release: nil
            )
        }
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

private struct UpdateAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: String
    let release: UpdateService.UpdateRelease?
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
