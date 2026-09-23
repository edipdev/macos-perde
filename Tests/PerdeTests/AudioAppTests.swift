import XCTest
@testable import Perde

final class AudioAppTests: XCTestCase {
    func testGroupsHelperProcessesByBundle() {
        let procs = [
            AudioProcessInfo(objectID: 1, pid: 10, bundleID: "com.google.Chrome", isRunningOutput: false),
            AudioProcessInfo(objectID: 2, pid: 11, bundleID: "com.google.Chrome.helper", isRunningOutput: true),
            AudioProcessInfo(objectID: 3, pid: 12, bundleID: "com.spotify.client", isRunningOutput: true),
        ]
        let apps = AudioApp.grouped(from: procs) { $0 }
        XCTAssertEqual(apps.count, 2)
        let chrome = apps.first { $0.bundleID == "com.google.Chrome" }
        XCTAssertEqual(chrome?.objectIDs.sorted(), [1, 2])
        XCTAssertEqual(chrome?.isPlaying, true)
    }
    func testEmptyInput() {
        XCTAssertTrue(AudioApp.grouped(from: [], name: { $0 }).isEmpty)
    }
}
