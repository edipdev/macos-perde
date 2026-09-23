import XCTest
@testable import Perde

final class AppAudioSettingTests: XCTestCase {
    func testDefaultIsDefault() {
        XCTAssertTrue(AppAudioSetting.default.isDefault)
    }
    func testLoweredVolumeIsNotDefault() {
        XCTAssertFalse(AppAudioSetting(volume: 0.5, muted: false, outputDeviceUID: nil).isDefault)
    }
    func testMutedIsNotDefault() {
        XCTAssertFalse(AppAudioSetting(volume: 1.0, muted: true, outputDeviceUID: nil).isDefault)
    }
    func testRoutedIsNotDefault() {
        XCTAssertFalse(AppAudioSetting(volume: 1.0, muted: false, outputDeviceUID: "X").isDefault)
    }
    func testCodableRoundTrip() throws {
        let s = AppAudioSetting(volume: 0.3, muted: true, outputDeviceUID: "dev")
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(AppAudioSetting.self, from: data), s)
    }
}
