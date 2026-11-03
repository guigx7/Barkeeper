import AppKit
import CoreGraphics

/// Synthetic mouse input used to ⌘-drag menu bar items.
enum EventSynth {
    nonisolated(unsafe) private static let source: CGEventSource? = {
        let src = CGEventSource(stateID: .hidSystemState)
        // Ignore the user's mouse while a move is in flight; keyboard still works.
        src?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalKeyboardEvents, .permitSystemDefinedEvents], state: .eventSuppressionStateSuppressionInterval)
        src?.localEventsSuppressionInterval = 0.25
        return src
    }()

    static var cursorLocation: CGPoint { CGEvent(source: nil)?.location ?? .zero }

    static func post(_ type: CGEventType, at point: CGPoint, command: Bool) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        else { return }
        event.flags = command ? .maskCommand : []
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)
    }

    /// ⌘-drag from `start` to `end` in small steps, the way a hand would.
    static func commandDrag(from start: CGPoint, to end: CGPoint, steps: Int = 8) async {
        post(.mouseMoved, at: start, command: true)
        try? await Task.sleep(for: .milliseconds(15))
        post(.leftMouseDown, at: start, command: true)
        try? await Task.sleep(for: .milliseconds(60))
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            post(.leftMouseDragged, at: p, command: true)
            try? await Task.sleep(for: .milliseconds(12))
        }
        try? await Task.sleep(for: .milliseconds(40))
        post(.leftMouseUp, at: end, command: true)
    }

    static func hideCursor() { CGDisplayHideCursor(CGMainDisplayID()) }
    static func showCursor() { CGDisplayShowCursor(CGMainDisplayID()) }
    static func warpCursor(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
