import Foundation

struct NowPlayingSnapshot: Equatable, Sendable {
    enum SourceApp: String, Sendable {
        case music = "Music"
        case spotify = "Spotify"

        var displayName: String {
            switch self {
            case .music: return "Apple Music"
            case .spotify: return "Spotify"
            }
        }
    }

    var title: String
    var artist: String
    var album: String
    var duration: Double
    var elapsed: Double
    var isPlaying: Bool
    var source: SourceApp
    var isShuffle: Bool = false
    var isRepeat: Bool = false
    var volume: Double = 100

    var trackKey: String { "\(source.rawValue)|\(title)|\(artist)|\(album)" }
}

enum PlaybackCommand: Sendable {
    case playPause
    case next
    case previous
}

enum NowPlayingParser {

    static func parse(_ raw: String, source: NowPlayingSnapshot.SourceApp) -> NowPlayingSnapshot? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.components(separatedBy: "\t")
        guard parts.count >= 6 else { return nil }

        let title = parts[0]
        guard !title.isEmpty else { return nil }

        guard let duration = parseSeconds(parts[3]),
              let elapsed = parseSeconds(parts[4]) else { return nil }

        let state = parts[5].lowercased()
        let isPlaying = state.contains("playing")

        let isShuffle = parts.count > 6 ? boolValue(parts[6]) : false
        let isRepeat = parts.count > 7 ? boolValue(parts[7]) : false
        let volume = parts.count > 8 ? (parseSeconds(parts[8]) ?? 100) : 100

        return NowPlayingSnapshot(
            title: title,
            artist: parts[1],
            album: parts[2],
            duration: max(0, duration),
            elapsed: max(0, elapsed),
            isPlaying: isPlaying,
            source: source,
            isShuffle: isShuffle,
            isRepeat: isRepeat,
            volume: min(max(volume, 0), 100)
        )
    }

    static func boolValue(_ raw: String) -> Bool {
        let v = raw.trimmingCharacters(in: .whitespaces).lowercased()
        return v == "true" || v == "1"
    }

    static func parseSeconds(_ raw: String) -> Double? {
        let normalized = raw
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
