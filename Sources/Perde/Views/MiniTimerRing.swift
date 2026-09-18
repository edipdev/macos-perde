import SwiftUI

struct MiniTimerRing: View {
    var remaining: TimeInterval
    var color: Color = Theme.accent
    var size: CGFloat = 28

    private var secs: Int { Int(remaining.rounded()) }
    private var ringFraction: Double { Double(secs % 60) / 60.0 }
    private var number: String { secs >= 60 ? "\(secs / 60)" : "\(secs)" }

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: ringFraction)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: ringFraction)
            Text(number)
                .font(.system(size: size * 0.42, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
    }
}
