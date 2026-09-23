# Per-App Audio Mixer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-app volume mixer tab to Perde that sets each app's output volume, mutes it, and routes it to a chosen output device, using Core Audio process taps (no driver).

**Architecture:** A pure model/logic layer (settings, grouping, row merge) is unit-tested; a thin Core Audio layer (`AudioProcessMonitor`, `AppAudioController`, output-device enumeration) is manually verified. `AudioMixerStore` binds them to a new SwiftUI `MixerView` tab. An app is only tapped when diverted from default (volume < 100%, muted, or non-default output); otherwise it plays untouched.

**Tech Stack:** Swift 6, SwiftUI, Core Audio (CATapDescription / AudioHardwareCreateProcessTap / aggregate devices / IOProc), UserDefaults.

**Spec:** `docs/superpowers/specs/2026-09-23-audio-mixer-design.md`

## Global Constraints

- Platform floor: macOS 15+ (process taps need 14.4+; already satisfied). Copy: `.macOS(.v15)`.
- No code comments (repo convention); English identifiers; Turkish user-facing strings.
- Match existing view patterns and `Theme` tokens; no third-party UI libraries.
- New source files live under `Sources/Perde/Audio/`. Tests under `Tests/PerdeTests/`.
- Commits: no `Co-Authored-By` trailer.
- Run tests with `swift test`. Build the app with `make build`.

---

### Task 1: `AppAudioSetting` model

**Files:**
- Create: `Sources/Perde/Audio/AppAudioSetting.swift`
- Test: `Tests/PerdeTests/AppAudioSettingTests.swift`

**Interfaces:**
- Produces: `struct AppAudioSetting: Codable, Equatable { var volume: Double; var muted: Bool; var outputDeviceUID: String? }`, `AppAudioSetting.default`, `var isDefault: Bool`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppAudioSettingTests`
Expected: FAIL (cannot find `AppAudioSetting`).

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct AppAudioSetting: Codable, Equatable {
    var volume: Double
    var muted: Bool
    var outputDeviceUID: String?

    static let `default` = AppAudioSetting(volume: 1.0, muted: false, outputDeviceUID: nil)

    var isDefault: Bool {
        volume >= 1.0 && !muted && outputDeviceUID == nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppAudioSettingTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Perde/Audio/AppAudioSetting.swift Tests/PerdeTests/AppAudioSettingTests.swift
git commit -m "audio: add AppAudioSetting model"
```

---

### Task 2: `AudioApp` model + process grouping

**Files:**
- Create: `Sources/Perde/Audio/AudioApp.swift`
- Test: `Tests/PerdeTests/AudioAppTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct AudioProcessInfo: Equatable { let objectID: UInt32; let pid: Int32; let bundleID: String; let isRunningOutput: Bool }`
  - `struct AudioApp: Identifiable, Equatable { let bundleID: String; let name: String; let objectIDs: [UInt32]; let isPlaying: Bool; var id: String { bundleID } }`
  - `static func AudioApp.grouped(from processes: [AudioProcessInfo], name: (String) -> String) -> [AudioApp]` — groups by `bundleID`, unions `objectIDs`, `isPlaying` = any `isRunningOutput`, sorted by name.

- [ ] **Step 1: Write the failing test**

```swift
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
```

Note: grouping maps `com.google.Chrome.helper` to its parent `com.google.Chrome` by stripping a trailing `.helper*` suffix; other bundle IDs map to themselves.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioAppTests`
Expected: FAIL (cannot find `AudioApp`).

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct AudioProcessInfo: Equatable {
    let objectID: UInt32
    let pid: Int32
    let bundleID: String
    let isRunningOutput: Bool
}

struct AudioApp: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let objectIDs: [UInt32]
    let isPlaying: Bool
    var id: String { bundleID }

    static func parentBundle(_ bundleID: String) -> String {
        if let range = bundleID.range(of: ".helper", options: [.caseInsensitive]) {
            return String(bundleID[..<range.lowerBound])
        }
        return bundleID
    }

    static func grouped(from processes: [AudioProcessInfo], name: (String) -> String) -> [AudioApp] {
        var byBundle: [String: [AudioProcessInfo]] = [:]
        for p in processes where !p.bundleID.isEmpty {
            byBundle[parentBundle(p.bundleID), default: []].append(p)
        }
        return byBundle.map { bundle, procs in
            AudioApp(
                bundleID: bundle,
                name: name(bundle),
                objectIDs: procs.map(\.objectID),
                isPlaying: procs.contains { $0.isRunningOutput }
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AudioAppTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Perde/Audio/AudioApp.swift Tests/PerdeTests/AudioAppTests.swift
git commit -m "audio: add AudioApp model and process grouping"
```

