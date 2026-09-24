import Foundation
import CoreAudio
import AppKit

@MainActor
final class AudioProcessMonitor: ObservableObject {
    @Published private(set) var apps: [AudioApp] = []

    private let sys = AudioObjectID(kAudioObjectSystemObject)
    private var listening = false
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var timer: Timer?

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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        guard listening else { return }
        listening = false
        guard let block = listenerBlock else { return }
        var addr = Self.listAddr
        AudioObjectRemovePropertyListenerBlock(sys, &addr, DispatchQueue.main, block)
        listenerBlock = nil
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let apps = Self.realApps()
        let infos = Self.readProcesses().filter { apps[AudioApp.parentBundle($0.bundleID)] != nil }
        let newApps = AudioApp.grouped(from: infos) { apps[$0] ?? Self.appName(for: $0) }
        if newApps != self.apps { self.apps = newApps }
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

    private static func realApps() -> [String: String] {
        var map: [String: String] = [:]
        let selfID = Bundle.main.bundleIdentifier
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular || app.activationPolicy == .accessory {
            guard let bid = app.bundleIdentifier, bid != selfID else { continue }
            map[bid] = app.localizedName ?? bid
        }
        return map
    }
}
