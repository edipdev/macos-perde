import Foundation
import CoreAudio
import AudioToolbox

@MainActor
final class AppAudioController {
    private let objectIDs: [AudioObjectID]
    private var tapID: AudioObjectID = 0
    private var aggID: AudioDeviceID = 0
    private var procID: AudioDeviceIOProcID?
    private var gain: Float = 1.0

    init(objectIDs: [UInt32]) { self.objectIDs = objectIDs }

    nonisolated static func effectiveGain(_ setting: AppAudioSetting) -> Float {
        if setting.muted { return 0 }
        return Float(min(max(setting.volume, 0), 1))
    }

    func apply(_ setting: AppAudioSetting) {
        gain = Self.effectiveGain(setting)
        if setting.isDefault { teardown(); return }
        let outUID = setting.outputDeviceUID ?? OutputDevices.defaultUID()
        rebuild(outputUID: outUID)
    }

    func teardown() {
        if let procID { AudioDeviceStop(aggID, procID); AudioDeviceDestroyIOProcID(aggID, procID) }
        procID = nil
        if aggID != 0 { AudioHardwareDestroyAggregateDevice(aggID); aggID = 0 }
        if tapID != 0 { AudioHardwareDestroyProcessTap(tapID); tapID = 0 }
    }

    private func rebuild(outputUID: String?) {
        teardown()
        guard let outputUID else { return }

        let desc = CATapDescription(stereoMixdownOfProcesses: objectIDs)
        desc.name = "PerdeMixerTap"
        desc.isPrivate = true
        desc.muteBehavior = .mutedWhenTapped
        guard AudioHardwareCreateProcessTap(desc, &tapID) == noErr, tapID != 0 else { return }
        let tapUID = tapUIDString() ?? desc.uuid.uuidString

        let aggDesc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "PerdeMixerAgg-\(objectIDs.first ?? 0)",
            kAudioAggregateDeviceUIDKey: "com.perde.mixer.\(objectIDs.first ?? 0)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUID, kAudioSubTapDriftCompensationKey: true]],
            kAudioAggregateDeviceTapAutoStartKey: true,
        ]
        guard AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggID) == noErr, aggID != 0 else {
            teardown(); return
        }

        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, nil) { [weak self] _, inData, _, outData, _ in
            let g = self?.gain ?? 0
            let inABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
            let outABL = UnsafeMutableAudioBufferListPointer(outData)
            for i in 0..<min(inABL.count, outABL.count) {
                guard let s = inABL[i].mData, let d = outABL[i].mData else { continue }
                let bytes = min(inABL[i].mDataByteSize, outABL[i].mDataByteSize)
                let n = Int(bytes) / MemoryLayout<Float>.size
                let sp = s.assumingMemoryBound(to: Float.self)
                let dp = d.assumingMemoryBound(to: Float.self)
                for f in 0..<n { dp[f] = sp[f] * g }
                if outABL[i].mDataByteSize > bytes { memset(d.advanced(by: Int(bytes)), 0, Int(outABL[i].mDataByteSize - bytes)) }
            }
        }
        guard status == noErr, let procID else { teardown(); return }
        AudioDeviceStart(aggID, procID)
    }

    private func tapUIDString() -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<CFString?>.size); var cf: CFString?
        let st = withUnsafeMutablePointer(to: &cf) { AudioObjectGetPropertyData(tapID, &addr, 0, nil, &size, $0) }
        return st == noErr ? (cf as String?) : nil
    }
}
