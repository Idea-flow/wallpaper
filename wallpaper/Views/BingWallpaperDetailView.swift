import AppKit // NSWorkspace
import SwiftUI // SwiftUI
import SwiftData // SwiftData

// BingWallpaperDetailView：Bing 壁纸详情页
struct BingWallpaperDetailView: View { // 详情视图
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Bindable var store: BingWallpaperStore // Bing 状态

    var body: some View { // 主体
        Group { // 分组
            if let item = store.selectedItem { // 有选中
                detailContent(for: item) // 详情内容
            } else { // 无选中
                ContentUnavailableView("请选择壁纸", systemImage: "photo") // 占位
            }
        }
        .padding() // 内边距
    }

    private func detailContent(for item: BingWallpaperItem) -> some View { // 详情内容
        VStack(alignment: .leading, spacing: 16) { // 垂直布局
            BingPreviewImage(item: item, preferUHD: store.preferUHD) // 预览图
                .frame(height: 360) // 固定高度
                .glassSurface(cornerRadius: 12) // 玻璃效果

            HStack(spacing: 12) { // 操作区
                Button { // 保存按钮
                    Task { // 异步
                        await store.downloadToLibrary(item, modelContext: modelContext) // 保存到素材库
                    }
                } label: {
                    Label("保存到素材库", systemImage: "tray.and.arrow.down") // 文案
                }
                .glassActionButtonStyle() // 玻璃按钮
                .disabled(store.downloadingIDs.contains(item.id)) // 下载中禁用

                if let link = item.copyrightLink { // 有版权链接
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // 对齐
    }
}

// BingPreviewImage：预览图片（支持 4K 回退）
struct BingPreviewImage: View { // 预览视图
    let item: BingWallpaperItem // 数据
    let preferUHD: Bool // 是否优先 4K
    @State private var fallbackToHD = false // 是否回退

    var body: some View { // 主体
        ZStack { // 层叠
            Rectangle() // 背景
                .fill(.black.opacity(0.06)) // 轻背景

            AsyncImage(url: currentURL) { phase in // 异步图片
                switch phase { // 状态
                case .empty: // 加载中
                    ProgressView() // 进度
                case .success(let image): // 成功
                    image
                        .resizable() // 可缩放
                        .scaledToFit() // 适应
                case .failure: // 失败
                    if preferUHD && !fallbackToHD { // 4K 失败回退
                        Color.clear.onAppear { fallbackToHD = true } // 触发回退
                    } else { // 最终失败
                        VStack(spacing: 8) { // 提示
                            Image(systemName: "photo") // 图标
                                .foregroundStyle(.secondary) // 次级色
                            Text("无法预览") // 文案
                                .foregroundStyle(.secondary) // 次级色
                        }
                    }
                @unknown default:
                    EmptyView() // 兜底
                }
            }
        }
        .clipShape(.rect(cornerRadius: 12)) // 圆角
        .onChange(of: item.id) { _, _ in // 切换重置
            fallbackToHD = false // 重置回退
        }
    }

    private var currentURL: URL { // 当前 URL
        if preferUHD && !fallbackToHD { // 4K
            return item.uhdImageURL // UHD
        }
        return item.fullImageURL // 1080p
    }
}
