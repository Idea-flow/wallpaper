import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// AlbumsView：相册列表
struct AlbumsView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \Album.name, order: .forward) private var albums: [Album] // 相册列表

    @Binding var selectedAlbumID: UUID? // 选中相册 ID

    @State private var showingCreate = false // 是否显示创建弹窗
    @State private var newAlbumName = "" // 新相册名称

    var body: some View { // 主体
        List(selection: $selectedAlbumID) { // 列表
            ForEach(albums) { album in // 遍历相册
                Text(album.name) // 相册名称
                    .tag(album.id) // 绑定选择
            }
            .onDelete(perform: deleteAlbums) // 删除
        }
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

    private func deleteAlbums(offsets: IndexSet) { // 删除相册
        for index in offsets { // 遍历
            modelContext.delete(albums[index]) // 删除
        }
    }
}

// AlbumDetailView：相册详情
struct AlbumDetailView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var allItems: [MediaItem] // 所有素材

    let album: Album // 当前相册

    @State private var showingAddSheet = false // 是否显示添加素材
    @State private var selectedItemIDs = Set<UUID>() // 选择的素材 ID

    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 12) { // 垂直布局
            HStack { // 顶部栏
                Text(album.name) // 相册标题
                    .font(.title2) // 字体
                Spacer() // 占位
                Button("添加素材") { // 添加按钮
                    selectedItemIDs = [] // 清空选择
                    showingAddSheet = true // 打开弹窗
                }
            }

            if album.items.isEmpty { // 空相册
                ContentUnavailableView("相册为空", systemImage: "rectangle.stack") // 占位
            } else {
                List { // 列表
                    ForEach(album.items) { item in // 遍历素材
                        MediaRow(item: item) // 行
                    }
                    .onDelete(perform: removeItems) // 删除
                }
            }
        }
        .padding() // 内边距
        .sheet(isPresented: $showingAddSheet) { // 添加素材弹窗
            NavigationStack { // 导航
                List(allItems, selection: $selectedItemIDs) { item in // 列表
                    MediaRow(item: item) // 行
                        .tag(item.id) // 绑定
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

    private func addSelectedItems() { // 添加素材
        let selected = allItems.filter { selectedItemIDs.contains($0.id) } // 找到选中
        for item in selected { // 遍历
            if !album.items.contains(where: { $0.id == item.id }) { // 避免重复
                album.items.append(item) // 添加
            }
        }
        try? modelContext.save() // 保存
    }

    private func removeItems(offsets: IndexSet) { // 删除素材
        for index in offsets { // 遍历
            album.items.remove(at: index) // 移除
        }
        try? modelContext.save() // 保存
    }
}
