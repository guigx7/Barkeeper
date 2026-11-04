import CoreGraphics
import Foundation

/// Posts one of the system's own shortcuts (System Settings → Keyboard → Keyboard Shortcuts), read
/// from the user's settings so a rebound shortcut still works.
enum SymbolicHotKey {
    /// IDs in `com.apple.symbolichotkeys`.
    enum ID: Int {
        case missionControl = 32
        case appWindows = 33
        case showDesktop = 36
        case spaceLeft = 79
        case spaceRight = 81

        /// macOS's default binding, used when the user's settings don't list one.
        var fallback: (keyCode: CGKeyCode, flags: CGEventFlags) {
            switch self {
            case .missionControl: (126, .maskControl) // ⌃↑
            case .appWindows: (125, .maskControl) // ⌃↓
            case .showDesktop: (103, []) // F11
            case .spaceLeft: (123, .maskControl) // ⌃←
            case .spaceRight: (124, .maskControl) // ⌃→
            }
        }
    }

    private static func shortcut(_ id: ID) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        guard let all = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys"), let entry = all[String(id.rawValue)] as? [String: Any] else { return id.fallback }
        if let enabled = entry["enabled"] as? Bool, !enabled { return nil }
        guard let value = entry["value"] as? [String: Any], let params = value["parameters"] as? [Int],
              params.count == 3, params[1] != 65535 else { return id.fallback }
        return (CGKeyCode(params[1]), CGEventFlags(rawValue: UInt64(params[2])))
    }

    /// Returns false when the shortcut is turned off in System Settings.
    @discardableResult
    static func post(_ id: ID) -> Bool {
        guard let (keyCode, flags) = shortcut(id) else {
            Log.platform.notice("Shortcut \(id.rawValue) is disabled in System Settings")
            return false
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
        return true
    }
}

/// Moves to the desktop (Space) on the left/right with the "Move left/right a space" shortcut.
enum SpaceSwitcher {
    enum Direction { case left, right }

    static func move(_ direction: Direction) {
        SymbolicHotKey.post(direction == .left ? .spaceLeft : .spaceRight)
    }
}

/// Mission Control, App Exposé (windows of the frontmost app) and Show Desktop. Asks the Dock
/// directly, so it works even when their keyboard shortcuts are turned off; falls back to the
/// shortcuts if that entry point is missing.
enum MissionControl {
    enum Mode {
        case all, frontApp, desktop

        var dockNotification: String {
            switch self {
            case .all: "com.apple.expose.awake"
            case .frontApp: "com.apple.expose.front.awake"
            case .desktop: "com.apple.showdesktop.awake"
            }
        }

        var hotKey: SymbolicHotKey.ID {
            switch self {
            case .all: .missionControl
            case .frontApp: .appWindows
            case .desktop: .showDesktop
            }
        }
    }

    private typealias SendNotification = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

    private static let sendNotification: SendNotification? = {
        guard let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY),
              let symbol = dlsym(handle, "CoreDockSendNotification") else { return nil }
        return unsafeBitCast(symbol, to: SendNotification.self)
    }()

    static func show(_ mode: Mode) {
        if let sendNotification {
            sendNotification(mode.dockNotification as CFString, nil)
        } else {
            Log.platform.notice("Dock notification unavailable; using the keyboard shortcut")
            SymbolicHotKey.post(mode.hotKey)
        }
    }
}
