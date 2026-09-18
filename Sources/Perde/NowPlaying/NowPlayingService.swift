import AppKit
import Combine

@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var snapshot: NowPlayingSnapshot?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var isFavorite = false

    var favoriteSupported: Bool { activeSource?.favoriteSupported ?? false }

    private let sources: [any NowPlayingSource] = [MusicAppSource(), SpotifySource()]
    private var activeSource: (any NowPlayingSource)?
    private var timer: Timer?
    private var lastArtworkKey: String?

    func start() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func playPause() { dispatch(.playPause) }
    func next() { dispatch(.next) }
    func previous() { dispatch(.previous) }

    func toggleFavorite() {
        guard let source = activeSource, source.favoriteSupported else { return }
        isFavorite.toggle()
        source.setFavorite(isFavorite)
    }

    func seek(to seconds: Double) {
        guard let source = activeSource else { return }
        source.seek(to: seconds)
        if var snap = snapshot { snap.elapsed = seconds; snapshot = snap }
    }

    func toggleShuffle() {
        guard let source = activeSource, var snap = snapshot else { return }
        snap.isShuffle.toggle()
        snapshot = snap
        source.setShuffle(snap.isShuffle)
    }

    func toggleRepeat() {
        guard let source = activeSource, var snap = snapshot else { return }
        snap.isRepeat.toggle()
        snapshot = snap
        source.setRepeat(snap.isRepeat)
    }

    func setVolume(_ value: Double) {
        guard let source = activeSource else { return }
        source.setVolume(value)
        if var snap = snapshot { snap.volume = value; snapshot = snap }
    }

    private func dispatch(_ command: PlaybackCommand) {
        guard let source = activeSource else { return }
        source.sendCommand(command)

        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            refresh()
        }
    }

    private func refresh() {

        var picked: (NowPlayingSnapshot, any NowPlayingSource)?
        for source in sources {
            guard let snap = source.fetch() else { continue }
            if snap.isPlaying {
                picked = (snap, source)
                break
            }
            if picked == nil { picked = (snap, source) }
        }

        guard let (snap, source) = picked else {
            snapshot = nil
            artwork = nil
            activeSource = nil
            lastArtworkKey = nil
            return
        }

        activeSource = source
        snapshot = snap

        guard snap.trackKey != lastArtworkKey else { return }
        lastArtworkKey = snap.trackKey
        isFavorite = false

        guard let reference = source.artwork() else {
            artwork = nil
            return
        }
        Task {
            let data = await Self.loadArtwork(reference)

            if snap.trackKey == lastArtworkKey {
                artwork = data.flatMap { NSImage(data: $0) }
            }
        }
    }

    private nonisolated static func loadArtwork(_ source: ArtworkSource) async -> Data? {
        switch source {
        case .file(let path):
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        case .remote(let url):
            return try? await withCheckedThrowingContinuation { continuation in
                URLSession.shared.dataTask(with: url) { data, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }.resume()
            }
        }
    }
}
