import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// RulesView：规则管理
struct RulesView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \Rule.priority, order: .reverse) private var rules: [Rule] // 规则列表
    @Query(sort: \Album.name, order: .forward) private var albums: [Album] // 相册列表

    @State private var editingRule: Rule? // 当前正在编辑的规则
    @State private var showingAddSheet = false

    // 自适应网格布局
    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 500), spacing: 16)
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(rules) { rule in
                        GlassRuleCard(rule: rule)
                            .onTapGesture {
                                editingRule = rule
                            }
                            .contextMenu {
                                Button("编辑") { editingRule = rule }
                                Divider()
                                Button("删除", role: .destructive) {
                                    deleteRule(rule)
                                }
                            }
                    }

                    // 添加按钮卡片
                    Button {
                        let newRule = Rule()
                        newRule.name = "新规则 \(rules.count + 1)"
                        modelContext.insert(newRule)
                        editingRule = newRule
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("创建新规则")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180) // 与卡片高度大致一致
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundStyle(.secondary.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color.clear) // 透明背景以展示壁纸/模糊
        .sheet(item: $editingRule) { rule in
            RuleEditorView(rule: rule, albums: albums)
                .frame(minWidth: 500, minHeight: 600)
        }
        .toolbar {
            Button(action: {
                let newRule = Rule()
                // 默认值
                newRule.name = "新规则 \(rules.count + 1)"
                modelContext.insert(newRule)
                editingRule = newRule
            }) {
                Label("新建规则", systemImage: "plus")
            }
        }
    }

    private func deleteRule(_ rule: Rule) {
        modelContext.delete(rule)
        try? modelContext.save()
    }
}

// 玻璃拟态规则卡片
struct GlassRuleCard: View {
    @Bindable var rule: Rule

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部：图标+名称+开关
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(rule.enabled ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: rule.enabled ? "clock.arrow.circlepath" : "pause.circle")
                        .font(.title2)
                        .foregroundStyle(rule.enabled ? .blue : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name ?? "未命名规则")
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(rule.enabled ? "运行中" : "已暂停")
                        .font(.caption)
                        .foregroundStyle(rule.enabled ? .green : .secondary)
                }

                Spacer()

                Toggle("", isOn: $rule.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()
                .background(.white.opacity(0.2))

            // 信息网格
            HStack(spacing: 20) {
                LabelInfoItem(
                    icon: "arrow.triangle.2.circlepath",
                    title: "间隔",
                    value: formatInterval(rule.intervalMinutes)
                )

                LabelInfoItem(
                    icon: rule.scope == .global ? "globe" : "display",
                    title: "范围",
                    value: rule.scope == .global ? "全局" : "单屏"
                )

                LabelInfoItem(
                    icon: "shuffle",
                    title: "策略",
                    value: rule.randomStrategyRaw == "uniform" ? "均匀" : "权重"
                )
            }

            // 底部：优先级
            HStack {
                Text("优先级")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 简单的进度条表示优先级
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(Color.blue.gradient)
                            .frame(width: geo.size.width * (CGFloat(rule.priority) / 10.0))
                    }
                }
                .frame(height: 6)

                Text("\(rule.priority)")
                    .font(.caption)
                    .monospacedDigit()
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .contentShape(Rectangle()) // 确保整个区域可点击
    }

    private func formatInterval(_ minutes: Int?) -> String {
        guard let minutes = minutes else { return "1小时" }
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            return String(format: "%.1f小时", Double(minutes) / 60.0)
        }
    }
}

struct LabelInfoItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

