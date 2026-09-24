import AppKit
import SwiftUI
import Combine

struct ShortcutOption: Identifiable, Hashable {
    let id: String
    let label: String
    let keyCode: Int
    let cmd: Bool
    let opt: Bool
    let ctrl: Bool
    let shift: Bool
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var autoHideFullscreen: Bool {
        didSet { UserDefaults.standard.set(autoHideFullscreen, forKey: Keys.autoHide) }
    }

    @Published var preferredScreenName: String {
        didSet { UserDefaults.standard.set(preferredScreenName, forKey: Keys.screen) }
    }

    @Published var enabledTabIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(enabledTabIDs), forKey: Keys.tabs) }
    }

    enum Theme: String { case black, light }

    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    @Published var accentColor: Color {
        didSet { saveAccent() }
    }

    @Published var recentTargets: [String] {
        didSet { UserDefaults.standard.set(recentTargets, forKey: Keys.recentTargets) }
    }

    @Published var toggleShortcutID: String {
        didSet { UserDefaults.standard.set(toggleShortcutID, forKey: Keys.toggleShortcut) }
    }
    @Published var translateShortcutID: String {
        didSet { UserDefaults.standard.set(translateShortcutID, forKey: Keys.translateShortcut) }
    }

    static let toggleOptions: [ShortcutOption] = [
        ShortcutOption(id: "opt-cmd-p", label: "⌥⌘P", keyCode: 35, cmd: true, opt: true, ctrl: false, shift: false),
        ShortcutOption(id: "ctrl-opt-p", label: "⌃⌥P", keyCode: 35, cmd: false, opt: true, ctrl: true, shift: false),
        ShortcutOption(id: "opt-cmd-space", label: "⌥⌘Space", keyCode: 49, cmd: true, opt: true, ctrl: false, shift: false),
        ShortcutOption(id: "ctrl-opt-n", label: "⌃⌥N", keyCode: 45, cmd: false, opt: true, ctrl: true, shift: false)
    ]
    static let translateOptions: [ShortcutOption] = [
        ShortcutOption(id: "opt-cmd-t", label: "⌥⌘T", keyCode: 17, cmd: true, opt: true, ctrl: false, shift: false),
        ShortcutOption(id: "ctrl-opt-t", label: "⌃⌥T", keyCode: 17, cmd: false, opt: true, ctrl: true, shift: false),
        ShortcutOption(id: "opt-cmd-l", label: "⌥⌘L", keyCode: 37, cmd: true, opt: true, ctrl: false, shift: false)
    ]

    var toggleShortcut: ShortcutOption {
        Self.toggleOptions.first { $0.id == toggleShortcutID } ?? Self.toggleOptions[0]
    }
    var translateShortcut: ShortcutOption {
        Self.translateOptions.first { $0.id == translateShortcutID } ?? Self.translateOptions[0]
    }

    func noteUsedTarget(_ code: String) {
        var list = recentTargets.filter { $0 != code }
        list.insert(code, at: 0)
        if list.count > 3 { list.removeLast(list.count - 3) }
        recentTargets = list
    }

    private enum Keys {
        static let autoHide = "perde.autoHideFullscreen"
        static let screen = "perde.preferredScreenName"
        static let tabs = "perde.enabledTabIDs"
        static let theme = "perde.theme"
        static let accent = "perde.accentRGBA"
        static let recentTargets = "perde.recentTargets"
        static let toggleShortcut = "perde.toggleShortcut"
        static let translateShortcut = "perde.translateShortcut"
    }

    private init() {
        autoHideFullscreen = UserDefaults.standard.bool(forKey: Keys.autoHide)
        preferredScreenName = UserDefaults.standard.string(forKey: Keys.screen) ?? ""
        if let saved = UserDefaults.standard.array(forKey: Keys.tabs) as? [String], !saved.isEmpty {
            enabledTabIDs = Set(saved)
        } else {
            enabledTabIDs = Set(NotchTab.defaultEnabled.map(\.id))
        }
        switch UserDefaults.standard.string(forKey: Keys.theme) {
        case "light", "mac", "transparent": theme = .light
        default: theme = .black
        }
        if let rgba = UserDefaults.standard.array(forKey: Keys.accent) as? [Double], rgba.count == 4 {
            accentColor = Color(.sRGB, red: rgba[0], green: rgba[1], blue: rgba[2], opacity: rgba[3])
        } else {
            accentColor = Color(red: 0.36, green: 0.83, blue: 0.78)
        }
        recentTargets = UserDefaults.standard.stringArray(forKey: Keys.recentTargets) ?? []
        toggleShortcutID = UserDefaults.standard.string(forKey: Keys.toggleShortcut) ?? "opt-cmd-p"
        translateShortcutID = UserDefaults.standard.string(forKey: Keys.translateShortcut) ?? "opt-cmd-t"
        if !UserDefaults.standard.bool(forKey: "perde.mixerTabMigrated") {
            enabledTabIDs.insert(NotchTab.mixer.id)
            UserDefaults.standard.set(Array(enabledTabIDs), forKey: Keys.tabs)
            UserDefaults.standard.set(true, forKey: "perde.mixerTabMigrated")
        }
    }

    func isEnabled(_ tab: NotchTab) -> Bool { enabledTabIDs.contains(tab.id) }

    func setEnabled(_ tab: NotchTab, _ enabled: Bool) {
        if enabled { enabledTabIDs.insert(tab.id) }
        else if enabledTabIDs.count > 1 { enabledTabIDs.remove(tab.id) }
    }

    private func saveAccent() {
        let ns = NSColor(accentColor).usingColorSpace(.sRGB) ?? .systemTeal
        UserDefaults.standard.set(
            [Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent), Double(ns.alphaComponent)],
            forKey: Keys.accent
        )
    }
}
