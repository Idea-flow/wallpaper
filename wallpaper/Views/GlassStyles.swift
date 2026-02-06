import SwiftUI // SwiftUI 界面

// Glass：统一玻璃风格与动画
enum Glass {
    static let cornerRadius: CGFloat = 14
    static let controlRadius: CGFloat = 12
    static let selectionRadius: CGFloat = 16
    static let selectionWidth: CGFloat = 2
    static let outlineWidth: CGFloat = 0.8
    static let animation: Animation = .easeInOut(duration: 0.2)
}

// View 扩展：统一 Liquid Glass 样式
extension View {
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = Glass.cornerRadius, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        }
    }

    func glassPanel(cornerRadius: CGFloat = Glass.cornerRadius) -> some View {
        self.glassSurface(cornerRadius: cornerRadius, interactive: false)
    }

    func glassControl(cornerRadius: CGFloat = Glass.controlRadius) -> some View {
        self.glassSurface(cornerRadius: cornerRadius, interactive: true)
    }

    func glassSelectionRing(_ isSelected: Bool, cornerRadius: CGFloat = Glass.selectionRadius) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: Glass.selectionWidth)
        )
        .animation(Glass.animation, value: isSelected)
    }

    func glassOutline(cornerRadius: CGFloat = Glass.cornerRadius) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.accentColor.opacity(0.35), lineWidth: Glass.outlineWidth)
        )
    }

    @ViewBuilder
    func glassCapsuleBackground() -> some View {
        if #available(macOS 26, *) {
            self
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func glassActionButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(GlassButtonStyle())
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(configuration.isPressed ? .thickMaterial : .regularMaterial)
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Glass.animation, value: configuration.isPressed)
    }
}
