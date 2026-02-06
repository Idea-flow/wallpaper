import ServiceManagement // 开机自启

// AutoLaunchService：管理开机自启
struct AutoLaunchService {
    // isEnabled：当前是否启用
    static func isEnabled() -> Bool {
        switch SMAppService.mainApp.status { // 读取状态
        case .enabled:
            return true // 已启用
        case .requiresApproval:
            return false // 需要用户批准
        default:
            return false // 未启用或未注册
        }
    }

    // setEnabled：启用/关闭开机自启
    static func setEnabled(_ enabled: Bool) throws {
        if enabled { // 启用
            try SMAppService.mainApp.register() // 注册
        } else { // 关闭
            try SMAppService.mainApp.unregister() // 取消注册
        }
    }
}
