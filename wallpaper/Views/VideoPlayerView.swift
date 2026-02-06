import AppKit
import AVFoundation
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    let url: URL
    let isMuted: Bool

    final class Coordinator {
        var player: AVPlayer
        var url: URL

        init(url: URL, isMuted: Bool) {
            self.url = url
            self.player = AVPlayer(url: url)
            self.player.isMuted = isMuted
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, isMuted: isMuted)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVPlayerLayer(player: context.coordinator.player)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        context.coordinator.player.play()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let layer = nsView.layer as? AVPlayerLayer else { return }
        layer.frame = nsView.bounds

        if context.coordinator.url != url {
            context.coordinator.url = url
            let newPlayer = AVPlayer(url: url)
            newPlayer.isMuted = isMuted
            context.coordinator.player = newPlayer
            layer.player = newPlayer
            newPlayer.play()
        } else {
            context.coordinator.player.isMuted = isMuted
        }
    }
}
