import AppKit // NSImage
import SwiftUI // SwiftUI 界面

// ThumbnailView：素材缩略图
struct ThumbnailView: View {
    let item: MediaItem // 素材

    var body: some View { // 视图
        ZStack { // 叠放
            if item.type == .image { // 图片类型
                let thumbnail = MediaAccessService.loadThumbnail(for: item, targetSize: CGSize(width: 48, height: 36)) // 缩略图
                if let image = thumbnail { // 读取成功
                    Image(nsImage: image) // 显示图片
                        .resizable() // 可拉伸
                        .scaledToFill() // 填充
                } else { // 读取失败
                    Rectangle() // 占位背景
                        .fill(.quaternary) // 次级颜色
                    VStack(spacing: 4) { // 垂直布局
                        Image(systemName: "photo") // 图标
                            .foregroundStyle(.secondary) // 次级颜色
                        Text(item.fileURL.lastPathComponent) // 文件名
                            .font(.caption2) // 小字号
                            .foregroundStyle(.secondary) // 次级颜色
                            .lineLimit(1) // 单行
                    }
                }
            } else if item.type == .video { // 视频类型
                VideoPlayerView(item: item, isMuted: true) // 视频缩略预览
                    .clipShape(.rect(cornerRadius: 4)) // 圆角
            } else { // 其他
                Rectangle() // 占位背景
                    .fill(.quaternary) // 次级颜色
                Image(systemName: "photo") // 图标
                    .foregroundStyle(.secondary) // 次级颜色
            }
        }
    }
}

// MediaCard：网格布局使用的卡片视图
struct MediaCard: View {
    let item: MediaItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if item.type == .image {
                    let thumbnail = MediaAccessService.loadThumbnail(for: item, targetSize: CGSize(width: 200, height: 120))
                    if let image = thumbnail {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    } else {
                        placeholder
                    }
                } else if item.type == .video {
                    VideoPlayerView(item: item, isMuted: true)
                        .frame(height: 120)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    placeholder
                }

                if isSelected {
                    Rectangle()
                        .fill(.blue.opacity(0.2))
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .font(.title)
                        .shadow(radius: 2)
                }
            }
            .frame(height: 120)
            .background(Color.black.opacity(0.1))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileURL.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack {
                    if item.type == .video {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: item.type == .video ? "film" : "photo")
                .foregroundStyle(.secondary)
        }
    }
}

// TiledImageView：使用 AppKit 的 patternImage 做原生平铺
struct TiledImageView: NSViewRepresentable {
    let image: NSImage // 平铺图片

    func makeNSView(context: Context) -> NSView { // 创建视图
        let view = NSView() // 创建 NSView
        view.wantsLayer = true // 启用图层
        view.layer?.backgroundColor = NSColor(patternImage: image).cgColor // 平铺背景
        return view // 返回视图
    }

    func updateNSView(_ nsView: NSView, context: Context) { // 更新视图
        nsView.layer?.backgroundColor = NSColor(patternImage: image).cgColor // 更新平铺
    }
}
