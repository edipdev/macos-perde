import XCTest
import CoreGraphics
@testable import Perde

final class NotchGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let inset: CGFloat = 37

    func testCollapsedSizeMatchesNotch() {
        let size = NotchGeometry.collapsedSize(notchWidth: 200, topInset: inset)
        XCTAssertEqual(size.width, 200)
        XCTAssertEqual(size.height, inset)
    }

    func testCollapsedSizeFallsBackWithoutNotch() {
        let size = NotchGeometry.collapsedSize(notchWidth: nil, topInset: 20)
        XCTAssertEqual(size.width, 210)
        XCTAssertEqual(size.height, 32)
    }

    func testExpandedCardsReserveTopInset() {
        let music = NotchGeometry.cardSize(tab: .music, expanded: true, notchWidth: 200, topInset: inset)
        XCTAssertEqual(music.height, inset + NotchGeometry.musicContentHeight)

        let translate = NotchGeometry.cardSize(tab: .translate, expanded: true, notchWidth: 200, topInset: inset)
        XCTAssertEqual(translate.height, inset + NotchGeometry.translateContentHeight)
        XCTAssertGreaterThan(translate.height, music.height)
    }

    func testWindowFrameIsTopAnchoredAndCentered() {
        let size = NotchGeometry.windowSize(topInset: inset)
        let frame = NotchGeometry.windowFrame(screenFrame: screen, size: size)

        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, screen.maxY, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(size.height, inset + NotchGeometry.translateContentHeight)
    }

    func testHoverZonePinnedToTopEdge() {
        let zone = NotchGeometry.hoverZone(screenFrame: screen, notchWidth: 200)
        XCTAssertEqual(zone.maxY, screen.maxY, accuracy: 0.001)
        XCTAssertEqual(zone.midX, screen.midX, accuracy: 0.001)
        XCTAssertGreaterThan(zone.width, 200)
    }
}
