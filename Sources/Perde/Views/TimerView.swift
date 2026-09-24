import SwiftUI

struct TimerView: View {
    @ObservedObject var store: TimerStore

    @State private var minutes = 25
    private let presets = [5, 15, 25]

    private var ringColor: Color {
        store.pomodoroEnabled && store.phase == .rest ? Color.blue : Theme.accent
    }

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "ZAMANLAYICI", help: "Geri sayım ve Pomodoro")
            header

            ZStack {
                Circle().stroke(.primary.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: ringFraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: ringFraction)
                VStack(spacing: 0) {
                    Text(centerNumber)
                        .font(.system(size: 36, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.primaryText)
                    Text(centerUnit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .frame(width: 108, height: 108)

            if !store.pomodoroEnabled {
                presetRow
            }

            HStack(spacing: 24) {
                IconButton(system: "arrow.counterclockwise", size: 15, color: Theme.secondaryText, action: store.reset)
                IconButton(system: store.isRunning ? "pause.fill" : "play.fill", size: 24, color: Theme.primaryText, action: store.toggle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 8) {
            chip("Pomodoro", active: store.pomodoroEnabled) { togglePomodoro() }
            if store.pomodoroEnabled {
                Text(store.phase == .work ? "Çalışma" : "Mola")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ringColor)
                Spacer()
                Text("\(store.completedSessions) seans")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            } else {
                Spacer()
            }
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { m in
                chip("\(m)dk", active: minutes == m) { set(m) }
            }
            HStack(spacing: 6) {
                stepButton("minus") { set(max(1, minutes - 1)) }
                Text("\(minutes)dk")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
                    .frame(minWidth: 34)
                stepButton("plus") { set(min(180, minutes + 1)) }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
        }
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? .black : Theme.secondaryText)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(active ? Theme.accent : Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func togglePomodoro() {
        if store.pomodoroEnabled {
            store.pomodoroEnabled = false
            store.setDuration(minutes: minutes)
        } else {
            store.startPomodoro()
        }
    }

    private func set(_ m: Int) {
        minutes = m
        store.setDuration(minutes: m)
    }

    private var centerNumber: String {
        let secs = Int(store.remaining.rounded())
        return secs >= 60 ? "\(secs / 60)" : "\(secs)"
    }

    private var centerUnit: String {
        Int(store.remaining.rounded()) >= 60 ? "dk" : "sn"
    }

    private var ringFraction: Double {
        let secs = Int(store.remaining.rounded())
        return Double(secs % 60) / 60.0
    }
}
