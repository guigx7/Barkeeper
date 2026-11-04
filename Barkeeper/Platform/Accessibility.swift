import AppKit
import ApplicationServices

/// Thin, timeout-guarded helpers over the AX API. Never call on apps that may hang from the main thread
/// without a messaging timeout.
enum AX {
    static let messagingTimeout: Float = 0.25

    static func application(pid: pid_t) -> AXUIElement {
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(el, messagingTimeout)
        return el
    }

    static func attribute<T>(_ el: AXUIElement, _ name: String, as: T.Type = T.self) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success, let value else { return nil }
        return value as? T
    }

    static func children(_ el: AXUIElement) -> [AXUIElement] {
        attribute(el, kAXChildrenAttribute, as: [AXUIElement].self) ?? []
    }

    /// Frame in CG global coordinates (top-left origin).
    static func frame(_ el: AXUIElement) -> CGRect? {
        guard let posValue = attribute(el, kAXPositionAttribute, as: AXValue.self),
              let sizeValue = attribute(el, kAXSizeAttribute, as: AXValue.self) else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(posValue, .cgPoint, &pos), AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    static func extrasMenuBarItems(pid: pid_t) -> [AXUIElement] {
        let app = application(pid: pid)
        guard let bar = attribute(app, "AXExtrasMenuBar", as: AXUIElement.self) else { return [] }
        AXUIElementSetMessagingTimeout(bar, messagingTimeout)
        return children(bar)
    }

    /// Opens a menu bar item through Accessibility (no pointer movement). The item is found among
    /// the app's `AXExtrasMenuBar` children by its on-screen frame. Runs off the main thread because
    /// some apps only return from AXPress once their menu closes.
    ///
    /// `index`/`count`: position of the item among the same app's items, left → right. Used when the
    /// AX frames are stale (macOS 26 does not refresh them when a divider resizes), since the order
    /// is still right.
    static func pressMenuBarItem(pid: pid_t, frame: CGRect, index: Int, count: Int) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            var all: [AXUIElement] = []
            var chosen: (AXUIElement, CGFloat)?
            // The owning app learns its item's new position a little after the WindowServer moves it;
            // pressing before that opens the menu at the old (off-screen) spot.
            let started = Date()
            while Date().timeIntervalSince(started) < 1.0 {
                all = extrasMenuBarItems(pid: pid)
                let candidates = all.compactMap { el -> (AXUIElement, CGFloat)? in
                    guard let f = AX.frame(el), abs(f.midY - frame.midY) < 12 else { return nil }
                    return (el, abs(f.midX - frame.midX))
                }
                chosen = candidates.min(by: { $0.1 < $1.1 }).flatMap { $0.1 < max(8, frame.width / 2) ? $0 : nil }
                if chosen != nil { break }
                usleep(30_000)
            }
            Log.platform.info("AX press: frame \(chosen != nil ? "in sync" : "stale", privacy: .public) after \(Int(Date().timeIntervalSince(started) * 1000)) ms")
            if chosen == nil, all.count == count, index < count {
                let sorted = all.sorted { (AX.frame($0)?.minX ?? 0) < (AX.frame($1)?.minX ?? 0) }
                chosen = (sorted[index], 0)
            }
            guard let (element, _) = chosen else {
                let frames = all.compactMap { AX.frame($0) }.map { NSStringFromRect($0) }.joined(separator: " ")
                Log.platform.notice("AX press: no element near \(NSStringFromRect(frame), privacy: .public) for pid \(pid); AX frames: \(frames, privacy: .public)")
                return false
            }
            for action in [kAXPressAction, "AXShowMenu"] {
                let result = AXUIElementPerformAction(element, action as CFString)
                Log.platform.info("AX press \(action, privacy: .public) on pid \(pid): \(result.rawValue)")
                // A timeout means the app is busy running the menu it just opened.
                if result == .success || result == .cannotComplete { return true }
            }
            return false
        }.value
    }
}

extension AX {
    /// Right edge (CG x) of the app menus (Apple menu, app name, File…) of the app that owns the menu
    /// bar, or nil if unknown.
    static func appMenusMaxX() -> CGFloat? {
        guard let app = NSWorkspace.shared.menuBarOwningApplication else { return nil }
        let el = application(pid: app.processIdentifier)
        guard let bar = attribute(el, kAXMenuBarAttribute, as: AXUIElement.self) else { return nil }
        AXUIElementSetMessagingTimeout(bar, messagingTimeout)
        return children(bar).compactMap(frame).map(\.maxX).max()
    }
}
