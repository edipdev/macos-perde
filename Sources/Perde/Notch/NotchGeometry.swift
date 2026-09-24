import CoreGraphics

enum NotchGeometry {

    static let windowWidth: CGFloat = 480

    static let musicCardWidth: CGFloat = 400
    static let translateCardWidth: CGFloat = 452

    static let musicContentHeight: CGFloat = 250
    static let musicLyricsContentHeight: CGFloat = 320
    static let translateContentHeight: CGFloat = 320

    static func windowSize(topInset: CGFloat) -> CGSize {
        CGSize(width: windowWidth, height: topInset + 360)
    }

    static func contentSize(for tab: NotchTab, showLyrics: Bool) -> CGSize {
        switch tab {
        case .music: return CGSize(width: musicCardWidth, height: showLyrics ? musicLyricsContentHeight : musicContentHeight)
        case .translate: return CGSize(width: translateCardWidth, height: translateContentHeight)
        case .timer: return CGSize(width: 360, height: 278)
        case .clipboard: return CGSize(width: 420, height: 300)
        case .mixer: return CGSize(width: 420, height: 300)
        case .output: return CGSize(width: 380, height: 260)
        }
    }

    static func collapsedSize(notchWidth: CGFloat?, topInset: CGFloat) -> CGSize {
        CGSize(width: notchWidth ?? 210, height: max(topInset, 32))
    }

    static func cardSize(tab: NotchTab, expanded: Bool, notchWidth: CGFloat?, topInset: CGFloat, showLyrics: Bool = false) -> CGSize {
        guard expanded else { return collapsedSize(notchWidth: notchWidth, topInset: topInset) }
        let content = contentSize(for: tab, showLyrics: showLyrics)
        return CGSize(width: content.width, height: topInset + content.height)
    }

    static func windowFrame(screenFrame: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func cardRect(screenFrame: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func hoverZone(screenFrame: CGRect, notchWidth: CGFloat?) -> CGRect {
        let width = (notchWidth ?? 210) + 60
        let height: CGFloat = 12
        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }
}
