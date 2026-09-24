import SwiftUI
import AppKit

struct MixerView: View {
    @ObservedObject var store: AudioMixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "SES MİKSERİ", help: "Uygulama başına ses seviyesi, sessize alma, çıkış yönlendirme")

            if store.rows.isEmpty {
                Spacer()
                Text("Ses çalan uygulama yok")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.rows) { row in rowView(row) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.start() }
    }

    private func rowView(_ row: MixerRow) -> some View {
        let bundleID = row.app.bundleID
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                icon(for: bundleID)
                Text(row.app.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.primaryText).lineLimit(1)
                Spacer(minLength: 4)
                Button { store.togglePin(bundleID) } label: {
                    Image(systemName: store.pinned.contains(bundleID) ? "pin.fill" : "pin").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(store.pinned.contains(bundleID) ? Theme.accent : Theme.tertiaryText)
                outputMenu(row)
            }
            HStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { row.setting.muted ? 0 : row.setting.volume },
                        set: { store.setVolume($0, for: bundleID) }
                    ),
                    in: 0...2
                )
                boostLabel(for: row)
                Button { store.reset(bundleID) } label: {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(Theme.tertiaryText)
                Button { store.setMuted(!row.setting.muted, for: bundleID) } label: {
                    Image(systemName: row.setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(row.setting.muted ? Theme.accent : Theme.secondaryText)
            }
        }
        .padding(9)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func boostLabel(for row: MixerRow) -> some View {
        let volume = row.setting.muted ? 0 : row.setting.volume
        let boosted = volume > 1.0
        return HStack(spacing: 2) {
            if boosted { Image(systemName: "bolt.fill").font(.system(size: 9)) }
            Text("\(Int(volume * 100))%").font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(boosted ? Theme.accent : Theme.secondaryText)
        .frame(width: 42, alignment: .trailing)
    }

    private func icon(for bundleID: String) -> some View {
        let image: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return Image(nsImage: image).resizable().frame(width: 22, height: 22)
    }

    private func outputMenu(_ row: MixerRow) -> some View {
        Menu {
            Button("Varsayılan") { store.setOutput(nil, for: row.app.bundleID) }
            ForEach(store.outputs) { dev in
                Button(dev.name) { store.setOutput(dev.uid, for: row.app.bundleID) }
            }
        } label: {
            Text(outputLabel(for: row))
                .font(.system(size: 10.5, weight: .medium)).foregroundStyle(Theme.secondaryText)
                .lineLimit(1).frame(maxWidth: 90)
        }
        .menuStyle(.button).buttonStyle(.plain).fixedSize()
    }

    private func outputLabel(for row: MixerRow) -> String {
        guard let uid = row.setting.outputDeviceUID else { return "Varsayılan" }
        return store.outputs.first { $0.uid == uid }?.name ?? "Varsayılan"
    }
}
