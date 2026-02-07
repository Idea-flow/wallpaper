import AppKit // AppKit
import SwiftUI // SwiftUI 框架
import SwiftData // SwiftData 框架

// wallpaperApp：应用入口，配置 SwiftData 容器并启动界面
@main
struct wallpaperApp: App {
    @AppStorage("menuBarEnabled") private var menuBarEnabled = false // 菜单栏开关
    @AppStorage("dockIconHidden") private var dockIconHidden = false // Dock 图标隐藏
    @AppStorage("themeColorHex") private var themeColorHex = ThemeColor.defaultHex // 主题色
    @AppStorage("themeMode") private var themeMode = "system" // 主题模式
    @State private var rulesStarted = false // 规则调度是否启动

    var sharedModelContainer: ModelContainer = { // 共享数据库容器
        let schema = Schema([ // 定义数据模型
            MediaItem.self, // 素材
            Album.self, // 相册
            Rule.self, // 规则
            ScreenProfile.self, // 屏幕偏好
            History.self, // 历史记录
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false) // 配置持久化

        do { // 捕获异常
            return try ModelContainer(for: schema, configurations: [modelConfiguration]) // 创建容器
        } catch {
            fatalError("Could not create ModelContainer: \(error)") // 失败直接崩溃
        }
    }()

    var body: some Scene { // 主场景
        WindowGroup { // 窗口组
            ContentView() // 主界面
                .tint(ThemeColor.color(from: themeColorHex)) // 应用主题色
                .preferredColorScheme(preferredScheme) // 应用主题模式
                .task { // 启动规则调度
                    if !rulesStarted { // 避免重复
                        RuleScheduler.shared.start(container: sharedModelContainer) // 启动调度
                        rulesStarted = true // 标记启动
                    }
                }
                .onAppear { // 同步 Dock 图标状态
                    setDockIconHidden(dockIconHidden)
                }
                .onChange(of: dockIconHidden) { _, newValue in
                    setDockIconHidden(newValue)
                }
        }
        .modelContainer(sharedModelContainer) // 注入数据容器

        MenuBarExtra("wallpaper", image: "MenuBarIcon", isInserted: $menuBarEnabled) { // 菜单栏
            MenuBarContentView() // 菜单栏内容
        }
        .modelContainer(sharedModelContainer) // 注入同一数据容器
    }

    private var preferredScheme: ColorScheme? { // 主题模式映射
        switch themeMode { // 判断模式
        case "light":
            return .light // 明亮
        case "dark":
            return .dark // 暗黑
        default:
            return nil // 跟随系统
        }
    }

    private func setDockIconHidden(_ hidden: Bool) {
        let policy: NSApplication.ActivationPolicy = hidden ? .accessory : .regular
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }
}
