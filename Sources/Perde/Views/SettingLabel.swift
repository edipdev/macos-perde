import SwiftUI

struct SettingLabel: View {
    let title: String
    let help: String

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
        }
        .contentShape(Rectangle())
        .help(help)
    }
}
