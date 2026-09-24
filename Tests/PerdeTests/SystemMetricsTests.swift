import XCTest
@testable import Perde

final class SystemMetricsTests: XCTestCase {
    func testCpuPercentComputesUsageRatio() {
        let previous = SystemMetrics.CPUTicks(used: 100, total: 200)
        let current = SystemMetrics.CPUTicks(used: 150, total: 300)
        XCTAssertEqual(SystemMetrics.cpuPercent(previous: previous, current: current), 50)
    }

    func testCpuPercentReturnsZeroForZeroDelta() {
        let ticks = SystemMetrics.CPUTicks(used: 100, total: 200)
        XCTAssertEqual(SystemMetrics.cpuPercent(previous: ticks, current: ticks), 0)
    }
}
