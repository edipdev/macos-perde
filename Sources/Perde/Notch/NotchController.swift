import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchController {
    let viewModel: NotchViewModel
    private let mouseTracker = MouseTracker()
    private let settings = SettingsStore.shared
    private var window: NotchWindow?
    private var collapseWorkItem: DispatchWorkItem?
    private var forceOpen = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        let service = NowPlayingService()
        viewModel = NotchViewModel(nowPlaying: service)
    }

    func start() {
        let screen = targetScreen()
        viewModel.topInset = screen.safeAreaInsets.top
        viewModel.notchWidth = NotchGeometry.notchWidth(for: screen)

        let frame = NotchGeometry.windowFrame(
            screenFrame: screen.frame,
            size: NotchGeometry.windowSize(topInset: viewModel.topInset)
        )

        let window = NotchWindow(contentRect: frame)
        let hosting = NSHostingView(rootView: NotchRootView(viewModel: viewModel))
        hosting.frame = CGRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        self.window = window
        applyCollectionBehavior()

        viewModel.nowPlaying.start()

        mouseTracker.onMove = { [weak self] location in self?.handleMouse(at: location) }
        mouseTracker.start()

        observeSettings()
    }

    func toggleViaHotKey() {
        forceOpen.toggle()
        if forceOpen {
            collapseWorkItem?.cancel(); collapseWorkItem = nil
            window?.ignoresMouseEvents = false
            viewModel.isExpanded = true
        } else {
            window?.ignoresMouseEvents = true
            viewModel.isExpanded = false
            viewModel.showLyrics = false
        }
    }

    func openTranslate() {
        forceOpen = true
        collapseWorkItem?.cancel(); collapseWorkItem = nil
        viewModel.selectedTab = .translate
        window?.ignoresMouseEvents = false
        viewModel.isExpanded = true
    }

    private var currentCardSize: CGSize {
        NotchGeometry.cardSize(
            tab: viewModel.selectedTab,
            expanded: true,
            notchWidth: viewModel.notchWidth,
            topInset: viewModel.topInset,
            showLyrics: viewModel.showLyrics
        )
    }

    private func handleMouse(at location: CGPoint) {
        if forceOpen { return }
        let screen = targetScreen()
        let shouldExpand: Bool

        if viewModel.isExpanded {
            if window?.isKeyWindow == true, viewModel.selectedTab == .translate {
                shouldExpand = true
            } else {
                let card = NotchGeometry.cardRect(screenFrame: screen.frame, size: currentCardSize)
                    .insetBy(dx: -14, dy: -14)
                shouldExpand = card.contains(location)
            }
        } else {
            let zone = NotchGeometry.hoverZone(
                screenFrame: screen.frame,
                notchWidth: NotchGeometry.notchWidth(for: screen)
            )
            shouldExpand = zone.contains(location)
        }

        setExpanded(shouldExpand)
    }

    private func setExpanded(_ expand: Bool) {
        if expand {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            guard !viewModel.isExpanded else { return }
            window?.ignoresMouseEvents = false
            viewModel.isExpanded = true
        } else {
            guard viewModel.isExpanded, collapseWorkItem == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.collapseWorkItem = nil
                self.window?.ignoresMouseEvents = true
                self.viewModel.isExpanded = false
                self.viewModel.showLyrics = false
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
        }
    }

    private func observeSettings() {
        settings.$preferredScreenName
            .dropFirst()
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &cancellables)
        settings.$autoHideFullscreen
            .dropFirst()
            .sink { [weak self] _ in self?.applyCollectionBehavior() }
            .store(in: &cancellables)
    }

    private func applyCollectionBehavior() {

        window?.collectionBehavior = settings.autoHideFullscreen
            ? [.stationary, .ignoresCycle]
            : [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    private func reposition() {
        guard let window else { return }
        let screen = targetScreen()
        viewModel.topInset = screen.safeAreaInsets.top
        viewModel.notchWidth = NotchGeometry.notchWidth(for: screen)
        let frame = NotchGeometry.windowFrame(
            screenFrame: screen.frame,
            size: NotchGeometry.windowSize(topInset: viewModel.topInset)
        )
        window.setFrame(frame, display: true)
    }

    private func targetScreen() -> NSScreen {
        if !settings.preferredScreenName.isEmpty,
           let chosen = NSScreen.screens.first(where: { $0.localizedName == settings.preferredScreenName }) {
            return chosen
        }
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }
}

extension NotchGeometry {

    static func notchWidth(for screen: NSScreen) -> CGFloat? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        return screen.frame.width - left.width - right.width
    }
}
