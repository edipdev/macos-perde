import Foundation
import IOKit.pwr_mgt

@MainActor
final class KeepAwakeStore: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var remaining: TimeInterval? = nil

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?
    private var endDate: Date?

    func activate(duration: TimeInterval?) {
        if isActive { deactivate() }

        var id: IOPMAssertionID = 0
        let ok = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Perde keep awake" as CFString,
            &id)
        guard ok == kIOReturnSuccess else { return }
        assertionID = id
        isActive = true

        guard let duration else {
            remaining = nil
            return
        }

        endDate = Date().addingTimeInterval(duration)
        remaining = duration
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func deactivate() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        remaining = nil
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isActive = false
    }

    private func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            deactivate()
        } else {
            remaining = left
        }
    }
}
