import Carbon
import RishabhWMCore

/// Global hotkeys through Carbon's RegisterEventHotKey: no Input Monitoring permission, no event tap.
final class HotKeys {
    static let shared = HotKeys()

    private var refs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var installed = false

    private init() {}

    func install() {
        guard !installed else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKey
            )
            HotKeys.shared.fire(hotKey.id)
            return noErr
        }, 1, &spec, nil, nil)
        installed = status == noErr
        if !installed { Log.error("could not install hotkey handler (\(status))") }
    }

    /// Replaces every registered hotkey with `bindings`.
    func set(_ bindings: [Binding], handler: @escaping (Binding) -> Void) {
        unregisterAll()
        for binding in bindings {
            guard let code = KeyCodes.code(for: binding.combo.key) else {
                Log.error("no key code for \(binding.combo.key)")
                continue
            }
            let modifiers = (binding.combo.option ? UInt32(optionKey) : 0) | (binding.combo.shift ? UInt32(shiftKey) : 0)
            register(keyCode: code, modifiers: modifiers) { handler(binding) }
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32, _ handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5257_4D31), id: id) // "RWM1"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.error("hotkey \(keyCode)/\(modifiers) taken by another app (\(status))")
            return
        }
        refs.append(ref)
        handlers[id] = handler
    }

    private func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        handlers = [:]
    }

    private func fire(_ id: UInt32) {
        handlers[id]?()
    }
}

enum KeyCodes {
    private static let table: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
        "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
        "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
        "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y,
        "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "minus": kVK_ANSI_Minus, "equal": kVK_ANSI_Equal, "slash": kVK_ANSI_Slash,
        "comma": kVK_ANSI_Comma, "semicolon": kVK_ANSI_Semicolon,
        "leftbracket": kVK_ANSI_LeftBracket, "rightbracket": kVK_ANSI_RightBracket,
        "tab": kVK_Tab, "escape": kVK_Escape, "backspace": kVK_Delete,
    ]

    static func code(for key: String) -> UInt32? { table[key].map { UInt32($0) } }
}
