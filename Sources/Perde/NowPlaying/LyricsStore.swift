import Foundation

@MainActor
final class LyricsStore: ObservableObject {
    @Published private(set) var lyrics = ""
    @Published private(set) var isLoading = false

    private var loadedKey = ""

    func load(for snapshot: NowPlayingSnapshot) async {
        guard snapshot.trackKey != loadedKey else { return }
        loadedKey = snapshot.trackKey
        lyrics = ""
        isLoading = true
        defer { isLoading = false }

        let result = await Self.fetch(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            duration: snapshot.duration
        )

        guard snapshot.trackKey == loadedKey else { return }
        lyrics = result ?? ""
    }

    func reset() { loadedKey = "" ; lyrics = "" }

    private nonisolated static func fetch(title: String, artist: String, album: String, duration: Double) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Perde (macOS notch player)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let plain = (json["plainLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (plain?.isEmpty == false) ? plain : nil
    }
}
