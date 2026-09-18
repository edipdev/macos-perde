import XCTest
@testable import Perde

final class NowPlayingParserTests: XCTestCase {
    func testParsesValidPlayingLine() {
        let raw = "Bohemian Rhapsody\tQueen\tA Night at the Opera\t354.0\t42.5\tplaying"
        let snap = NowPlayingParser.parse(raw, source: .spotify)

        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.title, "Bohemian Rhapsody")
        XCTAssertEqual(snap?.artist, "Queen")
        XCTAssertEqual(snap?.album, "A Night at the Opera")
        XCTAssertEqual(snap?.duration ?? 0, 354.0, accuracy: 0.001)
        XCTAssertEqual(snap?.elapsed ?? 0, 42.5, accuracy: 0.001)
        XCTAssertEqual(snap?.isPlaying, true)
        XCTAssertEqual(snap?.source, .spotify)
    }

    func testParsesPausedState() {
        let raw = "Song\tArtist\tAlbum\t100\t10\tpaused"
        let snap = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(snap?.isPlaying, false)
    }

    func testParsesCommaDecimalSeparator() {

        let raw = "Maraton\tAti242\tMaraton\t240,783\t66,012\tplaying"
        let snap = NowPlayingParser.parse(raw, source: .spotify)
        XCTAssertEqual(snap?.duration ?? 0, 240.783, accuracy: 0.001)
        XCTAssertEqual(snap?.elapsed ?? 0, 66.012, accuracy: 0.001)
        XCTAssertEqual(snap?.title, "Maraton")
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(NowPlayingParser.parse("", source: .music))
        XCTAssertNil(NowPlayingParser.parse("   ", source: .music))
    }

    func testMissingFieldsReturnsNil() {
        XCTAssertNil(NowPlayingParser.parse("Song\tArtist", source: .music))
    }

    func testEmptyTitleReturnsNil() {
        let raw = "\tArtist\tAlbum\t100\t10\tplaying"
        XCTAssertNil(NowPlayingParser.parse(raw, source: .music))
    }

    func testNonNumericDurationReturnsNil() {
        let raw = "Song\tArtist\tAlbum\tabc\t10\tplaying"
        XCTAssertNil(NowPlayingParser.parse(raw, source: .music))
    }

    func testNegativeValuesClampToZero() {
        let raw = "Song\tArtist\tAlbum\t-5\t-2\tplaying"
        let snap = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(snap?.duration, 0)
        XCTAssertEqual(snap?.elapsed, 0)
    }
}
