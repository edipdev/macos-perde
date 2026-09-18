import AppKit

@MainActor
final class MouseTracker {
    var onMove: ((CGPoint) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
            MainActor.assumeIsolated { [weak self] in self?.emit() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            MainActor.assumeIsolated { [weak self] in self?.emit() }
            return event
        }
        emit()
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func emit() {
        onMove?(NSEvent.mouseLocation)
    }
}
