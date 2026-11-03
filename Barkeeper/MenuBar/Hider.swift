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
    private var screenObserver: NSObjectProtocol?

    init(items: ControlItems, prefs: Preferences = .shared) {
        self.items = items
        self.prefs = prefs
        apply(.hidden)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self.map { $0.apply($0.state) } }
        }
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

    func apply(_ newState: State) {
        state = newState
        let showDivider = prefs.showDivider
        switch newState {
        case .hidden:
            items.setDivider(items.hiddenDivider, collapsed: true, visible: showDivider)
            items.setDivider(items.alwaysHiddenDivider, collapsed: true, visible: false)
        case .revealedHidden:
            items.setDivider(items.hiddenDivider, collapsed: false, visible: showDivider)
            items.setDivider(items.alwaysHiddenDivider, collapsed: true, visible: false)
        case .revealedAll:
            items.setDivider(items.hiddenDivider, collapsed: false, visible: showDivider)
            items.setDivider(items.alwaysHiddenDivider, collapsed: false, visible: showDivider)
        }
        Log.menuBar.info("Hider state: \(newState.rawValue, privacy: .public)")
        updateRehideMonitor()
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
