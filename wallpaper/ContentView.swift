import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    enum SidebarSection: String, CaseIterable, Identifiable {
        case library = "Library"
        case albums = "Albums"
        case rules = "Rules"
        case settings = "Settings"

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

    @State private var selection: MediaItem?
    @State private var sidebarSelection: SidebarSection = .library
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var isSettingWallpaper = false

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
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("", isPresented: Binding(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var libraryList: some View {
        List(selection: $selection) {
            ForEach(items) { item in
                MediaRow(item: item)
                    .tag(item)
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            Button {
                showingImporter = true
            } label: {
                Label("Import", systemImage: "plus")
            }
        }
    }

    private var detailView: some View {
        Group {
            if let item = selection {
                MediaDetailView(item: item, isSettingWallpaper: $isSettingWallpaper) {
                    applyWallpaper(for: item)
                }
            } else {
                ContentUnavailableView("Select an item", systemImage: "photo")
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
            alertMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func importOne(_ url: URL) {
        do {
            let result = try MediaImportService.importMedia(from: url)
            modelContext.insert(result.item)
        } catch {
            alertMessage = "Import failed: \(url.lastPathComponent)"
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func applyWallpaper(for item: MediaItem) {
        isSettingWallpaper = true
        defer { isSettingWallpaper = false }

        do {
            if item.type == .image {
                try MediaAccessService.withResolvedURL(for: item) { url in
                    try WallpaperService.applyImage(url: url, to: nil)
                }
                alertMessage = "Wallpaper applied to all screens."
            } else {
                try WallpaperService.applyVideoPlaceholder()
            }
        } catch {
            alertMessage = item.type == .video
                ? "Video wallpaper is not enabled yet."
                : "Failed to apply wallpaper."
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
                return "Image · \(width)x\(height)"
            }
            return "Image"
        case .video:
            if let duration = item.duration {
                return "Video · \(formatDuration(duration))"
            }
            return "Video"
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
            if item.type == .image, let image = NSImage(contentsOf: item.fileURL) {
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
}

struct MediaDetailView: View {
    let item: MediaItem
    @Binding var isSettingWallpaper: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            preview
            HStack {
                Button {
                    onApply()
                } label: {
                    Label(isSettingWallpaper ? "Applying..." : "Set as Wallpaper", systemImage: "sparkles")
                }
                .glassActionButtonStyle()
                .disabled(isSettingWallpaper)

                Spacer()

                if item.isFavorite {
                    Label("Favorite", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                }
            }

            metadata
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var preview: some View {
        Group {
            if item.type == .image, let image = NSImage(contentsOf: item.fileURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 12))
            } else if item.type == .video {
                VideoPlayerView(url: item.fileURL, isMuted: true)
                    .clipShape(.rect(cornerRadius: 12))
            } else {
                ContentUnavailableView("Preview not available", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .glassSurface(cornerRadius: 12)
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
