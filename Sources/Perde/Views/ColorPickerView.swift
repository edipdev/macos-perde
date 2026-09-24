import SwiftUI

struct ColorPickerView: View {
    @ObservedObject var store: ColorPickerStore
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "RENK SEÇİCİ", help: "Ekrandan renk al, HEX kopyala")

            pickButton

            VStack(alignment: .leading, spacing: 8) {
                Text("Son renkler")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)

                if store.recent.isEmpty {
                    Text("Henüz renk seçilmedi")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    swatchGrid
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private var pickButton: some View {
        Button(action: store.pick) {
            Label("Renk Seç", systemImage: "eyedropper")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
    }

    private var swatchGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.recent, id: \.self) { hex in
                    swatch(hex)
                }
            }
        }
    }

    private func swatch(_ hex: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: hex))
                .frame(width: 40, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            Text(hex)
                .font(.system(size: 9, weight: .medium).monospaced())
                .foregroundStyle(Theme.tertiaryText)
        }
        .contentShape(Rectangle())
        .onTapGesture { copy(hex) }
    }

    private func copy(_ hex: String) {
        store.copy(hex)
        withAnimation(.spring(response: 0.3)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.25)) { showCopied = false }
        }
    }
}

private extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
