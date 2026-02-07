import AppKit // NSWorkspace
import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData

// BingWallpapersView：Bing 壁纸列表页
struct BingWallpapersView: View { // Bing 列表视图
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Bindable var store: BingWallpaperStore // Bing 状态

    private let gridColumns = [ // 网格列
        GridItem(.adaptive(minimum: 220), spacing: 16) // 自适应列
    ]

    var body: some View { // 主体
        VStack(spacing: 12) { // 垂直布局
            toolbar // 顶部工具
            content // 内容区
        }
        .padding() // 内边距
        .task(id: taskKey) { // 自动拉取
            await store.load() // 拉取数据
        }
    }

    private var taskKey: String { // 任务 key
        "\(store.market)-\(store.dayIndex)-\(store.count)" // 组合
    }

    private var toolbar: some View { // 顶部工具栏
        HStack(spacing: 12) { // 横向布局
            Picker("地区", selection: $store.market) { // 市场选择
                ForEach(store.markets) { option in // 遍历市场
                    Text(option.name).tag(option.id) // 选项
                }
            }
            .pickerStyle(.menu) // 菜单样式

            Button { // 前一天
                if store.dayIndex < 15 { store.dayIndex += 1 } // 向前
            } label: {
                Label("上一天", systemImage: "chevron.left") // 文案
            }
            .disabled(store.dayIndex >= 15) // 超过上限

            Text(store.dayLabel) // 日期标签
                .font(.subheadline) // 字号
                .foregroundStyle(.secondary) // 次级色

            Button { // 后一天
                if store.dayIndex > 0 { store.dayIndex -= 1 } // 向后
            } label: {
                Label("下一天", systemImage: "chevron.right") // 文案
            }
            .disabled(store.dayIndex == 0) // 今天禁用

            Picker("数量", selection: $store.count) { // 数量选择
                Text("4 张").tag(4) // 4 张
                Text("8 张").tag(8) // 8 张
            }
            .pickerStyle(.segmented) // 分段样式
            .frame(width: 140) // 固定宽度

            Toggle("4K", isOn: $store.preferUHD) // 4K 开关
                .toggleStyle(.switch) // 开关样式

            Spacer() // 占位

            Button { // 刷新
                Task { await store.load() } // 重新拉取
            } label: {
                Label("刷新", systemImage: "arrow.clockwise") // 文案
            }
        }
    }

    @ViewBuilder
    private var content: some View { // 内容区
        if store.isLoading && store.items.isEmpty { // 首次加载
            VStack(spacing: 12) { // 垂直布局
                ProgressView() // 加载圈
                Text("正在加载 Bing 壁纸...") // 提示
                    .foregroundStyle(.secondary) // 次级色
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 居中
        } else if let error = store.errorMessage, store.items.isEmpty { // 错误
            VStack(spacing: 12) { // 错误容器
                Image(systemName: "exclamationmark.triangle") // 警告图标
                    .font(.system(size: 32)) // 图标大小
                    .foregroundStyle(.secondary) // 次级色
                Text("加载失败") // 标题
                    .font(.headline) // 字号
                Text(error) // 错误提示
                    .foregroundStyle(.secondary) // 次级色
                    .multilineTextAlignment(.center) // 居中
                Button("重试") { // 重试按钮
                    Task { await store.load() } // 重新拉取
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 居中
        } else { // 正常列表
            ScrollView { // 滚动
                LazyVGrid(columns: gridColumns, spacing: 16) { // 网格
                    ForEach(store.items) { item in // 遍历
                        BingWallpaperCard( // 卡片
                            item: item, // 数据
                            isSelected: store.selectedID == item.id, // 选中态
                            isDownloading: store.downloadingIDs.contains(item.id) // 下载态
                        ) { // 点击选择
                            store.selectedID = item.id // 更新选中
                        }
                        .contextMenu { // 右键菜单
                            Button("保存到素材库") { // 保存
                                Task { // 异步
                                    await store.downloadToLibrary(item, modelContext: modelContext) // 下载保存
                                }
                            }
                            if let link = item.copyrightLink { // 版权链接
                                Button("打开版权链接") { // 打开链接
                                    NSWorkspace.shared.open(link) // 打开浏览器
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4) // 顶部间距
            }
        }
    }
}

// BingWallpaperCard：壁纸卡片
struct BingWallpaperCard: View { // 卡片视图
    let item: BingWallpaperItem // 数据
    let isSelected: Bool // 选中态
    let isDownloading: Bool // 下载态
    let onSelect: () -> Void // 点击

    var body: some View { // 主体
        Button { // 点击
            onSelect() // 触发选择
        } label: {
            VStack(alignment: .leading, spacing: 8) { // 垂直布局
                ZStack(alignment: .topTrailing) { // 预览 + 状态
                    AsyncImage(url: item.fullImageURL) { phase in // 异步图片
                        switch phase { // 状态分支
                        case .empty: // 加载中
                            ZStack { // 占位
                                Rectangle().fill(.black.opacity(0.06)) // 背景
                                ProgressView() // 进度
                            }
                        case .success(let image): // 成功
                            image
                                .resizable() // 可缩放
                                .scaledToFill() // 填充
                        case .failure: // 失败
                            ZStack { // 占位
                                Rectangle().fill(.black.opacity(0.06)) // 背景
                                Image(systemName: "photo") // 图标
                                    .foregroundStyle(.secondary) // 次级色
                            }
                        @unknown default:
                            EmptyView() // 兜底
                        }
                    }
                    .frame(height: 120) // 固定高度
                    .clipShape(.rect(cornerRadius: 10)) // 圆角

                    if isDownloading { // 下载中
                        ProgressView() // 进度
                            .padding(6) // 内边距
                    }
                }

                Text(item.displayTitle) // 标题
                    .font(.headline) // 字体
                    .lineLimit(1) // 单行

                Text(item.displayDate) // 日期
                    .font(.caption) // 小字
                    .foregroundStyle(.secondary) // 次级色

                Text(item.copyright) // 版权
                    .font(.caption2) // 更小字
                    .foregroundStyle(.secondary) // 次级色
                    .lineLimit(1) // 单行
            }
            .padding(10) // 内边距
            .background(backgroundStyle) // 背景
            .clipShape(.rect(cornerRadius: 12)) // 圆角
        }
        .buttonStyle(.plain) // 取消默认样式
    }

    private var backgroundStyle: some View { // 背景样式
        RoundedRectangle(cornerRadius: 12) // 圆角
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08)) // 选中高亮
    }
}
