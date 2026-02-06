import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// AlbumsView：相册列表
struct AlbumsView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \Album.name, order: .forward) private var albums: [Album] // 相册列表

    @Binding var selectedAlbumID: UUID? // 选中相册 ID

    @State private var showingCreate = false // 是否显示创建弹窗
    @State private var newAlbumName = "" // 新相册名称

    // 定义网格列布局
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)
    ]

    var body: some View { // 主体
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(albums) { album in
                    AlbumCard(album: album, isSelected: selectedAlbumID == album.id)
                        .onTapGesture {
                            selectedAlbumID = album.id
                        }
                        .contextMenu {
                            Button("删除相册", role: .destructive) {
                                modelContext.delete(album)
                            }
                        }
                }
            }
            .padding()
        }
        .background(Color.clear)
        .toolbar { // 工具栏
            Button { // 新建相册
                newAlbumName = "" // 清空名称
                showingCreate = true // 打开弹窗
            } label: {
                Label("新建相册", systemImage: "plus") // 文案
            }
        }
        .alert("新建相册", isPresented: $showingCreate) { // 弹窗
            TextField("相册名称", text: $newAlbumName) // 输入框
            Button("创建") { // 创建按钮
                createAlbum() // 创建
            }
            Button("取消", role: .cancel) { } // 取消
        } message: {
            Text("请输入相册名称") // 提示
        }
    }

    private func createAlbum() { // 创建相册
        let name = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines) // 去空格
        guard !name.isEmpty else { return } // 不能为空
        let album = Album(name: name) // 新建相册
        modelContext.insert(album) // 保存
        selectedAlbumID = album.id // 选中
    }
}

// AlbumCard: 玻璃拟态相册卡片
struct AlbumCard: View {
    let album: Album
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(.quaternary)

                if let firstItem = album.items.first {
                    // 显示封面（第一张图）
                     // 这里简单复用 ThumbnailLogic，实际可以抽离
                    if firstItem.type == .image, let image = MediaAccessService.loadImageResult(for: firstItem).image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: firstItem.type == .video ? "film" : "photo")
                             .font(.largeTitle)
                             .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }

                // 选中状态
                if isSelected {
                    ContainerRelativeShape()
                        .inset(by: -2)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(album.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(album.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// AlbumDetailView：相册详情
struct AlbumDetailView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var allItems: [MediaItem] // 所有素材

    let album: Album // 当前相册

    @State private var showingAddSheet = false // 是否显示添加素材
    @State private var selectedItemIDs = Set<UUID>() // 选择的素材 ID
    @State private var viewMode: ViewMode = .grid // 视图模式

    // 复用网格配置
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)
    ]

    private enum ViewMode: String { // 视图模式
        case grid // 网格
        case list // 列表
    }

    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 12) { // 垂直布局
            headerBar // 顶部栏
            contentSection // 内容区
        }
        .padding() // 内边距
        .sheet(isPresented: $showingAddSheet) { // 添加素材弹窗
            NavigationStack { // 导航
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(allItems) { item in
                            MediaCard(item: item, isSelected: selectedItemIDs.contains(item.id))
                                .onTapGesture {
                                    if selectedItemIDs.contains(item.id) {
                                        selectedItemIDs.remove(item.id)
                                    } else {
                                        selectedItemIDs.insert(item.id)
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .navigationTitle("选择素材") // 标题
                .toolbar { // 工具栏
                    Button("取消") { // 取消
                        showingAddSheet = false // 关闭
                    }
                    Button("添加") { // 添加
                        addSelectedItems() // 添加
                        showingAddSheet = false // 关闭
                    }
                }
            }
            .frame(minWidth: 520, minHeight: 420) // 弹窗尺寸
        }
    }

    private var headerBar: some View { // 顶部栏
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(album.name)
                    .font(.title2)
                Text("共 \(album.items.count) 项")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("视图", selection: $viewMode) {
                Text("网格").tag(ViewMode.grid)
                Text("列表").tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .padding(4)
            .glassControl(cornerRadius: 10)
            Button {
                selectedItemIDs = []
                showingAddSheet = true
            } label: {
                Label("添加素材", systemImage: "plus")
            }
            .glassActionButtonStyle()
        }
    }

    @ViewBuilder
    private var contentSection: some View { // 内容区
        if album.items.isEmpty {
            ContentUnavailableView("相册为空", systemImage: "rectangle.stack")
        } else {
            switch viewMode {
            case .grid:
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(album.items) { item in
                            MediaCard(item: item, isSelected: false)
                                .contextMenu {
                                    Button("移出相册", role: .destructive) {
                                        removeFromAlbum(item)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            case .list:
                List {
                    ForEach(album.items) { item in
                        HStack(spacing: 12) {
                            ThumbnailView(item: item)
                                .frame(width: 48, height: 36)
                                .clipShape(.rect(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.fileURL.lastPathComponent)
                                    .lineLimit(1)
                                Text(item.type == .video ? "视频" : "图片")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.isFavorite {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .contextMenu {
                            Button("移出相册", role: .destructive) {
                                removeFromAlbum(item)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func removeFromAlbum(_ item: MediaItem) {
        if let index = album.items.firstIndex(where: { $0.id == item.id }) {
            album.items.remove(at: index)
            try? modelContext.save()
        }
    }

    private func addSelectedItems() {
        let selected = allItems.filter { selectedItemIDs.contains($0.id) }
        for item in selected {
            if !album.items.contains(where: { $0.id == item.id }) {
                album.items.append(item)
            }
        }
        try? modelContext.save()
    }

}
