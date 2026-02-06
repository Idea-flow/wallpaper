import AppKit // 使用 AppKit
import SwiftUI // 使用 SwiftUI
import SwiftData // 使用 SwiftData

// MenuBarContentView：菜单栏内容（显示主窗口/上一张/下一张/停止视频/导入素材/退出）
struct MenuBarContentView: View { // 菜单栏视图
    @AppStorage("themeColorHex") private var themeColorHex = ThemeColor.defaultHex // 主题色
    @Environment(\.modelContext) private var modelContext // 数据上下文

    var body: some View { // 视图主体
        VStack(alignment: .leading, spacing: 8) { // 垂直布局
            Button("显示主窗口") { // 显示主窗口
                MenuBarActions.showMainWindow() // 执行动作
            } // 结束按钮

            Divider() // 分隔线

            Button("停止视频壁纸") { // 停止视频壁纸
                MenuBarActions.stopVideoWallpaper() // 停止播放
            } // 结束按钮

            Divider() // 分隔线

            Button("导入素材") { // 导入素材
                MenuBarActions.importMedia(in: modelContext) // 打开导入
            } // 结束按钮

            Divider() // 分隔线

            Button("退出") { // 退出应用
                MenuBarActions.quitApp() // 退出应用
            } // 结束按钮
        } // 结束布局
        .padding(8) // 内边距
        .tint(ThemeColor.color(from: themeColorHex)) // 应用主题色
        .glassPanel(cornerRadius: 12) // 玻璃容器
    } // 结束视图主体
} // 结束视图
