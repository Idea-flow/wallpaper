import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    enum SidebarSection: String, CaseIterable, Identifiable {
        case library = "素材库"
        case albums = "相册"
        case rules = "规则"
        case settings = "设置"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .library: return "photo.on.rectangle"
            case .albums: return "rectangle.stack"
            case .rules: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var items: [MediaItem]

    // Use the item's id for List selection (UUID is Hashable)
    @State private var selectionID: UUID?
    private var selectedItem: MediaItem? { items.first { $0.id == selectionID } }
    @State private var sidebarSelection: SidebarSection = .library
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var isSettingWallpaper = false
    @State private var selectedFitMode: FitMode = .fill

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $sidebarSelection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            switch sidebarSelection {
            case .library:
                libraryList
            case .albums:
                placeholderView(title: "Albums", subtitle: "Create collections for different moods.")
            case .rules:
                placeholderView(title: "Rules", subtitle: "Schedule and automation live here.")
            case .settings:
                placeholderView(title: "Settings", subtitle: "System integration and preferences.")
            }
        } detail: {
            detailView
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("", isPresented: Binding(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Button("好") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var libraryList: some View {
        List(selection: $selectionID) {
            ForEach(items) { item in
                MediaRow(item: item)
                    .tag(item.id)
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            Button {
                showingImporter = true
            } label: {
                Label("导入图片", systemImage: "plus")
            }
        }
    }

    private var detailView: some View {
        Group {
            if let item = selectedItem {
                MediaDetailView(
                    item: item,
                    fitMode: $selectedFitMode,
                    isSettingWallpaper: $isSettingWallpaper
                ) {
                    applyWallpaper(for: item, fitMode: selectedFitMode)
                }
            } else {
                ContentUnavailableView("请选择一张图片", systemImage: "photo")
            }
        }
        .padding()
    }

    private func placeholderView(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title)
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                importOne(url)
            }
        case .failure(let error):
            alertMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func importOne(_ url: URL) {
        do {
            let result = try MediaImportService.importMedia(from: url)
            modelContext.insert(result.item)
        } catch {
            alertMessage = "导入失败：\(url.lastPathComponent)"
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func applyWallpaper(for item: MediaItem, fitMode: FitMode) {
        isSettingWallpaper = true
        defer { isSettingWallpaper = false }

        do {
            if item.type == .image {
                try MediaAccessService.withResolvedURL(for: item) { url in
                    try WallpaperService.applyImage(url: url, to: nil, fitMode: fitMode)
                }
                alertMessage = "已应用到所有屏幕。"
            } else {
                try WallpaperService.applyVideoPlaceholder()
            }
        } catch {
            alertMessage = item.type == .video
                ? "视频壁纸尚未启用。"
                : "设置壁纸失败：\(error.localizedDescription)"
        }
    }
}

struct MediaRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(item: item)
                .frame(width: 48, height: 36)
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileURL.lastPathComponent)
                    .lineLimit(1)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var detailText: String {
        switch item.type {
        case .image:
            let width = item.width.map { Int($0) }
            let height = item.height.map { Int($0) }
            if let width, let height {
                return "图片 · \(width)x\(height)"
            }
            return "图片"
        case .video:
            if let duration = item.duration {
                return "视频 · \(formatDuration(duration))"
            }
            return "视频"
        }
    }

    private func formatDuration(_ duration: Double) -> String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ThumbnailView: View {
    let item: MediaItem

    var body: some View {
        ZStack {
            if item.type == .image, let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                Image(systemName: item.type == .video ? "film" : "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadImage() -> NSImage? {
        try? MediaAccessService.withResolvedURL(for: item) { url in
            NSImage(contentsOf: url)
        }
    }
}

struct MediaDetailView: View {
    let item: MediaItem
    @Binding var fitMode: FitMode
    @Binding var isSettingWallpaper: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if item.type == .image {
                fitModePicker
            }
            preview
            HStack {
                Button {
                    onApply()
                } label: {
                    Label(isSettingWallpaper ? "设置中..." : "设为壁纸", systemImage: "sparkles")
                }
                .glassActionButtonStyle()
                .disabled(isSettingWallpaper)

                Spacer()

                if item.isFavorite {
                    Label("已收藏", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                }
            }

            metadata
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var preview: some View {
        Group {
            if item.type == .image, let image = loadImage() {
                imagePreview(image)
                    .clipShape(.rect(cornerRadius: 12))
            } else if item.type == .video {
                VideoPlayerView(url: item.fileURL, isMuted: true)
                    .clipShape(.rect(cornerRadius: 12))
            } else {
                ContentUnavailableView("无法预览", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .glassSurface(cornerRadius: 12)
    }

    private var fitModePicker: some View {
        HStack(spacing: 12) {
            Text("适配模式")
                .foregroundStyle(.secondary)
            Picker("", selection: $fitMode) {
                Text("填充").tag(FitMode.fill)
                Text("适应").tag(FitMode.fit)
                Text("拉伸").tag(FitMode.stretch)
                Text("居中").tag(FitMode.center)
                Text("平铺").tag(FitMode.tile)
            }
            .pickerStyle(.segmented)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.fileURL.lastPathComponent)
                .font(.headline)

            HStack(spacing: 12) {
                if let width = item.width, let height = item.height {
                    Text("\(Int(width)) x \(Int(height))")
                }
                if let duration = item.duration {
                    Text("\(formatDuration(duration))")
                }
                if let sizeBytes = item.sizeBytes {
                    Text(byteCount(sizeBytes))
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ duration: Double) -> String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func loadImage() -> NSImage? {
        try? MediaAccessService.withResolvedURL(for: item) { url in
            NSImage(contentsOf: url)
        }
    }

    @ViewBuilder
    private func imagePreview(_ image: NSImage) -> some View {
        switch fitMode {
        case .fill:
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .fit:
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        case .stretch:
            Image(nsImage: image)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .center:
            Image(nsImage: image)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .tile:
            Rectangle()
                .fill(ImagePaint(image: Image(nsImage: image), scale: 1))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MediaItem.self, inMemory: true)
}

extension View {
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func glassActionButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
