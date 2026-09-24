import XCTest
@testable import Perde

final class AudioGainTests: XCTestCase {
    func testMutedIsZero() {
        XCTAssertEqual(AppAudioController.effectiveGain(AppAudioSetting(volume: 0.8, muted: true, outputDeviceUID: nil)), 0)
    }
    func testVolumePassThrough() {
        XCTAssertEqual(AppAudioController.effectiveGain(AppAudioSetting(volume: 0.5, muted: false, outputDeviceUID: nil)), 0.5, accuracy: 0.0001)
    }
    func testClampsAboveOne() {
        XCTAssertEqual(AppAudioController.effectiveGain(AppAudioSetting(volume: 2.0, muted: false, outputDeviceUID: nil)), 2.0)
    }
    func testClampsAboveTwo() {
        XCTAssertEqual(AppAudioController.effectiveGain(AppAudioSetting(volume: 3.0, muted: false, outputDeviceUID: nil)), 2.0)
    }
}
