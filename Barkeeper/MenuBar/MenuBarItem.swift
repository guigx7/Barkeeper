import CoreGraphics
import Foundation

/// Stable identity of a menu bar item across launches: owning app + item name within that app.
struct ItemIdentity: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Bundle ID of the owning app (e.g. `com.apple.controlcenter`), or the process name if unknown.
    let namespace: String
    /// Item name inside the app: autosave name, AX identifier, or `#<index>` as last resort.
    let name: String

    var description: String { "\(namespace)/\(name)" }
}

struct MenuBarItem: Identifiable, Hashable, Sendable {
    var id: CGWindowID { windowID }

    let identity: ItemIdentity
    let windowID: CGWindowID
    /// PID of the app that owns the item (not the window owner; on macOS 26 windows belong to Control Center).
    let appPID: pid_t?
    let windowOwnerPID: pid_t
    let displayID: CGDirectDisplayID
    /// CG global coordinates.
    let frame: CGRect
    /// Human readable name for UI and logs.
    let displayName: String
    let isOnScreen: Bool

    var isBarkeeper: Bool { identity.namespace == Bundle.main.bundleIdentifier }

    /// Items macOS does not allow to be ⌘-dragged.
    var isMovable: Bool {
        !["com.apple.menuextra.clock", "com.apple.menuextra.controlcenter", "Clock", "BentoBox-0"].contains(identity.name)
            || identity.namespace != "com.apple.controlcenter"
    }
}

/// Items of one display's menu bar, ordered left → right (hidden items first, at negative x).
struct MenuBarSnapshot: Sendable {
    let display: DisplayInfo
    let isActive: Bool
    let items: [MenuBarItem]
}
