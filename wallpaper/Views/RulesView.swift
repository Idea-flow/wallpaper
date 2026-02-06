import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// RulesView：规则列表（用于中间栏）
struct RulesView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \Rule.priority, order: .reverse) private var rules: [Rule] // 规则列表

    @Binding var selectedRuleID: UUID? // 选中规则 ID

    @State private var showingCreate = false // 显示新建弹窗
    @State private var newRuleName = "" // 新规则名称
    @State private var newRuleInterval = 60 // 新规则间隔
    @State private var newRuleScope: RuleScope = .global // 新规则范围
    @State private var newRuleEnabled = true // 新规则启用

    var body: some View {
        List(selection: $selectedRuleID) {
            ForEach(rules) { rule in
                RuleListRow(rule: rule)
                    .tag(rule.id)
            }
            .onDelete(perform: deleteRules)
        }
        .toolbar {
            Button {
                newRuleName = ""
                newRuleInterval = 60
                newRuleScope = .global
                newRuleEnabled = true
                showingCreate = true
            } label: {
                Label("新建规则", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingCreate) {
            NewRuleSheet(
                name: $newRuleName,
                intervalMinutes: $newRuleInterval,
                scope: $newRuleScope,
                enabled: $newRuleEnabled
            ) {
                let rule = Rule(
                    name: newRuleName.isEmpty ? "新规则" : newRuleName,
                    scope: newRuleScope,
                    enabled: newRuleEnabled,
                    intervalMinutes: newRuleInterval
                )
                modelContext.insert(rule)
                selectedRuleID = rule.id
                showingCreate = false
            } onCancel: {
                showingCreate = false
            }
            .frame(minWidth: 420, minHeight: 320)
        }
    }

    private func deleteRules(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
    }
}

// RuleListRow：规则列表行
struct RuleListRow: View {
    @Bindable var rule: Rule

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name ?? "未命名规则")
                    .font(.headline)
                Text(rule.enabled ? "已启用" : "已停用")
                    .font(.caption)
                    .foregroundStyle(rule.enabled ? .green : .secondary)
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            HStack(spacing: 12) {
                Text("启用")
                Toggle("", isOn: $rule.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .glassCapsuleBackground()
        }
        .padding(.vertical, 4)
    }
}

// RuleSummaryView：规则摘要（保留可复用）
struct RuleSummaryView: View {
    @Bindable var rule: Rule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rule.name ?? "未命名规则").font(.title2)
            Text("范围：\(rule.scope == .global ? "全局" : "单屏")")
            Text("切换间隔：\(rule.intervalMinutes ?? 60) 分钟")
            Text("随机策略：\(rule.randomStrategyRaw)")
            Text("视频比例：\(Int(rule.mediaMixRatio * 100))%")
            Spacer()
        }
        .padding()
    }
}

// RuleDetailView：规则详细配置
struct RuleDetailView: View {
    @Bindable var rule: Rule
    let albums: [Album]
    private let allAlbumID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("规则名称", text: nameBinding)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Text("启用规则")
                    Spacer(minLength: 12)
                    Toggle("", isOn: $rule.enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .glassCapsuleBackground()

                HStack {
                    Text("切换间隔")
                    Spacer()
                    Stepper("\(rule.intervalMinutes ?? 60) 分钟", value: intervalBinding, in: 5...1440, step: 5)
                }

                HStack {
                    Text("范围")
                    Picker("", selection: $rule.scopeRaw) {
                        Text("全局").tag(RuleScope.global.rawValue)
                        Text("单屏").tag(RuleScope.screen.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .padding(4)
                    .glassControl(cornerRadius: 10)
                }

                if rule.scope == .screen {
                    HStack {
                        Text("屏幕")
                        Picker("", selection: Binding(
                            get: { rule.screenID ?? "" },
                            set: { rule.screenID = $0.isEmpty ? nil : $0 }
                        )) {
                            ForEach(ScreenHelper.screenOptions()) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                    }
                }

                HStack {
                    Text("相册")
                    Picker("", selection: Binding(
                        get: { rule.album?.id ?? allAlbumID },
                        set: { newValue in
                            rule.album = newValue == allAlbumID ? nil : albums.first { $0.id == newValue }
                        }
                    )) {
                        Text("全部素材").tag(allAlbumID)
                        ForEach(albums) { album in
                            Text(album.name).tag(album.id)
                        }
                    }
                    .padding(4)
                    .glassControl(cornerRadius: 10)
                }

                WeekdayPicker(selected: Binding(
                    get: { Set(rule.weekdays) },
                    set: { rule.weekdays = Array($0).sorted() }
                ))

                TimeRangePicker(
                    startMinutes: $rule.startMinutes,
                    endMinutes: $rule.endMinutes
                )

                HStack {
                    Text("随机策略")
                    Picker("", selection: $rule.randomStrategyRaw) {
                        Text("均匀").tag(RandomStrategy.uniform.rawValue)
                        Text("权重").tag(RandomStrategy.weighted.rawValue)
                        Text("避免近期重复").tag(RandomStrategy.avoidRecent.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .padding(4)
                    .glassControl(cornerRadius: 10)
                }

                HStack {
                    Text("视频比例")
                    Slider(value: $rule.mediaMixRatio, in: 0...1, step: 0.1)
                    Text(String(format: "%.0f%%", rule.mediaMixRatio * 100))
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .padding()
        }
    }
}

// NewRuleSheet：新建规则弹窗
struct NewRuleSheet: View {
    @Binding var name: String
    @Binding var intervalMinutes: Int
    @Binding var scope: RuleScope
    @Binding var enabled: Bool

    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建规则")
                .font(.title2)

            TextField("规则名称", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Text("启用规则")
                Spacer(minLength: 12)
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .glassCapsuleBackground()

            HStack {
                Text("切换间隔")
                Spacer()
                Stepper("\(intervalMinutes) 分钟", value: $intervalMinutes, in: 5...1440, step: 5)
            }

            HStack {
                Text("范围")
                Picker("", selection: $scope) {
                    Text("全局").tag(RuleScope.global)
                    Text("单屏").tag(RuleScope.screen)
                }
                .pickerStyle(.segmented)
                .padding(4)
                .glassControl(cornerRadius: 10)
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                Button("创建") { onCreate() }
                    .glassActionButtonStyle()
            }
        }
        .padding(20)
        .glassSurface(cornerRadius: 16)
        .padding()
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
                    .background {
                        if isSelected {
                            if #available(macOS 26, *) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                        }
                    }
                    .onTapGesture {
                        toggle(day)
                    }
                    .animation(Glass.animation, value: isSelected)
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
            .glassActionButtonStyle()
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

extension RuleDetailView {
    private var nameBinding: Binding<String> {
        Binding(
            get: { rule.name ?? "新规则" },
            set: { rule.name = $0.isEmpty ? "新规则" : $0 }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { rule.intervalMinutes ?? 60 },
            set: { rule.intervalMinutes = $0 }
        )
    }
}
