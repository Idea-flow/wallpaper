import SwiftUI // SwiftUI 界面
import SwiftData // SwiftData 数据

// RulesView：规则管理
struct RulesView: View {
    @Environment(\.modelContext) private var modelContext // 数据上下文
    @Query(sort: \Rule.priority, order: .reverse) private var rules: [Rule] // 规则列表

    var body: some View { // 主体
        ScrollView {
            VStack(spacing: 12) {
                ForEach(rules) { rule in // 遍历规则
                    GlassRuleRow(rule: rule) // 规则行
                        .contextMenu {
                            Button("删除规则", role: .destructive) {
                                modelContext.delete(rule)
                            }
                        }
                }
            }
            .padding()
        }
        .background(Color.clear)
        .toolbar { // 工具栏
            Button { // 新建规则
                let rule = Rule() // 默认规则
                modelContext.insert(rule) // 保存
            } label: {
                Label("新建规则", systemImage: "plus") // 文案
            }
        }
    }
}

// GlassRuleRow：规则行
struct GlassRuleRow: View {
    @Bindable var rule: Rule // 可绑定规则

    var body: some View { // 主体
        VStack(alignment: .leading, spacing: 12) { // 垂直布局
            HStack { // 第一行
                Label {
                    Text("自动切换规则")
                        .font(.headline)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.blue)
                }

                Spacer()

                Toggle("", isOn: $rule.enabled) // 启用开关
                    .toggleStyle(.switch)
            }

            Divider()
                .background(.white.opacity(0.2))

            HStack { // 第二行
                Text("生效范围")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $rule.scopeRaw) { // 作用范围
                    Text("全局").tag(RuleScope.global.rawValue) // 全局
                    Text("单屏").tag(RuleScope.screen.rawValue) // 单屏
                }
                .pickerStyle(.menu) // 菜单样式更紧凑
                .frame(width: 100)
            }

            HStack {
                Text("优先级: \(rule.priority)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Slider(value: Binding(get: {
                    Double(rule.priority)
                }, set: {
                    rule.priority = Int($0)
                }), in: 0...10, step: 1)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

