import AppKit // NSWorkspace
import SwiftUI // SwiftUI
import SwiftData // SwiftData

// BingWallpaperPreviewView：预览窗口内容
struct BingWallpaperPreviewView: View { // 预览视图
    @Bindable var store: BingWallpaperStore // Bing 状态
    let item: BingWallpaperItem // 壁纸数据
    let onClose: () -> Void // 关闭窗口

    var body: some View { // 主体
        BingPreviewImage(item: item, preferUHD: store.preferUHD) // 预览图
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 充满窗口
            .clipShape(.rect(cornerRadius: 16)) // 圆角
            .contentShape(Rectangle()) // 扩大可点击区域
            .onTapGesture { // 点击关闭
                onClose()
            }
            .onExitCommand { // ESC 关闭
                onClose()
            }
            .ignoresSafeArea() // 覆盖标题栏区域
    }
}
