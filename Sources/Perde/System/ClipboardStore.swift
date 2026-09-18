import AppKit
import Combine

struct ClipboardItem: Identifiable {
    enum Kind {
        case text(String)
        case image(NSImage)
    }

    let id = UUID()
    var kind: Kind
    var pinned = false

    var text: String? {
        if case .text(let value) = kind { return value }
        return nil
    }
    var image: NSImage? {
        if case .image(let value) = kind { return value }
        return nil
    }
    var url: URL? {
        guard let text, let url = URL(string: text), url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let maxItems = 30

    var ordered: [ClipboardItem] {
        items.filter(\.pinned) + items.filter { !$0.pinned }
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].pinned.toggle()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll { !$0.pinned }
    }

    func copy(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.kind {
        case .text(let value): pasteboard.setString(value, forType: .string)
        case .image(let image): pasteboard.writeObjects([image])
        }
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            items.removeAll { !$0.pinned && $0.text == text }
            items.insert(ClipboardItem(kind: .text(text)), at: 0)
        } else if let image = NSImage(pasteboard: pasteboard) {
            items.insert(ClipboardItem(kind: .image(image)), at: 0)
        } else {
            return
        }
        trim()
    }

    private func trim() {
        let unpinned = items.filter { !$0.pinned }
        guard unpinned.count > maxItems else { return }
        let removable = Set(unpinned.suffix(unpinned.count - maxItems).map(\.id))
        items.removeAll { removable.contains($0.id) }
    }
}
