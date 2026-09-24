import SwiftUI

struct OutputSwitcherView: View {
    @ObservedObject var store: OutputSwitcherStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SES ÇIKIŞI")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)

            if store.devices.isEmpty {
                Spacer()
                Text("Çıkış aygıtı yok")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(store.devices) { device in rowView(device) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.start() }
    }

    private func rowView(_ device: OutputDevice) -> some View {
        let isSelected = device.uid == store.currentUID
        return HStack(spacing: 8) {
            Image(systemName: "hifispeaker.fill")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryText)
            Text(device.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
            Spacer(minLength: 4)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { store.select(device.uid) }
    }
}
