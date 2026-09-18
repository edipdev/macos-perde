import SwiftUI

enum NotchTab: CaseIterable {
    case music
    case translate
    case timer
    case clipboard

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .translate: return "character.bubble"
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard"
        }
    }

    var id: String {
        switch self {
        case .music: return "music"
        case .translate: return "translate"
        case .timer: return "timer"
        case .clipboard: return "clipboard"
        }
    }

    var title: String {
        switch self {
        case .music: return "Müzik"
        case .translate: return "Çeviri"
        case .timer: return "Zamanlayıcı"
        case .clipboard: return "Pano"
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
