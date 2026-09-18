import SwiftUI

struct Scrubber: View {
    var fraction: Double
    var accent: Color = .primary
    var barHeight: CGFloat = 5
    var live: ((Double) -> Void)? = nil
    var onScrub: (Double) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        GeometryReader { geo in
            let value = dragFraction ?? fraction
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.16))
                Capsule()
                    .fill(accent)
                    .frame(width: max(0, geo.size.width * value))
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let f = clamp(g.location.x / geo.size.width)
                        dragFraction = f
                        live?(f)
                    }
                    .onEnded { g in
                        let f = clamp(g.location.x / geo.size.width)
                        dragFraction = nil
                        onScrub(f)
                    }
            )
            .overlay(alignment: .leading) {
                Circle()
                    .fill(.primary)
                    .frame(width: barHeight + 4, height: barHeight + 4)
                    .offset(x: geo.size.width * value - (barHeight + 4) / 2)
                    .opacity(dragFraction == nil ? 0 : 1)
            }
        }
        .frame(height: 16)
    }

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}
