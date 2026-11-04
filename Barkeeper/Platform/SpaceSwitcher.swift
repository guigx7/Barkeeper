import CoreGraphics
import Foundation

/// Moves to the desktop (Space) on the left/right by sending the system's own "Move left/right a
/// space" shortcut (System Settings → Keyboard → Shortcuts → Mission Control), read from the user's
/// settings so a rebound shortcut still works.
enum SpaceSwitcher {
    enum Direction { case left, right }

    /// Symbolic hot key IDs: 79 = move left a space, 81 = move right a space.
    private static func shortcut(_ direction: Direction) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        let id = direction == .left ? "79" : "81"
        let fallback: (CGKeyCode, CGEventFlags) = (direction == .left ? 123 : 124, .maskControl)
        guard let all = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys"), let entry = all[id] as? [String: Any] else { return fallback }
        if let enabled = entry["enabled"] as? Bool, !enabled { return nil }
        guard let value = entry["value"] as? [String: Any], let params = value["parameters"] as? [Int],
              params.count == 3 else { return fallback }
        return (CGKeyCode(params[1]), CGEventFlags(rawValue: UInt64(params[2])))
    }

    static func move(_ direction: Direction) {
        guard let (keyCode, flags) = shortcut(direction) else {
            Log.platform.notice("Space switch: the Mission Control shortcut is disabled")
            return
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            // Arrow keys carry the function / numeric pad flags on real keyboards.
            var all = flags
            if keyCode >= 123 && keyCode <= 126 { all.formUnion([.maskSecondaryFn, .maskNumericPad]) }
            event.flags = all
            event.post(tap: .cghidEventTap)
        }
    }
}
