import AppKit
import Combine

@MainActor
final class TimerStore: ObservableObject {
    enum Phase { case work, rest }

    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var total: TimeInterval = 25 * 60
    @Published private(set) var isRunning = false

    @Published var pomodoroEnabled = false
    @Published private(set) var phase: Phase = .work
    @Published private(set) var completedSessions = 0

    var workMinutes = 25
    var breakMinutes = 5

    private var timer: Timer?

    var fraction: Double {
        guard total > 0 else { return 0 }
        return 1 - (remaining / total)
    }

    func setDuration(minutes: Int) {
        stop()
        total = TimeInterval(minutes * 60)
        remaining = total
    }

    func startPomodoro() {
        pomodoroEnabled = true
        phase = .work
        completedSessions = 0
        total = TimeInterval(workMinutes * 60)
        remaining = total
        start()
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning, remaining > 0 else { return }
        isRunning = true
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        if pomodoroEnabled {
            phase = .work
            completedSessions = 0
            total = TimeInterval(workMinutes * 60)
        }
        remaining = total
    }

    private func stop() {
        pause()
        pomodoroEnabled = false
    }

    private func tick() {
        guard remaining > 0 else { finish(); return }
        remaining -= 1
        if remaining <= 0 { finish() }
    }

    private func finish() {
        pause()
        remaining = 0
        NSSound(named: "Glass")?.play()
        NSApp.requestUserAttention(.criticalRequest)

        guard pomodoroEnabled else { return }

        if phase == .work {
            completedSessions += 1
            phase = .rest
            total = TimeInterval(breakMinutes * 60)
        } else {
            phase = .work
            total = TimeInterval(workMinutes * 60)
        }
        remaining = total
        start()
    }
}
