import AppKit // NSWorkspace
import SwiftUI // SwiftUI
import SwiftData // SwiftData

// BingWallpaperPreviewView：预览窗口内容
struct BingWallpaperPreviewView: View { // 预览视图
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Bindable var store: BingWallpaperStore // Bing 状态
    let item: BingWallpaperItem // 壁纸数据

    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 16) { // 垂直布局
            BingPreviewImage(item: item, preferUHD: store.preferUHD) // 预览图
                .frame(maxWidth: .infinity) // 宽度填满
                .frame(height: 520) // 高度
                .glassSurface(cornerRadius: 14) // 玻璃效果

            HStack(spacing: 12) { // 操作区
                Button { // 保存按钮
                    Task { // 异步
                        await store.downloadToLibrary(item, modelContext: modelContext) // 保存
                    }
                } label: {
                    Label("保存到素材库", systemImage: "tray.and.arrow.down") // 文案
                }
                .glassActionButtonStyle() // 玻璃按钮
                .disabled(store.downloadingIDs.contains(item.id)) // 下载中禁用

                if let link = item.copyrightLink { // 版权链接
                    Button { // 打开链接
                        NSWorkspace.shared.open(link) // 打开浏览器
                        LogCenter.log("[Bing] 打开版权链接：\(link.absoluteString)") // 日志
                    } label: {
                        Label("版权链接", systemImage: "link") // 文案
                    }
                }

                Spacer() // 占位

                if store.downloadingIDs.contains(item.id) { // 下载中
                    ProgressView() // 进度
                }
            }

            VStack(alignment: .leading, spacing: 6) { // 信息
                Text(item.displayTitle) // 标题
                    .font(.title3) // 字号
                    .bold() // 加粗
                Text(item.displayDate) // 日期
                    .foregroundStyle(.secondary) // 次级色
                Text(item.copyright) // 版权
                    .font(.caption) // 小字
                    .foregroundStyle(.secondary) // 次级色
            }
        }
        .padding() // 内边距
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // 顶部对齐
    }
}
