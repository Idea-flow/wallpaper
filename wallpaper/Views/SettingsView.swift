import SwiftUI // SwiftUI 界面

// SettingsView：全局设置
struct SettingsView: View {
    @AppStorage("autoLaunchEnabled") private var autoLaunchEnabled = false // 开机自启
    @AppStorage("menuBarEnabled") private var menuBarEnabled = false // 菜单栏
    @AppStorage("reduceVideoPower") private var reduceVideoPower = true // 低功耗
    @AppStorage("themeColorHex") private var themeColorHex = ThemeColor.defaultHex // 主题色
    @AppStorage("themeMode") private var themeMode = "system" // 主题模式
    @State private var alertMessage: String? // 错误提示

    var body: some View { // 主体
        Form { // 表单
            Section("系统") { // 系统设置
                Toggle("开机自启", isOn: Binding( // 开机自启
                    get: { autoLaunchEnabled }, // 获取当前状态
                    set: { newValue in // 设置新值
                        setAutoLaunch(newValue) // 应用开机自启
                    }
                ))
                Toggle("显示菜单栏", isOn: $menuBarEnabled) // 菜单栏
            }

            Section("性能") { // 性能设置
                Toggle("低功耗模式", isOn: $reduceVideoPower) // 低功耗
            }

            Section("外观") { // 外观设置
                Picker("主题模式", selection: $themeMode) { // 主题模式
                    Text("系统").tag("system") // 系统
                    Text("明亮").tag("light") // 明亮
                    Text("暗黑").tag("dark") // 暗黑
                }
                .pickerStyle(.segmented) // 分段样式
                ColorPicker("主色彩", selection: themeColorBinding, supportsOpacity: true) // 主题色
            }

            Section("说明") { // 说明
                Text("开机自启需要系统批准，可在系统设置 > 登录项中查看。") // 提示
                    .foregroundStyle(.secondary) // 次级颜色
            }
        }
        .padding() // 内边距
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
    }

    private func setAutoLaunch(_ enabled: Bool) { // 设置开机自启
        do {
            try AutoLaunchService.setEnabled(enabled) // 调用系统 API
            autoLaunchEnabled = AutoLaunchService.isEnabled() // 读取真实状态
            NSLog("[设置] 开机自启状态：\\(autoLaunchEnabled)") // 日志
        } catch {
            alertMessage = "开机自启设置失败：\\(error.localizedDescription)" // 提示错误
            autoLaunchEnabled = AutoLaunchService.isEnabled() // 回滚状态
            NSLog("[设置] 开机自启失败：\\(error.localizedDescription)") // 日志
        }
    }

    private var themeColorBinding: Binding<Color> { // 主题色绑定
        Binding( // 创建绑定
            get: { ThemeColor.color(from: themeColorHex) }, // 读取颜色
            set: { newColor in // 设置颜色
                themeColorHex = ThemeColor.hex(from: newColor) // 保存主题色
                NSLog("[设置] 主题色更新：\\(themeColorHex)") // 日志
            }
        )
    }
}
