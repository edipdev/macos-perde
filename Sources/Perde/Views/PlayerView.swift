import SwiftUI

struct PlayerView: View {
    let snapshot: NowPlayingSnapshot
    let artwork: NSImage?
    let isFavorite: Bool
    let favoriteSupported: Bool
    let onFavorite: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onShuffle: () -> Void
    let onRepeat: () -> Void
    let onSeek: (Double) -> Void
    let onVolume: (Double) -> Void
    let onLyrics: () -> Void

    @State private var localVolume: Double?

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "MÜZİK", help: "Apple Music / Spotify oynatıcı — kontrol ve şarkı sözleri")
            header
            seekBar
            transport
            bottomRow
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ArtworkView(image: artwork, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(text: snapshot.title, font: .system(size: 15.5, weight: .bold), color: Theme.primaryText)
                Text(snapshot.artist.isEmpty ? snapshot.album : snapshot.artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            IconButton(system: "quote.bubble", size: 14, color: Theme.secondaryText, action: onLyrics)
        }
    }

    private var seekBar: some View {
        VStack(spacing: 4) {
            Scrubber(
                fraction: fraction,
                accent: .primary,
                onScrub: { onSeek($0 * snapshot.duration) }
            )
            HStack {
                Text(PlayerView.time(snapshot.elapsed))
                Spacer()
                Text("-" + PlayerView.time(max(0, snapshot.duration - snapshot.elapsed)))
            }
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
            .foregroundStyle(Theme.tertiaryText)
        }
    }

    private var transport: some View {
        HStack(spacing: 0) {
            IconButton(system: "shuffle", size: 14,
                       color: snapshot.isShuffle ? Theme.accent : .primary.opacity(0.8), action: onShuffle)
                .frame(maxWidth: .infinity)
            IconButton(system: "backward.fill", size: 17, color: .primary.opacity(0.92), action: onPrevious)
                .frame(maxWidth: .infinity)
            IconButton(system: snapshot.isPlaying ? "pause.fill" : "play.fill", size: 25, color: .primary, action: onPlayPause)
                .frame(maxWidth: .infinity)
            IconButton(system: "forward.fill", size: 17, color: .primary.opacity(0.92), action: onNext)
                .frame(maxWidth: .infinity)
            IconButton(system: "repeat", size: 14,
                       color: snapshot.isRepeat ? Theme.accent : .primary.opacity(0.8), action: onRepeat)
                .frame(maxWidth: .infinity)
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            IconButton(
                system: isFavorite ? "heart.fill" : "heart",
                size: 15,
                color: isFavorite ? Theme.accent : .primary.opacity(favoriteSupported ? 0.85 : 0.22),
                action: onFavorite
            )
            .disabled(!favoriteSupported)

            HStack(spacing: 7) {
                Image(systemName: volumeGlyph)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(width: 13, alignment: .leading)
                    .contentTransition(.symbolEffect(.replace))
                Scrubber(
                    fraction: (localVolume ?? snapshot.volume) / 100,
                    accent: .primary.opacity(0.4),
                    barHeight: 3,
                    live: { localVolume = $0 * 100 },
                    onScrub: { localVolume = nil; onVolume($0 * 100) }
                )
            }
            .frame(maxWidth: 150)

            Image(systemName: sourceIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private var volumeGlyph: String {
        let v = localVolume ?? snapshot.volume
        switch v {
        case ..<1: return "speaker.slash.fill"
        case ..<34: return "speaker.wave.1.fill"
        case ..<67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private var fraction: Double {
        guard snapshot.duration > 0 else { return 0 }
        return min(max(snapshot.elapsed / snapshot.duration, 0), 1)
    }

    private var sourceIcon: String {
        switch snapshot.source {
        case .music: return "music.note"
        case .spotify: return "waveform"
        }
    }

    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct IconButton: View {
    let system: String
    let size: CGFloat
    var color: Color = .primary
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: size + 14, height: size + 12)
                .contentShape(Rectangle())
                .scaleEffect(hovering ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct LyricsPanel: View {
    let snapshot: NowPlayingSnapshot
    let lyrics: String
    let isLoading: Bool
    let onClose: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.title).font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.primaryText).lineLimit(1)
                    Text(snapshot.artist).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryText).lineLimit(1)
                }
                Spacer()
                IconButton(system: "xmark", size: 12, color: Theme.secondaryText, action: onClose)
            }

            Group {
                if isLoading {
                    ProgressView().controlSize(.small).tint(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(lyrics.isEmpty ? "Sözler bulunamadı" : lyrics)
                            .font(.system(size: 12))
                            .foregroundStyle(lyrics.isEmpty ? Theme.tertiaryText : Theme.primaryText.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 30) {
                IconButton(system: "backward.fill", size: 15, color: .primary.opacity(0.9), action: onPrevious)
                IconButton(system: snapshot.isPlaying ? "pause.fill" : "play.fill", size: 20, color: .primary, action: onPlayPause)
                IconButton(system: "forward.fill", size: 15, color: .primary.opacity(0.9), action: onNext)
            }
        }
    }
}
