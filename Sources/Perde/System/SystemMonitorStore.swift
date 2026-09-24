import Foundation

@MainActor
final class SystemMonitorStore: ObservableObject {
    @Published private(set) var cpu: Double = 0
    @Published private(set) var memory: Double = 0
    @Published private(set) var battery: Double? = nil
    @Published private(set) var charging = false

    private var previous = SystemMetrics.cpuTicks()
    private var timer: Timer?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        sample()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        started = false
    }

    private func sample() {
        let now = SystemMetrics.cpuTicks()
        cpu = SystemMetrics.cpuPercent(previous: previous, current: now)
        previous = now
        memory = SystemMetrics.memoryPercent()
        battery = SystemMetrics.batteryPercent()
        charging = SystemMetrics.batteryCharging()
    }
}
