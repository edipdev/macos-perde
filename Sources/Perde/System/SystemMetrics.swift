import Darwin
import Foundation
import IOKit.ps

enum SystemMetrics {

    struct CPUTicks {
        let used: UInt64
        let total: UInt64
    }

    static func cpuTicks() -> CPUTicks {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return CPUTicks(used: 0, total: 0) }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        let used = user + system + nice
        return CPUTicks(used: used, total: used + idle)
    }

    static func cpuPercent(previous: CPUTicks, current: CPUTicks) -> Double {
        let dt = current.total - previous.total
        guard dt > 0 else { return 0 }
        let percent = Double(current.used - previous.used) / Double(dt) * 100
        return min(max(percent, 0), 100)
    }

    static func memoryPercent() -> Double {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let pageSize = Double(getpagesize())
        let used = Double(info.active_count + info.wire_count + info.compressor_page_count) * pageSize
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else { return 0 }
        return min(max(used / total * 100, 0), 100)
    }

    static func batteryPercent() -> Double? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: AnyObject] else { continue }
            guard let current = description[kIOPSCurrentCapacityKey] as? Double,
                  let maxCapacity = description[kIOPSMaxCapacityKey] as? Double, maxCapacity > 0 else { continue }
            return min(Swift.max((current / maxCapacity) * 100, 0), 100)
        }
        return nil
    }

    static func batteryCharging() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return false }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: AnyObject] else { continue }
            if let state = description[kIOPSPowerSourceStateKey] as? String {
                return state == kIOPSACPowerValue
            }
        }
        return false
    }
}
