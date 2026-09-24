import SwiftUI

struct KeepAwakeView: View {
    @ObservedObject var store: KeepAwakeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KAFEİN")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)

            statusView

            presetRow

            if store.isActive {
                closeButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var statusView: some View {
        HStack(spacing: 10) {
            Image(systemName: store.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 22))
                .foregroundStyle(store.isActive ? Theme.accent : Theme.secondaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.isActive ? "Açık" : "Kapalı")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                if let remaining = store.remaining {
                    Text(formatted(remaining))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            presetButton("15 dk") { store.activate(duration: 900) }
            presetButton("30 dk") { store.activate(duration: 1800) }
            presetButton("1 saat") { store.activate(duration: 3600) }
            presetButton("Süresiz") { store.activate(duration: nil) }
        }
    }

    private func presetButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private var closeButton: some View {
        Button(action: store.deactivate) {
            Text("Kapat")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
