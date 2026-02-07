import SwiftUI // SwiftUI

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
