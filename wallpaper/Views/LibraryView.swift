import AppKit // NSEvent
import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// LibraryView：素材库列表与筛选
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var items: [MediaItem] // 素材列表

    @Binding var selectionIDs: Set<UUID> // 选中素材 ID 集合
    @Binding var focusedItemID: UUID? // 当前详情素材
    @Binding var searchText: String // 搜索文本
    @Binding var filterType: MediaType? // 类型筛选
    @Binding var showFavoritesOnly: Bool // 仅收藏

    let onImport: () -> Void // 导入回调
    let onApply: (MediaItem) -> Void // 设置壁纸回调
    @State private var showingTagEditor = false // 是否显示标签弹窗
    @State private var tagInput = "" // 标签输入
    @State private var viewMode: ViewMode = .grid // 视图模式

    // ViewMode：视图模式
    private enum ViewMode: String { // 可选类型
        case grid // 网格
        case list // 列表
    }

    // 基准单元宽度
    private let cardMinWidth: CGFloat = 190

    var body: some View { // 主体
        Group {
            if viewMode == .grid { // 网格模式
                GeometryReader { geometry in
                    let columns = gridColumns(for: geometry.size.width)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredItems) { item in
                                Button {
                                    handleSelection(item)
                                } label: {
                                    MediaCard(item: item, isSelected: selectionIDs.contains(item.id))
                                        .frame(minWidth: cardMinWidth)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("设为壁纸") {
                                        onApply(item)
                                    }
                                    Button("标记收藏") {
                                        item.isFavorite.toggle()
                                        try? modelContext.save()
                                    }
                                    Button("删除", role: .destructive) {
                                        modelContext.delete(item)
                                        try? modelContext.save()
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .scrollIndicators(.hidden)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .background(Color.clear) // 确保背景透明以透出 Liquid Glass 效果
            } else { // 列表模式
                List(selection: $selectionIDs) {
                    ForEach(filteredItems) { item in
                        MediaRow(item: item)
                            .tag(item.id)
                    }
                    .onDelete(perform: deleteItems)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .scrollIndicators(.hidden)
            }
        }
        .animation(Glass.animation, value: selectionIDs)
        .onChange(of: selectionIDs) { _, newValue in // 同步详情选择
            if newValue.isEmpty {
                focusedItemID = nil
            } else if newValue.count == 1 {
                focusedItemID = newValue.first
            } else if let current = focusedItemID, newValue.contains(current) {
                // 保留当前焦点
            } else {
                focusedItemID = newValue.first
            }
        }
        .searchable(text: $searchText, prompt: "搜索文件名/标签") // 搜索框
        .toolbar { // 工具栏
            Button { // 导入按钮
                onImport() // 触发导入
            } label: {
                Label("导入素材", systemImage: "plus") // 文案
            }

            Picker("视图", selection: $viewMode) {
                Text("网格").tag(ViewMode.grid)
                Text("列表").tag(ViewMode.list)
            }
            .pickerStyle(.segmented)

            if !selectionIDs.isEmpty { // 有选择时显示批量操作
                Menu { // 批量操作菜单
                    Button("标记收藏") { // 收藏
                        applyFavorite(true) // 应用
                    }
                    Button("取消收藏") { // 取消收藏
                        applyFavorite(false) // 应用
                    }
                    Menu("评分") { // 评分子菜单
                        ForEach(0..<6, id: \.self) { value in // 0-5
                            Button("评分 \(value)") { // 设置评分
                                applyRating(value) // 应用评分
                            }
                        }
                    }
                    Button("设置标签...") { // 设置标签
                        showingTagEditor = true // 打开弹窗
                    }
                    Button("清空标签") { // 清空标签
                        applyTags("") // 清空
                    }
                } label: {
                    Label("批量操作", systemImage: "square.grid.3x3") // 文案
                }
            }

            Menu { // 筛选菜单
                Button { // 所有类型
                    filterType = nil // 清空筛选
                } label: {
                    filterMenuLabel("全部类型", selected: filterType == nil) // 文案
                }
                Button { // 仅图片
                    filterType = .image // 过滤图片
                } label: {
                    filterMenuLabel("仅图片", selected: filterType == .image) // 文案
                }
                Button { // 仅视频
                    filterType = .video // 过滤视频
                } label: {
                    filterMenuLabel("仅视频", selected: filterType == .video) // 文案
                }
                Divider() // 分隔线
                Button { // 仅收藏
                    showFavoritesOnly.toggle() // 切换收藏过滤
                } label: {
                    filterMenuLabel("仅收藏", selected: showFavoritesOnly) // 文案
                }
            } label: {
                Label("筛选", systemImage: "line.3.horizontal.decrease.circle") // 图标
            }
        }
        .alert("设置标签", isPresented: $showingTagEditor) { // 标签弹窗
            TextField("标签（逗号分隔）", text: $tagInput) // 输入框
            Button("应用") { // 应用
                applyTags(tagInput) // 应用标签
                tagInput = "" // 清空
            }
            Button("取消", role: .cancel) { } // 取消
        } message: {
            Text("将标签应用到已选择素材") // 提示
        }
    }

    private var filteredItems: [MediaItem] { // 过滤结果
        items.filter { item in // 过滤逻辑
            if let filterType { // 类型过滤
                if item.type != filterType { return false } // 不匹配
            }
            if showFavoritesOnly { // 仅收藏
                if !item.isFavorite { return false } // 非收藏
            }
            if searchText.isEmpty { // 无搜索
                return true // 通过
            }
            let nameMatch = item.fileURL.lastPathComponent.localizedStandardContains(searchText) // 文件名匹配
            let tagMatch = item.tags.localizedStandardContains(searchText) // 标签匹配
            return nameMatch || tagMatch // 返回
        }
    }

    private func filterMenuLabel(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 120)
    }

    private func deleteItems(offsets: IndexSet) { // 删除
        for index in offsets { // 遍历
            modelContext.delete(filteredItems[index]) // 删除对象
        }
    }

    private var selectedItems: [MediaItem] { // 选中素材
        items.filter { selectionIDs.contains($0.id) } // 过滤选中
    }

    private func applyFavorite(_ value: Bool) { // 批量收藏
        for item in selectedItems { // 遍历
            item.isFavorite = value // 设置
        }
        try? modelContext.save() // 保存
    }

    private func applyRating(_ value: Int) { // 批量评分
        for item in selectedItems { // 遍历
            item.rating = value // 设置评分
        }
        try? modelContext.save() // 保存
    }

    private func applyTags(_ tags: String) { // 批量标签
        for item in selectedItems { // 遍历
            item.tags = tags // 设置标签
        }
        try? modelContext.save() // 保存
    }

    private func handleSelection(_ item: MediaItem) {
        if NSEvent.modifierFlags.contains(.command) {
            // Command+Click: 切换当前项选中状态
            if selectionIDs.contains(item.id) {
                selectionIDs.remove(item.id)
            } else {
                selectionIDs.insert(item.id)
                focusedItemID = item.id
            }
        } else {
            // 普通点击: 单选
            selectionIDs = [item.id]
            focusedItemID = item.id
        }
    }

    private func gridColumns(for width: CGFloat) -> [GridItem] {
        let usableWidth = max(width - 32, cardMinWidth)
        let count = max(Int(usableWidth / cardMinWidth), 1)
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }
}
