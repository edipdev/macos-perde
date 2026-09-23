import XCTest
@testable import Perde

final class AudioMixerStoreTests: XCTestCase {
    func testSettingsRoundTrip() {
        let settings = ["com.spotify.client": AppAudioSetting(volume: 0.4, muted: true, outputDeviceUID: "dev")]
        let data = AudioMixerStore.encodeSettings(settings)
        XCTAssertEqual(AudioMixerStore.decodeSettings(data), settings)
    }
    func testDecodeNilIsEmpty() {
        XCTAssertTrue(AudioMixerStore.decodeSettings(nil).isEmpty)
    }
}
