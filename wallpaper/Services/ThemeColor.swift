import AppKit // 使用 NSColor
import SwiftUI // 使用 Color

// ThemeColor：主题颜色工具
struct ThemeColor {
    static let defaultHex = "#0A84FF" // 默认蓝色

    // color(from:)：将十六进制字符串转换为 Color
    static func color(from hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) // 清理字符
        let scanner = Scanner(string: cleaned) // 扫描器
        var value: UInt64 = 0 // 数值
        scanner.scanHexInt64(&value) // 读取十六进制

        let r, g, b, a: UInt64 // RGBA
        switch cleaned.count { // 根据长度判断
        case 6: // RRGGBB
            (r, g, b, a) = (value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF, 0xFF) // 拆分
        case 8: // AARRGGBB
            (a, r, g, b) = (value >> 24 & 0xFF, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF) // 拆分
        default:
            return Color.blue // 回退颜色
        }

        return Color(
            .sRGB, // 色彩空间
            red: Double(r) / 255.0, // R
            green: Double(g) / 255.0, // G
            blue: Double(b) / 255.0, // B
            opacity: Double(a) / 255.0 // A
        )
    }

    // hex(from:)：将 Color 转换为十六进制字符串
    static func hex(from color: Color) -> String {
        let nsColor = NSColor(color) // 转换为 NSColor
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { // 转换到 RGB
            return defaultHex // 回退
        }

        let r = Int(round(rgb.redComponent * 255)) // R
        let g = Int(round(rgb.greenComponent * 255)) // G
        let b = Int(round(rgb.blueComponent * 255)) // B
        let a = Int(round(rgb.alphaComponent * 255)) // A
        return String(format: "#%02X%02X%02X%02X", a, r, g, b) // AARRGGBB
    }
}
