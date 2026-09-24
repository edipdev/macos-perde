import SwiftUI
import AppKit

struct ClipboardView: View {
    @ObservedObject var store: ClipboardStore
    @State private var query = ""
    @State private var showCopied = false
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipboardItem] {
        guard !query.isEmpty else { return store.ordered }
        return store.ordered.filter { item in
            if let text = item.text { return text.localizedCaseInsensitiveContains(query) }
            return "resim".localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "PANO", help: "Kopyalananların geçmişi — ara, sabitle")
            searchField

            if filtered.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(filtered) { row($0) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if showCopied {
                Label("Kopyalandı", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.accent, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func copy(_ item: ClipboardItem) {
        store.copy(item)
        withAnimation(.spring(response: 0.3)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.25)) { showCopied = false }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            TextField("Ara…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.primaryText)
                .focused($searchFocused)
                .simultaneousGesture(TapGesture().onEnded {
                    NSApp.makeNotchWindowKey()
                    searchFocused = true
                })
            Spacer(minLength: 0)
            if store.items.contains(where: { !$0.pinned }) {
                Button("Temizle") { store.clear() }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Theme.secondaryText)
            Text(query.isEmpty ? "Kopyaladıkların burada birikir" : "Sonuç yok")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            leading(item)
            Spacer(minLength: 4)
            Button { store.togglePin(item) } label: {
                Image(systemName: item.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 10))
                    .foregroundStyle(item.pinned ? Theme.accent : Theme.tertiaryText)
            }.buttonStyle(.plain)
            Button { store.remove(item) } label: {
                Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(Theme.tertiaryText)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 6).padding(.horizontal, 9)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { copy(item) }
    }

    @ViewBuilder
    private func leading(_ item: ClipboardItem) -> some View {
        if let image = item.image {
            HStack(spacing: 8) {
                Image(nsImage: image)
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("Resim").font(.system(size: 12)).foregroundStyle(Theme.secondaryText)
            }
        } else if let url = item.url {
            HStack(spacing: 6) {
                Image(systemName: "link").font(.system(size: 10)).foregroundStyle(Theme.accent)
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 12)).foregroundStyle(Theme.primaryText).lineLimit(1)
            }
        } else {
            Text((item.text ?? "").replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 12)).foregroundStyle(Theme.primaryText.opacity(0.9)).lineLimit(1)
        }
    }
}
