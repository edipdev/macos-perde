import SwiftUI

struct SystemMonitorView: View {
    @ObservedObject var store: SystemMonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "SİSTEM", help: "CPU, bellek ve batarya durumu")

            metricRow(label: "CPU", value: store.cpu, valueText: percentText(store.cpu))
            metricRow(label: "Bellek", value: store.memory, valueText: percentText(store.memory))
            batteryRow
            networkRow
            metricRow(label: "Disk", value: store.disk * 100, valueText: percentText(store.disk * 100))
            if let temperature = store.temperature {
                temperatureRow(temperature)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.start() }
        .onDisappear { store.stop() }
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

    private var networkRow: some View {
        HStack(spacing: 8) {
            Text("Ağ")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 56, alignment: .leading)

            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .semibold))
                    Text(formatRate(store.download))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .semibold))
                    Text(formatRate(store.upload))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
            }
            .foregroundStyle(Theme.secondaryText)

            Spacer(minLength: 0)
        }
    }

    private func temperatureRow(_ value: Double) -> some View {
        HStack(spacing: 8) {
            Text("Sıcaklık")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 56, alignment: .leading)

            Spacer(minLength: 0)

            Text("\(Int(value.rounded()))°C")
                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 34, alignment: .trailing)
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

    private func formatRate(_ bytesPerSec: Double) -> String {
        let mb = bytesPerSec / 1_048_576
        if mb < 1 {
            let kb = bytesPerSec / 1024
            return "\(Int(kb.rounded())) KB/s"
        }
        return String(format: "%.1f MB/s", mb)
    }
}
