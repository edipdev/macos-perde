import SwiftUI

struct SettingLabel: View {
    let title: String
    let help: String
    @State private var show = false

    init(_ title: String, _ help: String) {
        self.title = title
        self.help = help
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .onHover { show = $0 }
                .popover(isPresented: $show, arrowEdge: .bottom) {
                    Text(help)
                        .font(.system(size: 12))
                        .padding(10)
                        .frame(width: 220)
                }
        }
    }
}
