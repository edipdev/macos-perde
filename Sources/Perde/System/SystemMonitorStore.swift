import Foundation

@MainActor
final class SystemMonitorStore: ObservableObject {
    @Published private(set) var cpu: Double = 0
    @Published private(set) var memory: Double = 0
    @Published private(set) var battery: Double? = nil
    @Published private(set) var charging = false
    @Published private(set) var download: Double = 0
    @Published private(set) var upload: Double = 0
    @Published private(set) var disk: Double = 0
    @Published private(set) var temperature: Double? = nil

    private var previous = SystemMetrics.cpuTicks()
    private var previousNet = SystemMetrics.netCounters()
    private var lastNetSample = Date()
    private var timer: Timer?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        sample()
        previousNet = SystemMetrics.netCounters()
        lastNetSample = Date()
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

        let nowNet = SystemMetrics.netCounters()
        let elapsed = Date().timeIntervalSince(lastNetSample)
        lastNetSample = Date()
        let speed = SystemMetrics.netSpeed(previous: previousNet, current: nowNet, seconds: max(elapsed, 0.001))
        download = speed.down
        upload = speed.up
        previousNet = nowNet

        disk = SystemMetrics.diskUsage()
        temperature = SystemMetrics.cpuTemperature()
    }
}
