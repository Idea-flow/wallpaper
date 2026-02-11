import SwiftUI // SwiftUI

// BingPreviewImage：预览图片（支持 4K 回退）
struct BingPreviewImage: View { // 预览视图
    let item: BingWallpaperItem // 数据
    let preferUHD: Bool // 是否优先 4K
    @State private var showUHD = false // 是否显示 4K
    @State private var uhdFailed = false // 4K 是否失败

    var body: some View { // 主体
        ZStack { // 层叠
            Rectangle() // 背景
                .fill(.black.opacity(0.06)) // 轻背景

            AsyncImage(url: item.fullImageURL) { phase in // 先加载 1080p
                switch phase { // 状态
                case .empty: // 加载中
                    ProgressView() // 进度
                case .success(let image): // 成功
                    image
                        .resizable() // 可缩放
                        .scaledToFit() // 适应
                case .failure: // 失败
                    VStack(spacing: 8) { // 提示
                        Image(systemName: "photo") // 图标
                            .foregroundStyle(.secondary) // 次级色
                        Text("无法预览") // 文案
                            .foregroundStyle(.secondary) // 次级色
                    }
                @unknown default:
                    EmptyView() // 兜底
                }
            }

            if preferUHD && !uhdFailed { // 需要尝试 4K
                AsyncImage(url: item.uhdImageURL) { phase in // 加载 4K
                    switch phase { // 状态
                    case .empty: // 加载中
                        Color.clear // 维持 1080p 展示
                    case .success(let image): // 4K 成功
                        image
                            .resizable() // 可缩放
                            .scaledToFit() // 适应
                            .onAppear { // 显示 4K
                                showUHD = true // 标记已就绪
                            }
                    case .failure: // 4K 失败
                        Color.clear // 不打断 1080p
                            .onAppear { // 标记失败
                                uhdFailed = true // 不再尝试
                            }
                    @unknown default:
                        EmptyView() // 兜底
                    }
                }
                .opacity(showUHD ? 1 : 0) // 仅成功后显示
            }
        }
        .clipShape(.rect(cornerRadius: 12)) // 圆角
        .onChange(of: item.id) { _, _ in // 切换重置
            showUHD = false // 重置 4K 状态
            uhdFailed = false // 重置 失败标记
        }
    }
}
