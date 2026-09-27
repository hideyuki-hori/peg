import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var installed = false
    private static let signature: OSType = 0x50454731

    private var reference: EventHotKeyRef?
    private let id: UInt32

    init?(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        HotKey.install()
        id = HotKey.nextID
        HotKey.nextID += 1
        let hotKeyID = EventHotKeyID(signature: HotKey.signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr else { return nil }
        HotKey.handlers[id] = handler
    }

    func unregister() {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        reference = nil
        HotKey.handlers[id] = nil
    }

    static func dispatch(_ id: UInt32) {
        handlers[id]?()
    }

    private static func install() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let id = hotKeyID.id
                MainActor.assumeIsolated {
                    HotKey.dispatch(id)
                }
                return noErr
            },
            1,
            &spec,
            nil,
            nil
        )
    }
}
