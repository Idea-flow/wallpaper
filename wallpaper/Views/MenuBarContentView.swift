import AppKit // 使用 NSApp
import SwiftUI // SwiftUI 界面

// MenuBarContentView：菜单栏内容
struct MenuBarContentView: View {
    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 8) { // 垂直布局
            Button("显示主窗口") { // 显示主窗口
                NSApp.activate(ignoringOtherApps: true) // 激活应用
                NSApp.windows.first?.makeKeyAndOrderFront(nil) // 打开窗口
            }

            Divider() // 分隔线

            Button("停止视频壁纸") { // 停止视频壁纸
                VideoWallpaperService.shared.stopAll() // 停止播放
            }

            Divider() // 分隔线

            Button("退出") { // 退出应用
                NSApp.terminate(nil) // 退出
            }
        }
        .padding(8) // 内边距
    }
}
