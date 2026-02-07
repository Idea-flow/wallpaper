import Foundation // 基础能力
import Observation // @Observable

// LogLevel：日志级别
enum LogLevel: String, CaseIterable, Identifiable { // 日志级别枚举
    case info = "信息" // 信息
    case warning = "警告" // 警告
    case error = "错误" // 错误

    var id: String { rawValue } // 唯一标识
}

// LogEntry：单条日志
struct LogEntry: Identifiable, Hashable { // 日志模型
    let id = UUID() // 唯一 ID
    let date: Date // 时间
    let level: LogLevel // 级别
    let message: String // 内容
}

// LogCenter：全局日志中心（内存保存）
@MainActor
@Observable
final class LogCenter { // 日志中心
    static let shared = LogCenter() // 单例
    private(set) var entries: [LogEntry] = [] // 日志列表
    private let maxCount = 2000 // 最大条数

    // log：写入日志（供外部调用）
    static func log(_ message: String, level: LogLevel = .info) { // 写入日志
        NSLog(message) // 同步到系统日志
        Task { @MainActor in // 切回主线程
            shared.append(message: message, level: level) // 写入内存
        }
    }

    // clear：清空日志
    func clear() { // 清空
        entries.removeAll() // 清空列表
    }

    private func append(message: String, level: LogLevel) { // 内部写入
        let entry = LogEntry(date: Date(), level: level, message: message) // 创建日志
        entries.insert(entry, at: 0) // 头插
        if entries.count > maxCount { // 超限
            entries.removeLast(entries.count - maxCount) // 删除多余
        }
    }
}
