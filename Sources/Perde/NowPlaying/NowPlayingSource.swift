import Foundation

enum ArtworkSource: Sendable {
    case remote(URL)
    case file(String)
}

@MainActor
protocol NowPlayingSource {
    var app: NowPlayingSnapshot.SourceApp { get }

    var favoriteSupported: Bool { get }
    func fetch() -> NowPlayingSnapshot?
    func artwork() -> ArtworkSource?
    func sendCommand(_ command: PlaybackCommand)
    func setFavorite(_ value: Bool)
    func seek(to seconds: Double)
    func setShuffle(_ value: Bool)
    func setRepeat(_ value: Bool)
    func setVolume(_ value: Double)
}

struct MusicAppSource: NowPlayingSource {
    let app: NowPlayingSnapshot.SourceApp = .music
    let favoriteSupported = true

    func setFavorite(_ value: Bool) {
        AppleScriptRunner.run(
            "if application \"Music\" is running then tell application \"Music\" to set favorited of current track to \(value)"
        )
    }

    func seek(to seconds: Double) {
        AppleScriptRunner.run(
            "if application \"Music\" is running then tell application \"Music\" to set player position to \(Int(seconds))"
        )
    }

    func setShuffle(_ value: Bool) {
        AppleScriptRunner.run(
            "if application \"Music\" is running then tell application \"Music\" to set shuffle enabled to \(value)"
        )
    }

    func setRepeat(_ value: Bool) {
        AppleScriptRunner.run(
            "if application \"Music\" is running then tell application \"Music\" to set song repeat to \(value ? "all" : "off")"
        )
    }

    func setVolume(_ value: Double) {
        AppleScriptRunner.run(
            "if application \"Music\" is running then tell application \"Music\" to set sound volume to \(Int(value))"
        )
    }

    func fetch() -> NowPlayingSnapshot? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    set playerState to (player state as text)
                    if playerState is "stopped" then return ""
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDur to (duration of current track)
                    set trackPos to (player position)
                    set sh to false
                    try
                        set sh to (shuffle enabled)
                    end try
                    set rp to false
                    try
                        if (song repeat as text) is not "off" then set rp to true
                    end try
                    set vol to 100
                    try
                        set vol to (sound volume)
                    end try
                    return trackName & tab & trackArtist & tab & trackAlbum & tab & trackDur & tab & trackPos & tab & playerState & tab & (sh as text) & tab & (rp as text) & tab & (vol as text)
                on error
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """
        guard let raw = AppleScriptRunner.run(script) else { return nil }
        return NowPlayingParser.parse(raw, source: .music)
    }

    func artwork() -> ArtworkSource? {
        let path = "/tmp/perde-artwork-music.dat"
        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    if (count of artworks of current track) is 0 then return ""
                    set artData to (data of artwork 1 of current track)
                    set artPath to "\(path)"
                    set artFile to open for access (POSIX file artPath) with write permission
                    set eof artFile to 0
                    write artData to artFile
                    close access artFile
                    return artPath
                on error
                    try
                        close access artFile
                    end try
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """
        guard let result = AppleScriptRunner.run(script), !result.isEmpty else { return nil }
        return .file(result)
    }

    func sendCommand(_ command: PlaybackCommand) {
        AppleScriptRunner.run(
            "if application \"Music\" is running then tell application \"Music\" to \(command.appleScriptVerb)"
        )
    }
}

struct SpotifySource: NowPlayingSource {
    let app: NowPlayingSnapshot.SourceApp = .spotify
    let favoriteSupported = false

    func setFavorite(_ value: Bool) {}

    func seek(to seconds: Double) {
        AppleScriptRunner.run(
            "if application \"Spotify\" is running then tell application \"Spotify\" to set player position to \(Int(seconds))"
        )
    }

    func setShuffle(_ value: Bool) {
        AppleScriptRunner.run(
            "if application \"Spotify\" is running then tell application \"Spotify\" to set shuffling to \(value)"
        )
    }

    func setRepeat(_ value: Bool) {
        AppleScriptRunner.run(
            "if application \"Spotify\" is running then tell application \"Spotify\" to set repeating to \(value)"
        )
    }

    func setVolume(_ value: Double) {
        AppleScriptRunner.run(
            "if application \"Spotify\" is running then tell application \"Spotify\" to set sound volume to \(Int(value))"
        )
    }

    func fetch() -> NowPlayingSnapshot? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                try
                    set playerState to (player state as text)
                    if playerState is "stopped" then return ""
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDur to ((duration of current track) / 1000)
                    set trackPos to (player position)
                    set sh to false
                    try
                        set sh to (shuffling)
                    end try
                    set rp to false
                    try
                        set rp to (repeating)
                    end try
                    set vol to 100
                    try
                        set vol to (sound volume)
                    end try
                    return trackName & tab & trackArtist & tab & trackAlbum & tab & trackDur & tab & trackPos & tab & playerState & tab & (sh as text) & tab & (rp as text) & tab & (vol as text)
                on error
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """
        guard let raw = AppleScriptRunner.run(script) else { return nil }
        return NowPlayingParser.parse(raw, source: .spotify)
    }

    func artwork() -> ArtworkSource? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                try
                    return (artwork url of current track)
                on error
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """
        guard let urlString = AppleScriptRunner.run(script),
              let url = URL(string: urlString),
              url.scheme?.hasPrefix("http") == true else { return nil }
        return .remote(url)
    }

    func sendCommand(_ command: PlaybackCommand) {
        AppleScriptRunner.run(
            "if application \"Spotify\" is running then tell application \"Spotify\" to \(command.appleScriptVerb)"
        )
    }
}

private extension PlaybackCommand {
    var appleScriptVerb: String {
        switch self {
        case .playPause: return "playpause"
        case .next: return "next track"
        case .previous: return "previous track"
        }
    }
}
