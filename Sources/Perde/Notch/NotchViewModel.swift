import SwiftUI

enum NotchTab: CaseIterable {
    case music
    case translate
    case timer
    case clipboard
    case mixer
    case output
    case keepAwake
    case color
    case monitor

    static let defaultEnabled: [NotchTab] = NotchTab.allCases

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .translate: return "character.bubble"
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard"
        case .mixer: return "slider.vertical.3"
        case .output: return "hifispeaker.fill"
        case .keepAwake: return "cup.and.saucer.fill"
        case .color: return "eyedropper.halffull"
        case .monitor: return "gauge.with.dots.needle.67percent"
        }
    }

    var id: String {
        switch self {
        case .music: return "music"
        case .translate: return "translate"
        case .timer: return "timer"
        case .clipboard: return "clipboard"
        case .mixer: return "mixer"
        case .output: return "output"
        case .keepAwake: return "keepawake"
        case .color: return "color"
        case .monitor: return "monitor"
        }
    }

    var title: String {
        switch self {
        case .music: return "Müzik"
        case .translate: return "Çeviri"
        case .timer: return "Zamanlayıcı"
        case .clipboard: return "Pano"
        case .mixer: return "Ses Mikseri"
        case .output: return "Ses Çıkışı"
        case .keepAwake: return "Kafein"
        case .color: return "Renk Seçici"
        case .monitor: return "Sistem"
        }
    }
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var selectedTab: NotchTab = .music
    @Published var showLyrics = false

    var topInset: CGFloat = 0
    var notchWidth: CGFloat?

    let nowPlaying: NowPlayingService

    init(nowPlaying: NowPlayingService) {
        self.nowPlaying = nowPlaying
    }
}
