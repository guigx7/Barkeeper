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
}
