import SwiftUI // SwiftUI 框架
import SwiftData // SwiftData 框架

// wallpaperApp：应用入口，配置 SwiftData 容器并启动界面
@main
struct wallpaperApp: App {
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
        }
        .modelContainer(sharedModelContainer) // 注入数据容器
    }
}
