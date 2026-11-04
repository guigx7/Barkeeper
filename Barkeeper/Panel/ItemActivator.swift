import AppKit

/// Opens the real menu of a hidden item: moves it temporarily into the visible part of the bar,
/// clicks it, waits for its menu to close and moves it back where it was.
@MainActor
final class ItemActivator {
    private let mover: Mover
    private let prefs: Preferences
    private(set) var isBusy = false

    init(mover: Mover, prefs: Preferences = .shared) {
        self.mover = mover
        self.prefs = prefs
    }

    func activate(_ item: MenuBarItem, in snapshot: MenuBarSnapshot) async {
        guard !isBusy, let main = snapshot.controlItem(.main) else { return }
        isBusy = true
        defer { isBusy = false }
        let display = snapshot.display

        // Where to put it back: left of its right neighbour, else right of its left neighbour.
        let order = snapshot.items
        guard let index = order.firstIndex(where: { $0.windowID == item.windowID }) else { return }
        let back: Mover.Destination = index + 1 < order.count
            ? .leftOf(order[index + 1].windowID) : .rightOf(order[index - 1].windowID)

        // Where to show it: left of the Barkeeper icon, or right of the shown items if that spot is
        // behind the notch / off screen.
        var destination = Mover.Destination.leftOf(main.windowID)
        let wouldStart = main.frame.minX - item.frame.width
        let blocked = wouldStart < display.bounds.minX
            || (display.notchSpan.map { wouldStart < $0.upperBound && main.frame.minX > $0.lowerBound } ?? false)
        if blocked, prefs.showItemsToRight,
           let fixed = order.first(where: { !$0.isMovable && $0.frame.minX > main.frame.maxX }) {
            destination = .leftOf(fixed.windowID)
        }

        let started = ContinuousClock.now
        let failures = await mover.perform([Mover.Move(item: item, destination: destination)], on: display)
        guard failures.isEmpty, let frame = WindowServer.windows(ids: [item.windowID]).first?.frame else {
            Log.menuBar.error("Activate \(item.identity.description, privacy: .public): could not bring item into view")
            return
        }

        let before = Set(WindowServer.onScreenWindows().map(\.windowID))
        click(at: CGPoint(x: frame.midX, y: frame.midY))
        Log.menuBar.info("Activated \(item.identity.description, privacy: .public) in \(started.duration(to: .now), privacy: .public)")

        await waitForMenuToClose(of: item, ignoring: before)

        let refreshed = await mover.perform([Mover.Move(item: item, destination: back)], on: display)
        if !refreshed.isEmpty {
            Log.menuBar.error("Activate \(item.identity.description, privacy: .public): could not move item back")
        }
    }

    private func click(at point: CGPoint) {
        let saved = EventSynth.cursorLocation
        EventSynth.post(.mouseMoved, at: point, command: false)
        EventSynth.post(.leftMouseDown, at: point, command: false)
        EventSynth.post(.leftMouseUp, at: point, command: false)
        EventSynth.warpCursor(to: saved)
    }

    /// Waits for the menu/popover the click opened (a new non-normal window of the item's app or of
    /// the menu bar host) to appear and then disappear. Items without a menu return after a short wait.
    private func waitForMenuToClose(of item: MenuBarItem, ignoring before: Set<CGWindowID>) async {
        let owners = Set([item.appPID, item.windowOwnerPID].compactMap { $0 })
        func menuWindows() -> Set<CGWindowID> {
            // Menus live above normal windows; popovers may sit at status level but are taller than the bar.
            Set(WindowServer.onScreenWindows().filter { w in
                guard !before.contains(w.windowID), owners.contains(w.ownerPID), w.windowID != item.windowID else { return false }
                return w.layer == WindowServer.statusItemLayer ? w.frame.height > 40 : w.layer != 0
            }.map(\.windowID))
        }

        var opened: Set<CGWindowID> = []
        let appearDeadline = ContinuousClock.now + .milliseconds(1500)
        while ContinuousClock.now < appearDeadline {
            try? await Task.sleep(for: .milliseconds(80))
            opened = menuWindows()
            if !opened.isEmpty { break }
        }
        guard !opened.isEmpty else {
            Log.menuBar.info("No menu window detected for \(item.identity.description, privacy: .public)")
            return
        }
        // Menus can stay open for a long time; poll gently, give up after 10 minutes.
        let closeDeadline = ContinuousClock.now + .seconds(600)
        while ContinuousClock.now < closeDeadline {
            try? await Task.sleep(for: .milliseconds(150))
            let onScreen = Set(WindowServer.onScreenWindows().map(\.windowID))
            if opened.isDisjoint(with: onScreen) { return }
        }
    }
}
