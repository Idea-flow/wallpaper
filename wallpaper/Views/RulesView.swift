import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// RulesView：规则管理
struct RulesView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \Rule.priority, order: .reverse) private var rules: [Rule] // 规则列表

    var body: some View { // 主体
        List { // 列表
            ForEach(rules) { rule in // 遍历规则
                RuleRow(rule: rule) // 规则行
            }
            .onDelete(perform: deleteRules) // 删除
        }
        .toolbar { // 工具栏
            Button { // 新建规则
                let rule = Rule() // 默认规则
                modelContext.insert(rule) // 保存
            } label: {
                Label("新建规则", systemImage: "plus") // 文案
            }
        }
    }

    private func deleteRules(offsets: IndexSet) { // 删除规则
        for index in offsets { // 遍历
            modelContext.delete(rules[index]) // 删除
        }
    }
}

// RuleRow：规则行
struct RuleRow: View {
    @Bindable var rule: Rule // 可绑定规则

    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 8) { // 垂直布局
            HStack { // 第一行
                Toggle("启用", isOn: $rule.enabled) // 启用开关
                Spacer() // 占位
                Text("优先级：\(rule.priority)") // 优先级显示
            }
            HStack { // 第二行
                Text("范围") // 标签
                Picker("", selection: $rule.scopeRaw) { // 作用范围
                    Text("全局").tag(RuleScope.global.rawValue) // 全局
                    Text("单屏").tag(RuleScope.screen.rawValue) // 单屏
                }
                .pickerStyle(.segmented) // 分段样式
            }
            Stepper("优先级", value: $rule.priority, in: 0...10) // 优先级调节
        }
        .padding(.vertical, 4) // 上下间距
    }
}
