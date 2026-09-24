import SwiftUI

struct CommandBarView: View {
    let items: [CommandItem]
    let recents: [String]
    let onRun: (CommandItem) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private var filtered: [CommandItem] {
        guard !query.isEmpty else {
            let recentItems = recents.compactMap { title in items.first { $0.title == title } }
            let remainingItems = items.filter { item in !recents.contains(item.title) }
            return recentItems + remainingItems
        }
        return items
            .compactMap { item -> (CommandItem, Int)? in
                guard let score = CommandMatcher.fuzzyScore(query, item.title) else { return nil }
                return (item, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.title < rhs.0.title
            }
            .map(\.0)
    }

    var body: some View {
        VStack(spacing: 10) {
            searchField

            if filtered.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            row(item, highlighted: index == clampedSelection)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 560, height: 360)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in selection = 0 }
        .onKeyPress(.downArrow) {
            selection = min(clampedSelection + 1, max(filtered.count - 1, 0))
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(clampedSelection - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            if filtered.indices.contains(clampedSelection) { onRun(filtered[clampedSelection]) }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private var clampedSelection: Int {
        filtered.isEmpty ? 0 : min(selection, filtered.count - 1)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            TextField("Komut ara…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .foregroundStyle(Theme.primaryText)
                .focused($focused)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.subtleFill, in: RoundedRectangle(cornerRadius: 10))
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Theme.secondaryText)
            Text("Sonuç yok")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ item: CommandItem, highlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(highlighted ? Theme.accent : Theme.secondaryText)
                .frame(width: 18)
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(highlighted ? Theme.accent.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .onTapGesture { onRun(item) }
    }
}
