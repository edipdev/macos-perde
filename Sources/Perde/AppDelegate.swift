import AppKit
import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var commandBar: CommandBarController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        enableLaunchAtLogin()
        setupMainMenu()
        setupStatusItem()
        let controller = NotchController()
        controller.start()
        self.controller = controller

        let commandBar = CommandBarController()
        commandBar.itemsProvider = { [weak self] in self?.buildCommandItems() ?? [] }
        self.commandBar = commandBar

        applyHotKeys()

        let settings = SettingsStore.shared
        settings.$toggleShortcutID.dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.applyHotKeys() } }
            .store(in: &cancellables)
        settings.$translateShortcutID.dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.applyHotKeys() } }
            .store(in: &cancellables)
        settings.$commandBarEnabled.dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.applyHotKeys() } }
            .store(in: &cancellables)

        KeepAwakeStore.shared.$isActive.dropFirst()
            .sink { [weak self] isActive in
                DispatchQueue.main.async { self?.updateStatusItemIcon(isActive: isActive) }
            }
            .store(in: &cancellables)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
    }

    private func applyHotKeys() {
        guard let controller else { return }
        let settings = SettingsStore.shared
        HotKeyCenter.shared.unregisterAll()

        let toggle = settings.toggleShortcut
        HotKeyCenter.shared.register(keyCode: toggle.keyCode, cmd: toggle.cmd, option: toggle.opt,
                                     shift: toggle.shift, control: toggle.ctrl) { [weak controller] in
            controller?.toggleViaHotKey()
        }
        let translate = settings.translateShortcut
        HotKeyCenter.shared.register(keyCode: translate.keyCode, cmd: translate.cmd, option: translate.opt,
                                     shift: translate.shift, control: translate.ctrl) { [weak controller] in
            controller?.openTranslate()
        }

        if settings.commandBarEnabled {
            HotKeyCenter.shared.register(keyCode: 49, option: true) { [weak self] in
                self?.commandBar?.toggle()
            }
        }
    }

    private func buildCommandItems() -> [CommandItem] {
        var items: [CommandItem] = NotchTab.allCases.filter { SettingsStore.shared.isEnabled($0) }.map { tab in
            CommandItem(title: "Aç: \(tab.title)", icon: tab.icon) { [weak self] in
                self?.controller?.open(tab)
            }
        }
        items.append(CommandItem(title: "Kafein: Süresiz", icon: "cup.and.saucer.fill") {
            KeepAwakeStore.shared.activate(duration: nil)
        })
        items.append(CommandItem(title: "Kafein: Kapat", icon: "cup.and.saucer.fill") {
            KeepAwakeStore.shared.deactivate()
        })
        items.append(CommandItem(title: "Renk Seç", icon: "eyedropper") {
            ColorPickerStore.shared.pick()
        })
        items.append(CommandItem(title: "Çentiği Aç/Kapat", icon: "chevron.compact.down") { [weak self] in
            self?.controller?.toggleViaHotKey()
        })
        items.append(CommandItem(title: "Ayarlar…", icon: "gearshape") { [weak self] in
            self?.openSettings()
        })
        return items
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "chevron.compact.down", accessibilityDescription: "Perde")

        let menu = NSMenu()
        menu.addItem(withTitle: "Perde", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Ayarlar…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Çıkış", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    private func updateStatusItemIcon(isActive: Bool) {
        statusItem?.button?.image = isActive
            ? NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Kafein açık")
            : NSImage(systemSymbolName: "chevron.compact.down", accessibilityDescription: "Perde")
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Perde Ayarları"
            window.contentViewController = NSHostingController(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func enableLaunchAtLogin() {
        guard SMAppService.mainApp.status != .enabled else { return }
        try? SMAppService.mainApp.register()
    }
}
