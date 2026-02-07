import Foundation
import Combine
import MachO

// PerformanceMonitor：采集本进程性能信息（CPU/内存/PID/运行时长）
final class PerformanceMonitor: ObservableObject {
    @Published private(set) var pid: Int32 = getpid()
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryBytes: UInt64 = 0
    @Published private(set) var uptimeSeconds: TimeInterval = 0

    private var timer: Timer?
    private let updateInterval: TimeInterval = 1

    func start() {
        stop()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        pid = getpid()
        cpuUsage = currentCPUUsage()
        memoryBytes = currentMemoryUsage()
        uptimeSeconds = ProcessInfo.processInfo.systemUptime
    }
}

private func currentCPUUsage() -> Double {
    var threadList: thread_act_array_t?
    var threadCount: mach_msg_type_number_t = 0
    let task = mach_task_self_

    let result = task_threads(task, &threadList, &threadCount)
    guard result == KERN_SUCCESS, let threadList else { return 0 }
    defer { vm_deallocate(task, vm_address_t(bitPattern: threadList), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size)) }

    var totalCPU: Double = 0
    for i in 0..<Int(threadCount) {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(THREAD_INFO_MAX)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_info(threadList[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
            }
        }
        if kr == KERN_SUCCESS, (info.flags & TH_FLAGS_IDLE) == 0 {
            totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
        }
    }
    return totalCPU
}

private func currentMemoryUsage() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    if kr == KERN_SUCCESS {
        return info.phys_footprint
    }
    return 0
}
