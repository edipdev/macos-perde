import Foundation

enum MixerListSource: String {
    case playingOnly
    case all
}

struct MixerRow: Identifiable, Equatable {
    let app: AudioApp
    let setting: AppAudioSetting
    var id: String { app.bundleID }

    static func build(apps: [AudioApp], settings: [String: AppAudioSetting], source: MixerListSource, pinned: Set<String> = []) -> [MixerRow] {
        apps
            .filter { source == .all || $0.isPlaying }
            .map { MixerRow(app: $0, setting: settings[$0.bundleID] ?? .default) }
            .sorted { pinned.contains($0.app.bundleID) && !pinned.contains($1.app.bundleID) }
    }
}
