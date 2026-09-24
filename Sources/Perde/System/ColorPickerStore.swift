import AppKit

@MainActor
final class ColorPickerStore: ObservableObject {
    static let shared = ColorPickerStore()

    @Published private(set) var recent: [String] = []

    private enum Keys {
        static let recentColors = "perde.recentColors"
    }

    private init() {
        if let saved = UserDefaults.standard.array(forKey: Keys.recentColors) as? [String] {
            recent = Array(saved.prefix(8))
        }
    }

    func pick() {
        NSColorSampler().show { [weak self] color in
            MainActor.assumeIsolated {
                guard let self, let color else { return }
                let hex = Self.hex(color)
                self.copy(hex)
                self.addRecent(hex)
            }
        }
    }

    func copy(_ hex: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }

    private func addRecent(_ hex: String) {
        var list = recent.filter { $0 != hex }
        list.insert(hex, at: 0)
        if list.count > 8 { list.removeLast(list.count - 8) }
        recent = list
        UserDefaults.standard.set(list, forKey: Keys.recentColors)
    }

    static func hex(_ color: NSColor) -> String {
        guard let converted = color.usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
