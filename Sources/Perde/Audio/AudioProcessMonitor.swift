import Foundation
import CoreAudio
import AppKit

@MainActor
final class AudioProcessMonitor: ObservableObject {
    @Published private(set) var apps: [AudioApp] = []

    private let sys = AudioObjectID(kAudioObjectSystemObject)
    private var listening = false
    private var listenerBlock: AudioObjectPropertyListenerBlock?

    func start() {
        guard !listening else { return }
        listening = true
        var addr = Self.listAddr
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refresh()
        }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(sys, &addr, DispatchQueue.main, block)
        refresh()
    }

    func stop() {
        guard listening else { return }
        listening = false
        guard let block = listenerBlock else { return }
        var addr = Self.listAddr
        AudioObjectRemovePropertyListenerBlock(sys, &addr, DispatchQueue.main, block)
        listenerBlock = nil
    }

    func refresh() {
        let infos = Self.readProcesses()
        apps = AudioApp.grouped(from: infos) { Self.appName(for: $0) }
    }

    private static var listAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private static func readProcesses() -> [AudioProcessInfo] {
        let sys = AudioObjectID(kAudioObjectSystemObject)
        var addr = listAddr
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { obj in
            guard let bundle = stringProp(obj, kAudioProcessPropertyBundleID), !bundle.isEmpty else { return nil }
            return AudioProcessInfo(
                objectID: obj,
                pid: pidProp(obj),
                bundleID: bundle,
                isRunningOutput: boolProp(obj, kAudioProcessPropertyIsRunningOutput)
            )
        }
    }

    private static func stringProp(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cf: CFString?
        let st = withUnsafeMutablePointer(to: &cf) { AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, $0) }
        return st == noErr ? (cf as String?) : nil
    }
    private static func pidProp(_ obj: AudioObjectID) -> Int32 {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<pid_t>.size); var pid: pid_t = -1
        AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &pid); return pid
    }
    private static func boolProp(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<UInt32>.size); var v: UInt32 = 0
        AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &v); return v != 0
    }

    private static func appName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let name = FileManager.default.displayName(atPath: url.path) as String? {
            return name.replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }
}
