import AppKit

/// Hides and reveals the Hidden / Always Hidden sections by resizing the divider items.
@MainActor
final class Hider {
    enum State: String {
        /// Hidden and Always Hidden are off screen.
        case hidden
        /// Hidden items are visible; Always Hidden stays off screen.
        case revealedHidden
        /// Hidden and Always Hidden are visible. On the real bar, Always Hidden sits left of Hidden,
        /// so revealing it always reveals Hidden too (the Barkeeper Bar can show AH alone).
        case revealedAll
    }

    private let items: ControlItems
    private let prefs: Preferences
    private(set) var state: State = .hidden
    private var outsideClickMonitor: Any?

    init(items: ControlItems, prefs: Preferences = .shared) {
        self.items = items
        self.prefs = prefs
        applyDividers(.revealedAll)
        // Screen changes are handled by BarWatcher, which re-applies the state once moves are done.
    }

    /// Plain click toggles Hidden; ⌥-click reveals per preference; ⇧-click reveals everything if enabled.
    func handleClick(modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.shift), prefs.shiftClickShowsAll {
            toggle(.revealedAll)
        } else if modifiers.contains(.option) {
            toggle(.revealedAll)
        } else {
            toggle(.revealedHidden)
        }
    }

    func toggle(_ target: State) {
        apply(state == .hidden ? target : .hidden)
    }

    /// Set by `AppServices`: puts control items back in order (icon right of the Hidden divider,
    /// Always Hidden divider left of it). Returns when done.
    var repairOrder: (() async -> Void)?
    private var isRepairing = false

    func apply(_ newState: State) {
        // Never collapse a divider while the Barkeeper icon sits to its left: the icon would vanish.
        if newState != .revealedAll, !isRepairing, let problem = orderProblem() {
            Log.menuBar.notice("Control items out of order (\(problem, privacy: .public)); repairing before hiding")
            isRepairing = true
            applyDividers(.revealedAll)
            Task {
                await repairOrder?()
                isRepairing = false
                if let still = orderProblem() {
                    Log.menuBar.error("Control items still out of order (\(still, privacy: .public)); keeping everything revealed")
                    applyDividers(.revealedAll)
                } else {
                    applyDividers(newState)
                }
            }
            return
        }
        applyDividers(newState)
    }

    private func applyDividers(_ newState: State) {
        state = newState
        // While revealed, dividers are always drawn so the section boundaries can be seen and
        // items can be ⌘-dragged across them. While hidden they are collapsed (invisible).
        switch newState {
        case .hidden:
            items.setDivider(items.hiddenDivider, collapsed: true, visible: false)
            items.setDivider(items.alwaysHiddenDivider, collapsed: true, visible: false)
        case .revealedHidden:
            items.setDivider(items.hiddenDivider, collapsed: false, visible: true)
            items.setDivider(items.alwaysHiddenDivider, collapsed: true, visible: false)
        case .revealedAll:
            items.setDivider(items.hiddenDivider, collapsed: false, visible: true)
            items.setDivider(items.alwaysHiddenDivider, collapsed: false, visible: true)
        }
        Log.menuBar.info("Hider state: \(newState.rawValue, privacy: .public)")
        updateRehideMonitor()
    }

    /// Describes what is out of order, or nil when icon > H divider > AH divider (left → right reversed).
    func orderProblem() -> String? {
        guard let mainID = items.windowID(.main), let hiddenID = items.windowID(.hidden),
              let ahID = items.windowID(.alwaysHidden) else { return nil }
        let frames = Dictionary(WindowServer.windows(ids: [mainID, hiddenID, ahID]).map { ($0.windowID, $0.frame) },
                                uniquingKeysWith: { a, _ in a })
        guard let main = frames[mainID], let hidden = frames[hiddenID], let ah = frames[ahID] else { return nil }
        if main.midX < hidden.midX { return "icon left of Hidden divider" }
        if ah.midX > hidden.midX { return "Always Hidden divider right of Hidden divider" }
        return nil
    }

    /// Every section on screen with both dividers drawn small, so they can serve as drop targets.
    /// Does not change `state`; callers restore with `apply(state)`.
    func revealForMove() {
        items.setDivider(items.hiddenDivider, collapsed: false, visible: true)
        items.setDivider(items.alwaysHiddenDivider, collapsed: false, visible: true)
    }

    // MARK: - Auto rehide

    /// Rehide when the user clicks anywhere outside the menu bar.
    private func updateRehideMonitor() {
        if state == .hidden || !prefs.autoRehide {
            if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
            outsideClickMonitor = nil
            return
        }
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            let location = NSEvent.mouseLocation
            MainActor.assumeIsolated {
                guard let self, !Self.isInMenuBar(location) else { return }
                self.apply(.hidden)
            }
        }
    }

    private static func isInMenuBar(_ point: NSPoint) -> Bool {
        NSScreen.screens.contains { screen in
            let barHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
            return screen.frame.minX <= point.x && point.x <= screen.frame.maxX
                && point.y >= screen.frame.maxY - barHeight && point.y <= screen.frame.maxY
        }
    }
}
