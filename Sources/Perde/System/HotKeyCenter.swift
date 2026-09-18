import Carbon.HIToolbox
import Foundation

final class HotKeyCenter: @unchecked Sendable {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var installed = false

    func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
    }

    func register(keyCode: Int, cmd: Bool = false, option: Bool = false,
                  shift: Bool = false, control: Bool = false,
                  handler: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        handlers[id] = handler

        var modifiers: UInt32 = 0
        if cmd { modifiers |= UInt32(cmdKey) }
        if option { modifiers |= UInt32(optionKey) }
        if shift { modifiers |= UInt32(shiftKey) }
        if control { modifiers |= UInt32(controlKey) }

        let hotKeyID = EventHotKeyID(signature: OSType(0x50524445), id: id)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &ref)
        if let ref { refs.append(ref) }
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async { HotKeyCenter.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    private func fire(_ id: UInt32) {
        handlers[id]?()
    }
}
