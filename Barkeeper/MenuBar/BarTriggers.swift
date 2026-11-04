import AppKit

/// Reveals hidden items from gestures on empty menu bar space: click, scroll/swipe and hover.
/// Listens through a listen-only event tap (needs Accessibility); events are never altered.
@MainActor
final class BarTriggers {
    enum Action { case toggle, reveal, hide }

    private let prefs: Preferences
    /// Called with the action to perform; `isRevealed` tells the triggers whether a hover/scroll
    /// reveal makes sense.
    var perform: ((Action) -> Void)?
    var isRevealed: (() -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var hoverTask: Task<Void, Never>?
    private var scrollAccumulated: CGFloat = 0
    private var scrollLockedUntil = ContinuousClock.now

    init(prefs: Preferences = .shared) {
        self.prefs = prefs
    }

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<BarTriggers>.fromOpaque(refcon).takeUnretainedValue()
            let location = event.location
            let delta = CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
            let inverted = NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? false
            MainActor.assumeIsolated { me.handle(type, at: location, scrollDelta: delta, inverted: inverted) }
            return Unmanaged.passUnretained(event)
        }, userInfo: refcon) else {
            Log.app.error("Bar triggers: could not create event tap (Accessibility missing?)")
            return
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.app.info("Bar triggers: event tap installed")
    }

    private func handle(_ type: CGEventType, at point: CGPoint, scrollDelta: CGFloat, inverted: Bool) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            guard prefs.revealOnEmptyClick, Self.isEmptyMenuBarSpace(point) else { return }
            perform?(.toggle)
        case .scrollWheel:
            handleScroll(at: point, delta: scrollDelta, inverted: inverted)
        case .mouseMoved:
            handleHover(at: point)
        default:
            break
        }
    }

    // MARK: - Scroll

    /// Fingers (or wheel) moving down reveals, up hides: the same as pulling the items down out of
    /// the bar. One action per gesture.
    private func handleScroll(at point: CGPoint, delta: CGFloat, inverted: Bool) {
        guard prefs.revealOnScroll, delta != 0, Self.menuBarDisplay(at: point) != nil else {
            scrollAccumulated = 0
            return
        }
        guard ContinuousClock.now >= scrollLockedUntil else { return }
        // Natural scrolling reports fingers-down as positive delta; classic scrolling as negative.
        scrollAccumulated += inverted ? delta : -delta
        guard abs(scrollAccumulated) >= 6 else { return }
        let down = scrollAccumulated > 0
        scrollAccumulated = 0
        scrollLockedUntil = .now + .milliseconds(600)
        let revealed = isRevealed?() ?? false
        if down, !revealed {
            perform?(.reveal)
        } else if !down, revealed {
            perform?(.hide)
        }
    }

    // MARK: - Hover

    private func handleHover(at point: CGPoint) {
        guard prefs.revealOnHover, Self.menuBarDisplay(at: point) != nil, !(isRevealed?() ?? false) else {
            hoverTask?.cancel()
            hoverTask = nil
            return
        }
        guard hoverTask == nil else { return }
        let delay = prefs.hoverDelay
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard let self, !Task.isCancelled else { return }
            self.hoverTask = nil
            let now = NSEvent.mouseLocation
            let cgPoint = CGPoint(x: now.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - now.y)
            guard Self.isEmptyMenuBarSpace(cgPoint), !(self.isRevealed?() ?? false) else { return }
            self.perform?(.reveal)
        }
    }

    // MARK: - Geometry

    /// The display whose menu bar contains the point (CG global coordinates).
    static func menuBarDisplay(at point: CGPoint) -> DisplayInfo? {
        Displays.current().first { d in
            let height = d.menuBarHeight > 0 ? d.menuBarHeight : 24
            return point.x >= d.bounds.minX && point.x < d.bounds.maxX
                && point.y >= d.bounds.minY && point.y < d.bounds.minY + height
        }
    }

    /// In a menu bar, not over a status item, an app menu or the notch.
    static func isEmptyMenuBarSpace(_ point: CGPoint) -> Bool {
        guard let display = menuBarDisplay(at: point) else { return false }
        if let notch = display.notchSpan, notch.contains(point.x) { return false }
        let overItem = WindowServer.onScreenWindows().contains { w in
            w.layer == WindowServer.statusItemLayer && w.frame.width < 1000 && w.frame.contains(point)
        }
        if overItem { return false }
        // App menus exist only on the active menu bar; elsewhere the left side is empty.
        if let menusMaxX = AX.appMenusMaxX(), point.x <= menusMaxX + 4,
           let menusDisplay = Displays.current().first(where: { $0.bounds.minX <= menusMaxX && menusMaxX < $0.bounds.maxX }),
           menusDisplay.id == display.id {
            return false
        }
        return true
    }
}
