import SwiftUI

struct TabBarView: View {
    @Binding var selected: NotchTab
    var tabs: [NotchTab] = NotchTab.allCases

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected == tab ? Theme.primaryText : Theme.tertiaryText)
                        .frame(width: 44, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected == tab ? Color.primary.opacity(0.15) : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        )
    }
}
