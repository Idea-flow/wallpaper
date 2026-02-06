import AppKit // 使用 NSView
import AVFoundation // 使用 AVPlayer
import SwiftUI // SwiftUI 适配

// VideoPlayerView：用于在详情页预览视频
struct VideoPlayerView: NSViewRepresentable {
    let item: MediaItem // 视频素材
    let isMuted: Bool // 是否静音

    // Coordinator：持有播放器和安全访问令牌
    class Coordinator {
        var player: AVPlayer // 播放器
        var accessToken: MediaAccessService.AccessToken // 安全访问令牌

        init(accessToken: MediaAccessService.AccessToken, player: AVPlayer) { // 指定初始化
            self.accessToken = accessToken // 保存令牌
            self.player = player // 保存播放器
        }

        convenience init(item: MediaItem, isMuted: Bool) throws { // 便捷初始化
            let token = try MediaAccessService.beginAccess(for: item) // 开启安全访问
            let asset = AVURLAsset(url: token.url) // 创建视频资源
            let playerItem = AVPlayerItem(asset: asset) // 创建播放条目
            let player = AVPlayer(playerItem: playerItem) // 创建播放器
            player.isMuted = isMuted // 设置静音
            self.init(accessToken: token, player: player) // 调用指定初始化
        }

        static func fallback() -> Coordinator { // 兜底协调器
            let url = URL(fileURLWithPath: "/dev/null") // 空文件
            let token = MediaAccessService.AccessToken(url: url, stopAccess: {}) // 空令牌
            let asset = AVURLAsset(url: url) // 空资源
            let playerItem = AVPlayerItem(asset: asset) // 空播放条目
            let player = AVPlayer(playerItem: playerItem) // 空播放器
            return Coordinator(accessToken: token, player: player) // 返回兜底
        }

        deinit { // 释放时停止安全访问
            accessToken.stopAccess() // 停止安全访问
        }
    }

    func makeCoordinator() -> Coordinator { // 创建协调器
        (try? Coordinator(item: item, isMuted: isMuted)) ?? Coordinator.fallback() // 尝试创建
    }

    func makeNSView(context: Context) -> NSView { // 创建 NSView
        let view = NSView() // 创建视图
        view.wantsLayer = true // 启用图层
        let layer = AVPlayerLayer(player: context.coordinator.player) // 创建播放图层
        layer.videoGravity = .resizeAspectFill // 默认填充
        view.layer = layer // 设置图层
        context.coordinator.player.play() // 开始播放
        return view // 返回视图
    }

    func updateNSView(_ nsView: NSView, context: Context) { // 更新视图
        guard let layer = nsView.layer as? AVPlayerLayer else { return } // 确保图层类型
        layer.frame = nsView.bounds // 更新图层大小
        context.coordinator.player.isMuted = isMuted // 更新静音状态
    }
}
