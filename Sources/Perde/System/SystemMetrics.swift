import Darwin
import Foundation
import IOKit.ps

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: AnyObject, _ match: CFDictionary) -> Void

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: AnyObject) -> Unmanaged<CFArray>?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: AnyObject, _ type: Int64, _ options: Int32, _ timestamp: Int64) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: AnyObject, _ field: Int32) -> Double

enum SystemMetrics {

    struct CPUTicks {
        let used: UInt64
        let total: UInt64
    }

    struct NetCounters {
        let received: UInt64
        let sent: UInt64
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
        guard current.total > previous.total, current.used >= previous.used else { return 0 }
        let deltaTotal = current.total - previous.total
        let deltaUsed = current.used - previous.used
        return min(max(Double(deltaUsed) / Double(deltaTotal) * 100, 0), 100)
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

    static func netCounters() -> NetCounters {
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else {
            return NetCounters(received: 0, sent: 0)
        }
        defer { freeifaddrs(ifaddrPointer) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = pointer {
            let interface = current.pointee
            let name = String(cString: interface.ifa_name)
            let addressFamily = interface.ifa_addr?.pointee.sa_family
            if name != "lo0", addressFamily == UInt8(AF_LINK), let data = interface.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                received += UInt64(networkData.ifi_ibytes)
                sent += UInt64(networkData.ifi_obytes)
            }
            pointer = interface.ifa_next
        }
        return NetCounters(received: received, sent: sent)
    }

    static func netSpeed(previous: NetCounters, current: NetCounters, seconds: Double) -> (down: Double, up: Double) {
        guard seconds > 0, current.received >= previous.received, current.sent >= previous.sent else {
            return (0, 0)
        }
        let down = Double(current.received - previous.received) / seconds
        let up = Double(current.sent - previous.sent) / seconds
        return (down, up)
    }

    static func diskUsage() -> Double {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attributes[.systemSize] as? NSNumber,
              let free = attributes[.systemFreeSize] as? NSNumber,
              total.doubleValue > 0 else {
            return 0
        }
        let usedFraction = (total.doubleValue - free.doubleValue) / total.doubleValue
        return min(max(usedFraction, 0), 1)
    }

    static func cpuTemperature() -> Double? {
        let kHIDPageAppleVendor: Int32 = 0xff00
        let kHIDUsageAppleVendorTemperatureSensor: Int32 = 0x0005
        let kIOHIDEventTypeTemperature: Int64 = 15

        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue() else {
            return nil
        }

        let matching: [String: Any] = [
            "PrimaryUsagePage": kHIDPageAppleVendor,
            "PrimaryUsage": kHIDUsageAppleVendorTemperatureSensor
        ]
        IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)

        guard let services = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue() as? [AnyObject],
              !services.isEmpty else {
            return nil
        }

        var readings: [Double] = []
        let temperatureField: Int32 = Int32(kIOHIDEventTypeTemperature << 16)
        for service in services {
            guard let event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0)?.takeRetainedValue() else {
                continue
            }
            let value = IOHIDEventGetFloatValue(event, temperatureField)
            if value >= 10, value <= 110 {
                readings.append(value)
            }
        }

        guard !readings.isEmpty else { return nil }
        return readings.reduce(0, +) / Double(readings.count)
    }
}