// 规则编辑器
struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var rule: Rule
    let albums: [Album]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 基础信息
                    GlassSectionWrapper(title: "基础设置", icon: "gearshape.fill") {
                        TextField("规则名称", text: Binding(
                            get: { rule.name ?? "" },
                            set: { rule.name = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.white.opacity(0.1))
                        .cornerRadius(8)

                        Toggle("启用规则", isOn: $rule.enabled)

                        Divider().background(.white.opacity(0.1))

                        HStack {
                            Text("优先级 (0-10)")
                            Spacer()
                            Text("\(rule.priority)")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(rule.priority) },
                            set: { rule.priority = Int($0) }
                        ), in: 0...10, step: 1)
                    }

                    // 触发条件
                    GlassSectionWrapper(title: "触发条件", icon: "timer") {
                        HStack {
                            Text("切换间隔")
                            Spacer()
                            Stepper("\(rule.intervalMinutes ?? 60) 分钟", value: Binding(
                                get: { rule.intervalMinutes ?? 60 },
                                set: { rule.intervalMinutes = $0 }
                            ), in: 5...1440, step: 5)
                        }

                        Divider().background(.white.opacity(0.1))

                        TimeRangePicker(
                            startMinutes: $rule.startMinutes,
                            endMinutes: $rule.endMinutes
                        )

                        Divider().background(.white.opacity(0.1))

                        WeekdayPicker(selected: Binding(
                            get: { Set(rule.weekdays) },
                            set: { rule.weekdays = Array($0).sorted() }
                        ))
                    }

                    // 作用域
                    GlassSectionWrapper(title: "作用范围 & 内容", icon: "photo.stack") {
                        Picker("模式", selection: $rule.scopeRaw) {
                            Text("全局联动").tag(RuleScope.global.rawValue)
                            Text("独立屏幕").tag(RuleScope.screen.rawValue)
                        }
                        .pickerStyle(.segmented)

                        if rule.scope == .screen {
                            Picker("选择屏幕", selection: Binding(
                                get: { rule.screenID ?? "" },
                                set: { rule.screenID = $0.isEmpty ? nil : $0 }
                            )) {
                                Text("未选择").tag("")
                                ForEach(ScreenHelper.screenOptions()) { option in
                                    Text(option.title).tag(option.id)
                                }
                            }
                        }

                        Divider().background(.white.opacity(0.1))

                        Picker("素材来源 (相册)", selection: Binding(
                            get: { rule.album?.id },
                            set: { id in
                                if let id {
                                    rule.album = albums.first { $0.id == id }
                                } else {
                                    rule.album = nil
                                }
                            }
                        )) {
                            Text("所有导入素材").tag(Optional<UUID>.none)
                            ForEach(albums) { album in
                                Text(album.name).tag(Optional<UUID>.some(album.id))
                            }
                        }
                    }

                    // 播放策略
                    GlassSectionWrapper(title: "播放策略", icon: "shuffle") {
                        Picker("随机算法", selection: $rule.randomStrategyRaw) {
                            Text("完全随机").tag(RandomStrategy.uniform.rawValue)
                            Text("加权随机").tag(RandomStrategy.weighted.rawValue)
                            Text("避免重复").tag(RandomStrategy.avoidRecent.rawValue)
                        }
                        .pickerStyle(.segmented)

                        Divider().background(.white.opacity(0.1))

                        VStack(alignment: .leading) {
                            HStack {
                                Text("视频/图片 混合比例")
                                Spacer()
                                Text(String(format: "%.0f%% 视频", rule.mediaMixRatio * 100))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $rule.mediaMixRatio, in: 0...1, step: 0.1) {
                                Text("Ratio")
                            } minimumValueLabel: {
                                Image(systemName: "photo")
                            } maximumValueLabel: {
                                Image(systemName: "film")
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle(rule.name ?? "编辑规则")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .background(.thinMaterial)
        }
        .presentationBackground(.ultraThinMaterial) // 弹窗背景也是毛玻璃
    }
}

// 辅助组件 GlassSectionWrapper
struct GlassSectionWrapper<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .font(.headline)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.05)) // 稍微深一点的背景区分层级
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// WeekdayPicker：工作日选择
struct WeekdayPicker: View {
    let selected: Binding<Set<Int>> // 选中集合（1-7）
    private let symbols = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    var body: some View {
        HStack {
            Text("工作日")
            ForEach(1...7, id: \.self) { day in
                let isSelected = selected.wrappedValue.contains(day)
                Text(symbols[day - 1])
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture {
                        toggle(day)
                    }
            }
        }
    }

    private func toggle(_ day: Int) {
        var set = selected.wrappedValue
        if set.contains(day) {
            set.remove(day)
        } else {
            set.insert(day)
        }
        selected.wrappedValue = set
    }
}

// TimeRangePicker：时间范围选择
struct TimeRangePicker: View {
    @Binding var startMinutes: Int?
    @Binding var endMinutes: Int?

    var body: some View {
        HStack {
            Text("时间段")
            DatePicker("开始", selection: startBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
            DatePicker("结束", selection: endBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
            Button("清除") {
                startMinutes = nil
                endMinutes = nil
            }
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { minutesToDate(startMinutes ?? 9 * 60) },
            set: { startMinutes = dateToMinutes($0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { minutesToDate(endMinutes ?? 18 * 60) },
            set: { endMinutes = dateToMinutes($0) }
        )
    }

    private func minutesToDate(_ minutes: Int) -> Date {
        let calendar = Calendar.current
        let hour = minutes / 60
        let minute = minutes % 60
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func dateToMinutes(_ date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
