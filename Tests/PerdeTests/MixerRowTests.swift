import XCTest
@testable import Perde

final class MixerRowTests: XCTestCase {
    let spotify = AudioApp(bundleID: "com.spotify.client", name: "Spotify", objectIDs: [1], isPlaying: true)
    let idle = AudioApp(bundleID: "com.apple.Music", name: "Music", objectIDs: [2], isPlaying: false)

    func testPlayingOnlyFiltersIdleApps() {
        let rows = MixerRow.build(apps: [spotify, idle], settings: [:], source: .playingOnly)
        XCTAssertEqual(rows.map(\.app.bundleID), ["com.spotify.client"])
    }
    func testAllIncludesIdleApps() {
        let rows = MixerRow.build(apps: [spotify, idle], settings: [:], source: .all)
        XCTAssertEqual(rows.count, 2)
    }
    func testAttachesSavedSetting() {
        let saved = ["com.spotify.client": AppAudioSetting(volume: 0.5, muted: false, outputDeviceUID: nil)]
        let rows = MixerRow.build(apps: [spotify], settings: saved, source: .all)
        XCTAssertEqual(rows.first?.setting.volume, 0.5)
    }
    func testDefaultWhenNoSetting() {
        let rows = MixerRow.build(apps: [spotify], settings: [:], source: .all)
        XCTAssertTrue(rows.first?.setting.isDefault == true)
    }
}
