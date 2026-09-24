import SwiftUI

struct SystemMonitorView: View {
    @ObservedObject var store: SystemMonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "SİSTEM", help: "CPU, bellek ve batarya durumu")

            metricRow(label: "CPU", value: store.cpu, valueText: percentText(store.cpu))
            metricRow(label: "Bellek", value: store.memory, valueText: percentText(store.memory))
            batteryRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.start() }
    }

    private var batteryRow: some View {
        HStack(spacing: 8) {
            Text("Batarya")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 56, alignment: .leading)

            barTrack(percent: store.battery ?? 0)

            HStack(spacing: 4) {
                if store.charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text(store.battery.map { percentText($0) } ?? "—")
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private func metricRow(label: String, value: Double, valueText: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 56, alignment: .leading)

            barTrack(percent: value)

            Text(valueText)
                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 34, alignment: .trailing)
        }
    }

    private func barTrack(percent: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.subtleFill)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: geometry.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
            }
        }
        .frame(height: 8)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}
