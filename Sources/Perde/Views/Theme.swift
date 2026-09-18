import SwiftUI

enum Theme {

    @MainActor static var accent: Color { SettingsStore.shared.accentColor }

    static var primaryText: Color { .primary }
    static var secondaryText: Color { .secondary }
    static var tertiaryText: Color { Color.secondary.opacity(0.6) }
    static var hairline: Color { Color.primary.opacity(0.12) }

    static var subtleFill: Color { Color.primary.opacity(0.08) }
}

struct MiniEqualizer: View {
    var isPlaying: Bool
    var color: Color = Theme.accent
    var barCount: Int = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: height(index, t))
                }
            }
            .frame(height: 15, alignment: .bottom)
            .animation(.easeInOut(duration: 0.12), value: isPlaying)
        }
    }

    private func height(_ index: Int, _ time: Double) -> CGFloat {
        guard isPlaying else { return 4 }
        let phase = time * 5.5 + Double(index) * 1.3
        return 4 + (sin(phase) * 0.5 + 0.5) * 11
    }
}
