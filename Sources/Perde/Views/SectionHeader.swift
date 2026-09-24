import SwiftUI

struct SectionHeader: View {
    let title: String
    let help: String

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .contentShape(Rectangle())
            .help(help)
            Spacer(minLength: 0)
        }
    }
}
