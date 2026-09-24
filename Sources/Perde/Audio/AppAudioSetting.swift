import Foundation

struct AppAudioSetting: Codable, Equatable {
    var volume: Double
    var muted: Bool
    var outputDeviceUID: String?

    static let `default` = AppAudioSetting(volume: 1.0, muted: false, outputDeviceUID: nil)

    var isDefault: Bool {
        volume == 1.0 && !muted && outputDeviceUID == nil
    }
}
