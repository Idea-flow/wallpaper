import AppKit // 屏幕信息

// ScreenOption：屏幕选项
struct ScreenOption: Identifiable { // 可识别
    let id: String // 屏幕 ID
    let title: String // 显示名称
}

// ScreenHelper：屏幕相关工具
struct ScreenHelper { // 工具结构
    // screenOptions：生成屏幕选项
    static func screenOptions() -> [ScreenOption] { // 返回屏幕列表
        NSScreen.screens.map { screen in // 遍历屏幕
            let id = screenIdentifier(screen) // 屏幕 ID
            let title = "\(screen.localizedName) · \(id)" // 显示名称
            return ScreenOption(id: id, title: title) // 返回选项
        }
    }

    // screenByID：通过 ID 找到屏幕
    static func screenByID(_ id: String) -> NSScreen? { // 通过 ID 查找
        NSScreen.screens.first { screenIdentifier($0) == id } // 匹配 ID
    }

    // screenIdentifier：获取屏幕唯一 ID
    static func screenIdentifier(_ screen: NSScreen) -> String { // 屏幕 ID
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber { // 读取编号
            return number.stringValue // 返回编号
        }
        return screen.localizedName // 回退到名称
    }
}
