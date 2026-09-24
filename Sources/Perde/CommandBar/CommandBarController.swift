import AppKit
import SwiftUI

@MainActor
final class CommandBarController {
    var itemsProvider: (() -> [CommandItem])?

    private var panel: NSPanel?
    private var resignObserver: NSObjectProtocol?

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        let items = itemsProvider?() ?? []
        let view = CommandBarView(
            items: items,
            onRun: { [weak self] item in
                item.action()
                self?.hide()
            },
            onClose: { [weak self] in self?.hide() }
        )

        let size = CGSize(width: 560, height: 360)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]
        let origin = CGPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.midY - size.height / 2)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)

        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = CommandBarPanel(
            contentRect: CGRect(origin: .zero, size: CGSize(width: 560, height: 360)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }

        return panel
    }
}

private final class CommandBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
