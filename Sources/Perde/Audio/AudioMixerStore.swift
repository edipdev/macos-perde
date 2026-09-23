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
    private var started = false

    static let settingsKey = "perde.mixerSettings"
    static let sourceKey = "perde.mixerListSource"

    init() {
        settings = Self.decodeSettings(UserDefaults.standard.data(forKey: Self.settingsKey))
        listSource = MixerListSource(rawValue: UserDefaults.standard.string(forKey: Self.sourceKey) ?? "") ?? .playingOnly
    }

    func start() {
        guard !started else { return }
        started = true
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
        cancellables.removeAll()
        started = false
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
        let present = Set(monitor.apps.map(\.bundleID))
        for bundleID in Array(controllers.keys) where !present.contains(bundleID) {
            controllers[bundleID]?.teardown()
            controllers[bundleID] = nil
        }
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
        if let existing = controllers[bundleID], existing.objectIDs != ids {
            existing.teardown(); controllers[bundleID] = nil
        }
        let controller = controllers[bundleID] ?? AppAudioController(objectIDs: ids)
        controllers[bundleID] = controller
        controller.apply(setting)
    }

    private func rebuildRows() {
        rows = MixerRow.build(apps: monitor.apps, settings: settings, source: listSource)
    }

    private func persist() { UserDefaults.standard.set(Self.encodeSettings(settings), forKey: Self.settingsKey) }

    nonisolated static func encodeSettings(_ s: [String: AppAudioSetting]) -> Data { (try? JSONEncoder().encode(s)) ?? Data() }
    nonisolated static func decodeSettings(_ data: Data?) -> [String: AppAudioSetting] {
        guard let data, let s = try? JSONDecoder().decode([String: AppAudioSetting].self, from: data) else { return [:] }
        return s
    }
}
