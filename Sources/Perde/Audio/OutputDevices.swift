import Foundation
import CoreAudio

struct OutputDevice: Identifiable, Equatable {
    let uid: String
    let name: String
    var id: String { uid }
}

enum OutputDevices {
    private static let sys = AudioObjectID(kAudioObjectSystemObject)

    static func list() -> [OutputDevice] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { dev in
            guard hasOutput(dev), let uid = string(dev, kAudioDevicePropertyDeviceUID) else { return nil }
            let name = string(dev, kAudioObjectPropertyName) ?? uid
            return OutputDevice(uid: uid, name: name)
        }
    }

    static func defaultUID() -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var dev: AudioDeviceID = 0; var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &dev) == noErr else { return nil }
        return string(dev, kAudioDevicePropertyDeviceUID)
    }

    private static func hasOutput(_ dev: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(dev, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        let count = Int(size) / MemoryLayout<AudioBuffer>.size
        guard count > 0 else { return false }
        let abl = AudioBufferList.allocate(maximumBuffers: count)
        defer { free(abl.unsafeMutablePointer) }
        guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, abl.unsafeMutablePointer) == noErr else { return false }
        return abl.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private static func string(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<CFString?>.size); var cf: CFString?
        let st = withUnsafeMutablePointer(to: &cf) { AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, $0) }
        return st == noErr ? (cf as String?) : nil
    }
}
