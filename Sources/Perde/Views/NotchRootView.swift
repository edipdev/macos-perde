import SwiftUI

struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject private var nowPlaying: NowPlayingService
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var lyricsStore = LyricsStore()
    @StateObject private var timerStore = TimerStore()
    @StateObject private var clipboardStore = ClipboardStore()
    @ObservedObject private var mixerStore = AudioMixerStore.shared
    @StateObject private var outputStore = OutputSwitcherStore()
    @ObservedObject private var keepAwakeStore = KeepAwakeStore.shared
    @ObservedObject private var colorStore = ColorPickerStore.shared
    @StateObject private var monitorStore = SystemMonitorStore()

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.nowPlaying = viewModel.nowPlaying
    }

    private var notchWidth: CGFloat { viewModel.notchWidth ?? 210 }
    private var topInset: CGFloat { viewModel.topInset }

    private var enabledTabs: [NotchTab] { NotchTab.allCases.filter { settings.isEnabled($0) } }

    private var hasCollapsedContent: Bool { nowPlaying.snapshot != nil || timerStore.isRunning }

    private var cardSize: CGSize {
        if viewModel.isExpanded {
            return NotchGeometry.cardSize(
                tab: viewModel.selectedTab,
                expanded: true,
                notchWidth: viewModel.notchWidth,
                topInset: topInset,
                showLyrics: viewModel.showLyrics
            )
        }

        let width = hasCollapsedContent ? notchWidth + 80 : notchWidth
        return CGSize(width: width, height: max(topInset, 32))
    }

    private var cornerRadius: CGFloat { viewModel.isExpanded ? 26 : 12 }

    private var borderVisible: Bool { !(settings.theme == .light && !viewModel.isExpanded) }

    var body: some View {
        VStack(spacing: 0) {
            card
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var card: some View {
        let shape = BottomRoundedRectangle(radius: cornerRadius)
        return ZStack(alignment: .top) {
            cardBackground(shape)
                .overlay(shape.stroke(Theme.hairline.opacity(borderVisible ? 1 : 0), lineWidth: 1))
            if viewModel.isExpanded {
                expandedContent
                    .padding(.top, topInset)
                    .transition(.opacity)
            } else {
                collapsedContent
                    .transition(.opacity)
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .environment(\.colorScheme, (settings.theme == .light && viewModel.isExpanded) ? .light : .dark)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: viewModel.isExpanded)
    }

    @ViewBuilder
    private func cardBackground(_ shape: BottomRoundedRectangle) -> some View {
        switch settings.theme {
        case .black:
            shape.fill(Color.black)
        case .light:
            if viewModel.isExpanded {
                shape.fill(Color(red: 0.6, green: 0.6, blue: 0.6))
            } else {

                shape.fill(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var collapsedContent: some View {
        if hasCollapsedContent {
            HStack(spacing: 0) {
                leftEar
                Spacer(minLength: notchWidth)
                rightEar
            }
            .frame(height: max(topInset, 32))
        }
    }

    @ViewBuilder
    private var leftEar: some View {
        if nowPlaying.snapshot != nil {
            ArtworkView(image: nowPlaying.artwork, size: min(max(topInset - 12, 18), 24))
                .padding(.leading, 10)
        } else if timerStore.isRunning {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.leading, 12)
        }
    }

    @ViewBuilder
    private var rightEar: some View {
        if timerStore.isRunning {

            MiniTimerRing(remaining: timerStore.remaining, size: min(max(topInset - 8, 22), 30))
                .padding(.trailing, 12)
        } else if let snapshot = nowPlaying.snapshot {
            MiniEqualizer(isPlaying: snapshot.isPlaying, barCount: 3)
                .padding(.trailing, 12)
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 12) {
            TabBarView(selected: $viewModel.selectedTab, tabs: enabledTabs)

            switch viewModel.selectedTab {
            case .music:
                musicContent
            case .translate:
                TranslationView()
            case .timer:
                TimerView(store: timerStore)
            case .clipboard:
                ClipboardView(store: clipboardStore)
            case .mixer:
                MixerView(store: mixerStore)
            case .output:
                OutputSwitcherView(store: outputStore)
            case .keepAwake:
                KeepAwakeView(store: keepAwakeStore)
            case .color:
                ColorPickerView(store: colorStore)
            case .monitor:
                SystemMonitorView(store: monitorStore)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            clipboardStore.start()
            if !settings.isEnabled(viewModel.selectedTab) { viewModel.selectedTab = firstEnabledTab }
        }
        .onChange(of: settings.enabledTabIDs) { _, _ in
            if !settings.isEnabled(viewModel.selectedTab) { viewModel.selectedTab = firstEnabledTab }
        }
    }

    private var firstEnabledTab: NotchTab { enabledTabs.first ?? .music }

    @ViewBuilder
    private var musicContent: some View {
        if let snapshot = nowPlaying.snapshot {
            if viewModel.showLyrics {
                LyricsPanel(
                    snapshot: snapshot,
                    lyrics: lyricsStore.lyrics,
                    isLoading: lyricsStore.isLoading,
                    onClose: { viewModel.showLyrics = false },
                    onPlayPause: { nowPlaying.playPause() },
                    onNext: { nowPlaying.next() },
                    onPrevious: { nowPlaying.previous() }
                )
                .frame(maxHeight: .infinity)
                .task(id: snapshot.trackKey) { await lyricsStore.load(for: snapshot) }
            } else {
                PlayerView(
                    snapshot: snapshot,
                    artwork: nowPlaying.artwork,
                    isFavorite: nowPlaying.isFavorite,
                    favoriteSupported: nowPlaying.favoriteSupported,
                    onFavorite: { nowPlaying.toggleFavorite() },
                    onPlayPause: { nowPlaying.playPause() },
                    onNext: { nowPlaying.next() },
                    onPrevious: { nowPlaying.previous() },
                    onShuffle: { nowPlaying.toggleShuffle() },
                    onRepeat: { nowPlaying.toggleRepeat() },
                    onSeek: { nowPlaying.seek(to: $0) },
                    onVolume: { nowPlaying.setVolume($0) },
                    onLyrics: { viewModel.showLyrics = true }
                )
                .frame(maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.secondaryText)
                Text("Şu an çalan bir şey yok")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                Text("Apple Music veya Spotify'da bir şey başlat")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
