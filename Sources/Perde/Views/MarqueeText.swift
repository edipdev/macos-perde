import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .semibold)
    var color: Color = .primary

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflow: Bool { textWidth > containerWidth + 1 }
    private let gap: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            content
                .onAppear { containerWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, new in containerWidth = new }
        }
        .frame(height: lineHeight)
        .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if overflow {
            HStack(spacing: gap) {
                label
                label
            }
            .offset(x: offset)
            .onAppear { startScrolling() }
            .onChange(of: text) { _, _ in restart() }
        } else {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: text) { _, _ in measure() }
        }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { textWidth = proxy.size.width }
                        .onChange(of: text) { _, _ in textWidth = proxy.size.width }
                }
            )
    }

    private var lineHeight: CGFloat { 18 }

    private func measure() {
        offset = 0
    }

    private func restart() {
        offset = 0
        startScrolling()
    }

    private func startScrolling() {
        guard overflow else { return }
        offset = 0
        let distance = textWidth + gap
        let duration = Double(distance) / 30.0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}