---

### Task 3: Mixer-row merge logic

**Files:**
- Create: `Sources/Perde/Audio/MixerRow.swift`
- Test: `Tests/PerdeTests/MixerRowTests.swift`

**Interfaces:**
- Consumes: `AudioApp` (Task 2), `AppAudioSetting` (Task 1).
- Produces:
  - `struct MixerRow: Identifiable, Equatable { let app: AudioApp; let setting: AppAudioSetting; var id: String { app.bundleID } }`
  - `enum MixerListSource { case playingOnly, all }`
  - `static func MixerRow.build(apps: [AudioApp], settings: [String: AppAudioSetting], source: MixerListSource) -> [MixerRow]` — filters apps by source (`.playingOnly` keeps `isPlaying`), attaches the saved setting or `.default`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import Perde

final class MixerRowTests: XCTestCase {
    let spotify = AudioApp(bundleID: "com.spotify.client", name: "Spotify", objectIDs: [1], isPlaying: true)
    let idle = AudioApp(bundleID: "com.apple.Music", name: "Music", objectIDs: [2], isPlaying: false)

    func testPlayingOnlyFiltersIdleApps() {
        let rows = MixerRow.build(apps: [spotify, idle], settings: [:], source: .playingOnly)
        XCTAssertEqual(rows.map(\.app.bundleID), ["com.spotify.client"])
    }
    func testAllIncludesIdleApps() {
        let rows = MixerRow.build(apps: [spotify, idle], settings: [:], source: .all)
        XCTAssertEqual(rows.count, 2)
    }
    func testAttachesSavedSetting() {
        let saved = ["com.spotify.client": AppAudioSetting(volume: 0.5, muted: false, outputDeviceUID: nil)]
        let rows = MixerRow.build(apps: [spotify], settings: saved, source: .all)
        XCTAssertEqual(rows.first?.setting.volume, 0.5)
    }
    func testDefaultWhenNoSetting() {
        let rows = MixerRow.build(apps: [spotify], settings: [:], source: .all)
        XCTAssertTrue(rows.first?.setting.isDefault == true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MixerRowTests`
Expected: FAIL (cannot find `MixerRow`).

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

enum MixerListSource: String {
    case playingOnly
    case all
}

struct MixerRow: Identifiable, Equatable {
    let app: AudioApp
    let setting: AppAudioSetting
    var id: String { app.bundleID }

    static func build(apps: [AudioApp], settings: [String: AppAudioSetting], source: MixerListSource) -> [MixerRow] {
        apps
            .filter { source == .all || $0.isPlaying }
            .map { MixerRow(app: $0, setting: settings[$0.bundleID] ?? .default) }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MixerRowTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Perde/Audio/MixerRow.swift Tests/PerdeTests/MixerRowTests.swift
git commit -m "audio: add mixer row merge logic"
```

---

### Task 4: `AudioProcessMonitor` (Core Audio read)

**Files:**
- Create: `Sources/Perde/Audio/AudioProcessMonitor.swift`
- Test: manual (Core Audio; no unit test).

**Interfaces:**
- Consumes: `AudioProcessInfo`, `AudioApp` (Task 2).
- Produces: `@MainActor final class AudioProcessMonitor: ObservableObject { @Published private(set) var apps: [AudioApp]; func start(); func stop() }`. Internally reads the process list and calls `AudioApp.grouped`.

- [ ] **Step 1: Implement**

```swift
import Foundation
import CoreAudio
import AppKit

@MainActor
final class AudioProcessMonitor: ObservableObject {
    @Published private(set) var apps: [AudioApp] = []

    private let sys = AudioObjectID(kAudioObjectSystemObject)
    private var listening = false

    func start() {
        guard !listening else { return }
        listening = true
        var addr = Self.listAddr
        AudioObjectAddPropertyListenerBlock(sys, &addr, DispatchQueue.main) { [weak self] _, _ in
            self?.refresh()
        }
        refresh()
    }

    func stop() {
        guard listening else { return }
        listening = false
        var addr = Self.listAddr
        AudioObjectRemovePropertyListenerBlock(sys, &addr, DispatchQueue.main) { _, _ in }
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
```

- [ ] **Step 2: Build**

Run: `make build`
Expected: builds cleanly.

- [ ] **Step 3: Manual verify**

Temporarily call `monitor.start()` from a scratch entry point (or verify in Task 9 once wired). With Spotify playing, `apps` should contain a `Spotify` entry with `isPlaying == true`. Confirm helper-based apps (Chrome) appear as one row.

- [ ] **Step 4: Commit**

```bash
git add Sources/Perde/Audio/AudioProcessMonitor.swift
git commit -m "audio: add AudioProcessMonitor"
```

---

### Task 5: Output-device enumeration

**Files:**
- Create: `Sources/Perde/Audio/OutputDevices.swift`
- Test: manual (Core Audio).

**Interfaces:**
- Produces:
  - `struct OutputDevice: Identifiable, Equatable { let uid: String; let name: String; var id: String { uid } }`
  - `enum OutputDevices { static func list() -> [OutputDevice]; static func defaultUID() -> String? }`

- [ ] **Step 1: Implement**

```swift
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
        let abl = UnsafeMutableAudioBufferListPointer(AudioBufferList.allocate(maximumBuffers: Int(size) / MemoryLayout<AudioBuffer>.size))
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
```

- [ ] **Step 2: Build & manual verify**

Run: `make build`. Print `OutputDevices.list()` from a scratch call; expect at least the built-in speakers, each with a UID and readable name. `defaultUID()` returns the current output.

- [ ] **Step 3: Commit**

```bash
git add Sources/Perde/Audio/OutputDevices.swift
git commit -m "audio: add output device enumeration"
```

---

### Task 6: `AppAudioController` engine

**Files:**
- Create: `Sources/Perde/Audio/AppAudioController.swift`
- Test: `Tests/PerdeTests/AudioGainTests.swift` (pure gain) + manual (routing).

**Interfaces:**
- Consumes: `AppAudioSetting` (Task 1), `OutputDevices` (Task 5).
- Produces:
  - `static func AppAudioController.effectiveGain(_ setting: AppAudioSetting) -> Float` — `muted ? 0 : Float(clamp(volume, 0...1))`.
  - `@MainActor final class AppAudioController { init(objectIDs: [UInt32]); func apply(_ setting: AppAudioSetting); func teardown() }` — builds/rebuilds the tap+aggregate+IOProc chain; `apply` with a default setting tears down.

- [ ] **Step 1: Write the failing gain test**

```swift
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
        XCTAssertEqual(AppAudioController.effectiveGain(AppAudioSetting(volume: 2.0, muted: false, outputDeviceUID: nil)), 1.0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioGainTests`
Expected: FAIL (cannot find `AppAudioController`).

- [ ] **Step 3: Implement the controller**

```swift
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

    init(objectIDs: [UInt32]) { self.objectIDs = objectIDs.map(AudioObjectID.init) }

    static func effectiveGain(_ setting: AppAudioSetting) -> Float {
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
```

- [ ] **Step 4: Run gain test + build**

Run: `swift test --filter AudioGainTests` → PASS. Then `make build` → clean.

- [ ] **Step 5: Manual verify (routing)**

Wire a scratch call: create `AppAudioController(objectIDs:)` for Spotify's object IDs, `apply(AppAudioSetting(volume: 0.25, muted: false, outputDeviceUID: nil))`. Confirm Spotify audibly drops to ~25% while another app stays full; `apply(.default)` restores it. This reproduces the proven spike.

- [ ] **Step 6: Commit**

```bash
git add Sources/Perde/Audio/AppAudioController.swift Tests/PerdeTests/AudioGainTests.swift
git commit -m "audio: add AppAudioController engine"
```

---

### Task 7: `AudioMixerStore`

**Files:**
- Create: `Sources/Perde/Audio/AudioMixerStore.swift`
- Test: `Tests/PerdeTests/AudioMixerStoreTests.swift` (persistence round-trip only).

**Interfaces:**
- Consumes: `AudioProcessMonitor` (4), `AppAudioController` (6), `MixerRow`/`MixerListSource` (3), `AppAudioSetting` (1), `OutputDevices` (5).
- Produces: `@MainActor final class AudioMixerStore: ObservableObject { @Published private(set) var rows: [MixerRow]; @Published var listSource: MixerListSource; var outputs: [OutputDevice]; func start(); func stop(); func setVolume(_ v: Double, for bundleID: String); func setMuted(_ m: Bool, for bundleID: String); func setOutput(_ uid: String?, for bundleID: String); func reset(_ bundleID: String) }`
- Persistence: `settings: [String: AppAudioSetting]` saved to `UserDefaults` under `perde.mixerSettings` as JSON; static helpers `encodeSettings`/`decodeSettings` are the unit-tested seam.

- [ ] **Step 1: Write the failing persistence test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioMixerStoreTests`
Expected: FAIL (cannot find `AudioMixerStore`).

- [ ] **Step 3: Implement**

```swift
import Foundation
import Combine

@MainActor
final class AudioMixerStore: ObservableObject {
    @Published private(set) var rows: [MixerRow] = []
    @Published var listSource: MixerListSource {
        didSet { UserDefaults.standard.set(listSource.rawValue, forKey: Self.sourceKey); rebuildRows() }
    }
    private(set) var outputs: [OutputDevice] = []

    private let monitor = AudioProcessMonitor()
    private var controllers: [String: AppAudioController] = [:]
    private var settings: [String: AppAudioSetting]
    private var cancellables = Set<AnyCancellable>()

    static let settingsKey = "perde.mixerSettings"
    static let sourceKey = "perde.mixerListSource"

    init() {
        settings = Self.decodeSettings(UserDefaults.standard.data(forKey: Self.settingsKey))
        listSource = MixerListSource(rawValue: UserDefaults.standard.string(forKey: Self.sourceKey) ?? "") ?? .playingOnly
    }

    func start() {
        outputs = OutputDevices.list()
        monitor.$apps
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyAndRebuild() }
            .store(in: &cancellables)
        monitor.start()
    }

    func stop() {
        monitor.stop()
        controllers.values.forEach { $0.teardown() }
        controllers.removeAll()
    }

    func setVolume(_ v: Double, for bundleID: String) { mutate(bundleID) { $0.volume = v } }
    func setMuted(_ m: Bool, for bundleID: String) { mutate(bundleID) { $0.muted = m } }
    func setOutput(_ uid: String?, for bundleID: String) { mutate(bundleID) { $0.outputDeviceUID = uid } }
    func reset(_ bundleID: String) {
        settings[bundleID] = nil
        controllers[bundleID]?.teardown()
        controllers[bundleID] = nil
        persist(); rebuildRows()
    }

    private func mutate(_ bundleID: String, _ change: (inout AppAudioSetting) -> Void) {
        var s = settings[bundleID] ?? .default
        change(&s)
        if s.isDefault { settings[bundleID] = nil } else { settings[bundleID] = s }
        applyController(bundleID: bundleID, setting: s)
        persist(); rebuildRows()
    }

    private func applyAndRebuild() {
        for app in monitor.apps {
            if let s = settings[app.bundleID], !s.isDefault {
                applyController(bundleID: app.bundleID, setting: s, objectIDs: app.objectIDs)
            }
        }
        rebuildRows()
    }

    private func applyController(bundleID: String, setting: AppAudioSetting, objectIDs: [UInt32]? = nil) {
        if setting.isDefault {
            controllers[bundleID]?.teardown(); controllers[bundleID] = nil; return
        }
        let ids = objectIDs ?? monitor.apps.first { $0.bundleID == bundleID }?.objectIDs ?? []
        guard !ids.isEmpty else { return }
        let controller = controllers[bundleID] ?? AppAudioController(objectIDs: ids)
        controllers[bundleID] = controller
        controller.apply(setting)
    }

    private func rebuildRows() {
        rows = MixerRow.build(apps: monitor.apps, settings: settings, source: listSource)
    }

    private func persist() { UserDefaults.standard.set(Self.encodeSettings(settings), forKey: Self.settingsKey) }

    static func encodeSettings(_ s: [String: AppAudioSetting]) -> Data { (try? JSONEncoder().encode(s)) ?? Data() }
    static func decodeSettings(_ data: Data?) -> [String: AppAudioSetting] {
        guard let data, let s = try? JSONDecoder().decode([String: AppAudioSetting].self, from: data) else { return [:] }
        return s
    }
}
```

- [ ] **Step 4: Run test + build**

Run: `swift test --filter AudioMixerStoreTests` → PASS. `make build` → clean.

- [ ] **Step 5: Commit**

```bash
git add Sources/Perde/Audio/AudioMixerStore.swift Tests/PerdeTests/AudioMixerStoreTests.swift
git commit -m "audio: add AudioMixerStore"
```

---

### Task 8: Notch integration (tab enum, geometry, routing)

**Files:**
- Modify: `Sources/Perde/Notch/NotchViewModel.swift` (add `.mixer` to `NotchTab`)
- Modify: `Sources/Perde/Notch/NotchGeometry.swift:18-24` (add `.mixer` content size)
- Modify: `Sources/Perde/Views/NotchRootView.swift` (store + switch case)
- Test: manual (`make build` + open).

**Interfaces:**
- Consumes: `AudioMixerStore` (Task 7), `MixerView` (Task 9 — placeholder `Text("")` until Task 9 lands, or order Task 9 before wiring the body; here we route to `MixerView(store:)`).

- [ ] **Step 1: Add the enum case**

In `NotchTab`, add `case mixer` to the enum and each switch:
```swift
case mixer   // in enum, after clipboard
// icon:
case .mixer: return "slider.vertical.3"
// id:
case .mixer: return "mixer"
// title:
case .mixer: return "Ses Mikseri"
```

- [ ] **Step 2: Add the card size**

In `NotchGeometry.contentSize(for:showLyrics:)` add:
```swift
case .mixer: return CGSize(width: 420, height: 300)
```

- [ ] **Step 3: Route in NotchRootView**

Add a store next to the others:
```swift
@StateObject private var mixerStore = AudioMixerStore()
```
Add the switch case in `expandedContent`:
```swift
case .mixer:
    MixerView(store: mixerStore)
```
Start/stop with expansion — in the existing `.onAppear` of `expandedContent` add `mixerStore.start()`; the store's monitor is lightweight, leaving it running is acceptable.

- [ ] **Step 4: Build**

Run: `make build`
Expected: builds (with `MixerView` from Task 9 present; sequence Task 9 before Step 4 if executing strictly in order).

- [ ] **Step 5: Commit**

```bash
git add Sources/Perde/Notch/NotchViewModel.swift Sources/Perde/Notch/NotchGeometry.swift Sources/Perde/Views/NotchRootView.swift
git commit -m "notch: add mixer tab integration"
```

---

### Task 9: `MixerView` UI

**Files:**
- Create: `Sources/Perde/Views/MixerView.swift`
- Test: manual.

**Interfaces:**
- Consumes: `AudioMixerStore` (Task 7), `MixerRow` (3), `OutputDevice` (5), `Theme`.

- [ ] **Step 1: Implement**

```swift
import SwiftUI
import AppKit

struct MixerView: View {
    @ObservedObject var store: AudioMixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SES MİKSERİ")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)

            if store.rows.isEmpty {
                Spacer()
                Text("Ses çalan uygulama yok")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.rows) { row in rowView(row) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.start() }
    }

    private func rowView(_ row: MixerRow) -> some View {
        let bundleID = row.app.bundleID
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                icon(for: bundleID)
                Text(row.app.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.primaryText).lineLimit(1)
                Spacer(minLength: 4)
                outputMenu(row)
            }
            HStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { row.setting.muted ? 0 : row.setting.volume },
                        set: { store.setVolume($0, for: bundleID) }
                    ),
                    in: 0...1
                )
                Text("\(Int((row.setting.muted ? 0 : row.setting.volume) * 100))%")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.secondaryText)
                    .frame(width: 38, alignment: .trailing)
                Button { store.reset(bundleID) } label: {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(Theme.tertiaryText)
                Button { store.setMuted(!row.setting.muted, for: bundleID) } label: {
                    Image(systemName: row.setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(row.setting.muted ? Theme.accent : Theme.secondaryText)
            }
        }
        .padding(9)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func icon(for bundleID: String) -> some View {
        let image: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return Image(nsImage: image).resizable().frame(width: 22, height: 22)
    }

    private func outputMenu(_ row: MixerRow) -> some View {
        Menu {
            Button("Varsayılan") { store.setOutput(nil, for: row.app.bundleID) }
            ForEach(store.outputs) { dev in
                Button(dev.name) { store.setOutput(dev.uid, for: row.app.bundleID) }
            }
        } label: {
            Text(outputLabel(for: row))
                .font(.system(size: 10.5, weight: .medium)).foregroundStyle(Theme.secondaryText)
                .lineLimit(1).frame(maxWidth: 90)
        }
        .menuStyle(.button).buttonStyle(.plain).fixedSize()
    }

    private func outputLabel(for row: MixerRow) -> String {
        guard let uid = row.setting.outputDeviceUID else { return "Varsayılan" }
        return store.outputs.first { $0.uid == uid }?.name ?? "Varsayılan"
    }
}
```

- [ ] **Step 2: Build & manual verify**

Run: `make build && open build/Perde.app`. Open the notch, select the mixer tab. With Spotify + a browser playing: both rows appear; drag Spotify to 50% → only Spotify drops; mute toggles; output menu lists devices; reset returns to 100%.

- [ ] **Step 3: Commit**

```bash
git add Sources/Perde/Views/MixerView.swift
git commit -m "mixer: add MixerView UI"
```

---

### Task 10: Settings (tab toggle default + list source) + Info.plist

**Files:**
- Modify: `Sources/Perde/System/SettingsStore.swift` (mixer in default enabled tabs; `mixerListSource` passthrough is owned by the store, so Settings only needs the tab toggle — see note)
- Modify: `Sources/Perde/Views/SettingsView.swift` (mixer toggle appears automatically via `NotchTab.allCases`; add the list-source picker)
- Modify: `Resources/Info.plist` (audio-capture usage description)
- Test: manual.

**Interfaces:**
- Consumes: `MixerListSource` (3), `AudioMixerStore` (7 — for the picker binding, expose the store to Settings, or read/write `UserDefaults` key `perde.mixerListSource` directly in SettingsView to avoid coupling).

- [ ] **Step 1: Default-enable the mixer tab**

`SettingsStore` already defaults `enabledTabIDs` to `NotchTab.allCases.map(\.id)`, so a fresh install includes `mixer`. For existing users whose saved set predates the mixer, add a one-line migration in `init()` after loading `enabledTabIDs`:
```swift
enabledTabIDs.insert(NotchTab.mixer.id)
```

- [ ] **Step 2: Add the list-source picker to SettingsView**

In the tabs/settings section, add (reads/writes the same key the store uses):
```swift
Picker("Mikser listesi", selection: Binding(
    get: { UserDefaults.standard.string(forKey: "perde.mixerListSource") ?? "playingOnly" },
    set: { UserDefaults.standard.set($0, forKey: "perde.mixerListSource") }
)) {
    Text("Sadece ses çalanlar").tag("playingOnly")
    Text("Tüm uygulamalar").tag("all")
}
```
Note: the mixer tab on/off toggle is already rendered by the existing per-tab loop over `NotchTab.allCases`; no extra toggle code needed.

- [ ] **Step 3: Add Info.plist usage description**

Add to `Resources/Info.plist` (precaution for the audio-capture TCC prompt on clean installs):
```xml
<key>NSAudioCaptureUsageDescription</key>
<string>Perde, uygulama-bazlı ses seviyesini ayarlamak için ses akışını okur.</string>
```

- [ ] **Step 4: Build & manual verify**

Run: `make build && open build/Perde.app`. In Settings: the "Ses Mikseri" tab toggle disables/enables the tab; the "Mikser listesi" picker switches the mixer between playing-only and all apps (observe the mixer list change after reopening the tab).

- [ ] **Step 5: Commit**

```bash
git add Sources/Perde/System/SettingsStore.swift Sources/Perde/Views/SettingsView.swift Resources/Info.plist
git commit -m "mixer: settings toggle, list-source preference, audio usage description"
```

---

## Self-Review

**Spec coverage:**
- Per-app volume → Tasks 6, 7, 9. Mute → 6, 7, 9. Output routing → 5, 6, 7, 9. Reset → 7, 9. List-source preference → 3, 7, 10. Persistence by bundle ID → 1, 7. Helper-process grouping → 2, 4. Monitor → 4. Engine/tap/aggregate/IOProc → 6. Store/data flow → 7. Notch tab integration → 8. UI → 9. Settings + Info.plist/permission → 10. Error handling (default fallback, teardown) → 6, 7. Unit tests for pure logic → 1, 2, 3, 6, 7. All spec sections map to a task.

**Placeholder scan:** No TBD/TODO; every code step has concrete code; manual-verify steps name exact expected behavior.

**Type consistency:** `AppAudioSetting`, `AudioApp`/`AudioProcessInfo`, `MixerRow`/`MixerListSource`, `OutputDevice`/`OutputDevices`, `AppAudioController.effectiveGain`/`apply`/`teardown`, `AudioMixerStore` method names are used identically across tasks. `NotchTab.mixer` id `"mixer"` matches the settings key usage.

**Known ordering note:** Task 8 wires `MixerView(store:)`, which is created in Task 9. When executing strictly in order, implement Task 9 before building Task 8 (or stub `MixerView` as `Text("")` in Task 8 Step 3 and replace in Task 9). Both tasks land in the same integration slice.
