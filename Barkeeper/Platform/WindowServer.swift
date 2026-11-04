import AppKit
import CoreGraphics

/// Raw description of a WindowServer window.
struct WindowInfo: Sendable, Hashable {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let title: String?
    let layer: Int
    /// Global coordinates, origin at the top-left of the main display (CG space).
    let frame: CGRect
    let isOnScreen: Bool

    init?(_ dict: [String: Any]) {
        guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
              let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
              let layer = dict[kCGWindowLayer as String] as? Int,
              let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict)
        else { return nil }
        windowID = id
        ownerPID = pid
        ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""
        title = dict[kCGWindowName as String] as? String
        self.layer = layer
        frame = bounds
        isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? false
    }
}

enum WindowServer {
    /// Window level of status items (kCGStatusWindowLevel).
    static let statusItemLayer = Int(CGWindowLevelForKey(.statusWindow))

    /// All windows known to the WindowServer, including off-screen ones.
    static func allWindows() -> [WindowInfo] {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap(WindowInfo.init)
    }

    /// Windows currently on screen, front to back.
    static func onScreenWindows() -> [WindowInfo] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap(WindowInfo.init)
    }

    /// Descriptions for specific window IDs.
    static func windows(ids: [CGWindowID]) -> [WindowInfo] {
        guard !ids.isEmpty else { return [] }
        let list = CGWindowListCreateDescriptionFromArray(windowIDArray(ids)) as? [[String: Any]] ?? []
        return list.compactMap(WindowInfo.init)
    }

    /// CFArray whose values are raw window IDs (no retain callbacks), as the CGWindow*FromArray APIs expect.
    static func windowIDArray(_ ids: [CGWindowID]) -> CFArray {
        var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        return CFArrayCreate(kCFAllocatorDefault, &pointers, pointers.count, nil)
    }

    /// Window IDs the WindowServer reports as menu bar item windows, in bar order when the
    /// private API is available; `nil` if it is not.
    static func menuBarWindowIDs() -> [CGWindowID]? {
        PrivateCGS.menuBarWindowList()
    }
}
