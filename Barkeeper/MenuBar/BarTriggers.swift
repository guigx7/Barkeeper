import AppKit

/// Runs actions from gestures in the menu bar: clicks on empty space, scroll/swipe anywhere, and
/// hover over empty space (reveals hidden items).
/// Listens through a listen-only event tap (needs Accessibility); events are never altered.
@MainActor
final class BarTriggers {
    enum Action { case reveal, hide, run(Preferences.BarAction) }

    private let prefs: Preferences
    /// Called with the action to perform; `isRevealed` tells the triggers whether a hover/scroll
    /// reveal makes sense.
    var perform: ((Action) -> Void)?
    var isRevealed: (() -> Bool)?
    /// Extra area that counts as "still hovering" after a hover reveal (the Barkeeper Bar panel).
    var isOverRevealedUI: ((CGPoint) -> Bool)?
    /// False while hiding would get in the way (a menu is open, an item is being opened).
    var canHideNow: (() -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var hoverTask: Task<Void, Never>?
    private var leaveTask: Task<Void, Never>?
    /// Set when hover revealed the items: they hide again once the pointer leaves.
    private var revealedByHoverAt: ContinuousClock.Instant?
    /// Menu-like windows already open when the hover reveal happened (overlays, HUDs): not the user's.
    private var menusAtReveal: Set<CGWindowID> = []
    private var scrollAccumulated = CGVector.zero
    private var scrollLockedUntil = ContinuousClock.now
    /// One action per gesture: set once a trackpad gesture fired, cleared when it ends.
    private var gestureConsumed = false

    init(prefs: Preferences = .shared) {
        self.prefs = prefs
    }

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<BarTriggers>.fromOpaque(refcon).takeUnretainedValue()
            let location = event.location
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            var scroll: Scroll?
            if type == .scrollWheel {
                scroll = Scroll(dx: CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)),
                                dy: CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)),
                                phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
                                momentum: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
                                inverted: NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? false)
            }
            MainActor.assumeIsolated { me.handle(type, at: location, button: button, scroll: scroll) }
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

    struct Scroll {
        let dx: CGFloat, dy: CGFloat
        /// Trackpad gesture phase (0 = none, i.e. a mouse wheel; 1 = began; 4 = ended; 8 = cancelled).
        let phase: Int64
        /// Non-zero while the system replays inertia after the fingers lift.
        let momentum: Int64
        let inverted: Bool
    }

    private func handle(_ type: CGEventType, at point: CGPoint, button: Int64, scroll: Scroll?) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            handleClick(.left, at: point)
        case .rightMouseDown:
            handleClick(.right, at: point)
        case .otherMouseDown:
            // Button 2 is the middle button; 3 and up are back/forward and extras.
            if button == 2 { handleClick(.middle, at: point) }
        case .scrollWheel:
            if let scroll { handleScroll(at: point, scroll) }
        case .mouseMoved:
            handleHover(at: point)
        default:
            break
        }
    }

    // MARK: - Click

    private func handleClick(_ button: Preferences.ClickButton, at point: CGPoint) {
        let action = prefs.clickActions[button] ?? Preferences.BarAction.none
        guard action != .none, Self.isEmptyMenuBarSpace(point) else { return }
        Log.app.info("\(button.title, privacy: .public) on empty menu bar space → \(action.rawValue, privacy: .public)")
        perform?(.run(action))
    }

    // MARK: - Scroll

    /// Scrolling or swiping anywhere in a menu bar runs the action set for that direction.
    /// Directions are physical (fingers / wheel), so they do not flip with natural scrolling.
    /// One action per gesture; inertia is ignored.
    private func handleScroll(at point: CGPoint, _ scroll: Scroll) {
        if scroll.phase == 1 { gestureConsumed = false; scrollAccumulated = .zero }
        guard scroll.momentum == 0, Self.menuBarDisplay(at: point) != nil else {
            if scroll.momentum == 0 { scrollAccumulated = .zero }
            return
        }
        if scroll.phase == 4 || scroll.phase == 8 {
            gestureConsumed = false
            scrollAccumulated = .zero
            return
        }
        guard !gestureConsumed, ContinuousClock.now >= scrollLockedUntil else { return }
        // Natural scrolling reports fingers moving down/right as positive deltas.
        let sign: CGFloat = scroll.inverted ? 1 : -1
        scrollAccumulated.dx += scroll.dx * sign
        scrollAccumulated.dy += scroll.dy * sign
        let threshold: CGFloat = 8
        guard max(abs(scrollAccumulated.dx), abs(scrollAccumulated.dy)) >= threshold else { return }
        let direction: Preferences.ScrollDirection = abs(scrollAccumulated.dy) >= abs(scrollAccumulated.dx)
            ? (scrollAccumulated.dy > 0 ? .down : .up)
            : (scrollAccumulated.dx > 0 ? .right : .left)
        scrollAccumulated = .zero
        if scroll.phase == 0 {
            scrollLockedUntil = .now + .milliseconds(500) // mouse wheel: no gesture phases
        } else {
            gestureConsumed = true
        }
        let action = prefs.scrollActions[direction] ?? Preferences.BarAction.none
        Log.app.info("Scroll \(direction.rawValue, privacy: .public) in menu bar → \(action.rawValue, privacy: .public)")
        if action != .none { perform?(.run(action)) }
    }

    // MARK: - Hover

    private func handleHover(at point: CGPoint) {
        if revealedByHoverAt != nil {
            trackHoverLeave(at: point)
            return
        }
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
            guard Self.isEmptyMenuBarSpace(Self.pointerLocation()), !(self.isRevealed?() ?? false) else { return }
            self.revealedByHoverAt = .now
            self.menusAtReveal = WindowServer.openMenuWindows()
            self.perform?(.reveal)
        }
    }

    /// After a hover reveal: hide once the pointer has left the menu bar (and the Barkeeper Bar) for
    /// a moment, waiting for any menu the user opened to close first.
    private func trackHoverLeave(at point: CGPoint) {
        guard let since = revealedByHoverAt else { return }
        // The panel appears asynchronously; give it a moment before trusting "not revealed".
        if !(isRevealed?() ?? false), ContinuousClock.now - since > .seconds(1) {
            endHoverReveal()
            return
        }
        if isInsideHoverArea(point) {
            leaveTask?.cancel()
            leaveTask = nil
            return
        }
        guard leaveTask == nil else { return }
        leaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            while let self, !Task.isCancelled {
                guard let since = self.revealedByHoverAt else { break }
                // The panel appears asynchronously: within the grace period keep waiting for it.
                if !(self.isRevealed?() ?? false) {
                    if ContinuousClock.now - since > .seconds(1) { break }
                    try? await Task.sleep(for: .milliseconds(150))
                    continue
                }
                if self.isInsideHoverArea(Self.pointerLocation()) { break }
                if self.canHideNow?() ?? true, NSEvent.pressedMouseButtons == 0,
                   !WindowServer.isMenuOpen(ignoring: self.menusAtReveal) {
                    self.perform?(.hide)
                    break
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard let self, !Task.isCancelled else { return }
            self.leaveTask = nil
            if !(self.isRevealed?() ?? false) { self.endHoverReveal() }
        }
    }

    private func endHoverReveal() {
        revealedByHoverAt = nil
        leaveTask?.cancel()
        leaveTask = nil
    }

    private func isInsideHoverArea(_ point: CGPoint) -> Bool {
        Self.menuBarDisplay(at: point) != nil || (isOverRevealedUI?(point) ?? false)
    }

    private static func pointerLocation() -> CGPoint {
        let now = NSEvent.mouseLocation
        return CGPoint(x: now.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - now.y)
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
