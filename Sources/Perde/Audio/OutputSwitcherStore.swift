import Foundation
import CoreAudio

@MainActor
final class OutputSwitcherStore: ObservableObject {
    @Published private(set) var devices: [OutputDevice] = []
    @Published private(set) var currentUID: String? = nil

    private let sys = AudioObjectID(kAudioObjectSystemObject)
    private var started = false
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var devicesListenerBlock: AudioObjectPropertyListenerBlock?

    func start() {
        guard !started else { return }
        started = true
        devices = OutputDevices.list()
        currentUID = OutputDevices.defaultUID()

        var defaultAddr = Self.defaultOutputAddr
        let defaultBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.currentUID = OutputDevices.defaultUID()
        }
        defaultDeviceListenerBlock = defaultBlock
        AudioObjectAddPropertyListenerBlock(sys, &defaultAddr, DispatchQueue.main, defaultBlock)

        var devicesAddr = Self.devicesAddr
        let devicesBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.devices = OutputDevices.list()
        }
        devicesListenerBlock = devicesBlock
        AudioObjectAddPropertyListenerBlock(sys, &devicesAddr, DispatchQueue.main, devicesBlock)
    }

    func stop() {
        guard started else { return }
        started = false
        if let block = defaultDeviceListenerBlock {
            var addr = Self.defaultOutputAddr
            AudioObjectRemovePropertyListenerBlock(sys, &addr, DispatchQueue.main, block)
            defaultDeviceListenerBlock = nil
        }
        if let block = devicesListenerBlock {
            var addr = Self.devicesAddr
            AudioObjectRemovePropertyListenerBlock(sys, &addr, DispatchQueue.main, block)
            devicesListenerBlock = nil
        }
    }

    func select(_ uid: String) {
        OutputDevices.setDefaultOutput(uid: uid)
    }

    private static var defaultOutputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private static var devicesAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
}
