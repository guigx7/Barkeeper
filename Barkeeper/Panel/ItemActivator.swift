import AppKit

/// Opens the real menu of a hidden item: moves it temporarily into the visible part of the bar,
/// clicks it, waits for its menu to close and moves it back where it was.
@MainActor
final class ItemActivator {
    private let mover: Mover
    private let hider: Hider
    private let prefs: Preferences
    private(set) var isBusy = false
    private let cover = BarCover()

    init(mover: Mover, hider: Hider, prefs: Preferences = .shared) {
        self.mover = mover
        self.hider = hider
        self.prefs = prefs
    }

    /// Opens the item's real menu without touching the pointer when possible: reveal its section
    /// (dividers shrink), press it through Accessibility, rehide once the menu closes. Falls back to
    /// moving the item with ⌘-drag only when it does not fit on screen even when revealed.
    func activate(_ item: MenuBarItem, in snapshot: MenuBarSnapshot) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let started = ContinuousClock.now
        let previous = hider.state
        let section = snapshot.section(of: item)
        // Freeze the bars so only the clicked item shows up when its section is revealed underneath.
        let displays = Displays.current()
        cover.show(on: displays)
        defer { cover.close() }
        hider.apply(section == .alwaysHidden ? .revealedAll : .revealedHidden)

        if let frame = await waitUntilVisible(item, on: snapshot.display), let pid = item.appPID ?? Optional(item.windowOwnerPID) {
            uncover(item, displays: displays, active: snapshot.display)
            let before = Set(WindowServer.onScreenWindows().map(\.windowID))
            let (index, count) = position(of: item, in: snapshot)
            if await AX.pressMenuBarItem(pid: pid, frame: frame, index: index, count: count) {
                Log.menuBar.info("Opened \(item.identity.description, privacy: .public) in place via AX in \(started.duration(to: .now), privacy: .public)")
                await waitForMenuToClose(of: item, ignoring: before)
                hider.apply(previous)
                // Let the dividers collapse before lifting the still image.
                try? await Task.sleep(for: .milliseconds(120))
                return
            }
            Log.menuBar.notice("AXPress failed for \(item.identity.description, privacy: .public); moving it instead")
        }
        hider.apply(previous)
        cover.close()
        try? await Task.sleep(for: .milliseconds(100))
        await activateByMoving(item, in: snapshot)
    }

    /// Opens the cover over the clicked item and over Barkeeper's own shown items (the capture
    /// cannot see this app's own status items, and they do not move when a section is revealed), on
    /// every display: each display mirrors the bar in the same order.
    private func uncover(_ item: MenuBarItem, displays: [DisplayInfo], active: DisplayInfo) {
        var byDisplay: [CGDirectDisplayID: [WindowInfo]] = [:]
        for w in ItemScanner.itemWindows() {
            guard let d = Displays.display(forMenuBarWindow: w.frame, in: displays) else { continue }
            byDisplay[d.id, default: []].append(w)
        }
        for id in byDisplay.keys { byDisplay[id]?.sort { $0.frame.minX < $1.frame.minX } }
        guard let activeWindows = byDisplay[active.id],
              let itemIndex = activeWindows.firstIndex(where: { $0.windowID == item.windowID }) else { return }
        let dividers = Set([ControlItems.Name.hidden.rawValue, ControlItems.Name.alwaysHidden.rawValue])
        let ownTitles = Set(ControlItems.Name.allCases.map(\.rawValue))
        let ownIndices = activeWindows.indices.filter { i in
            let title = activeWindows[i].title ?? ""
            let own = ownTitles.contains(title) || title.hasPrefix(MenuBarGroup.namePrefix) || title.hasPrefix(SpacerItems.namePrefix)
            return own && !dividers.contains(title)
        }
        let indices = [itemIndex] + ownIndices
        for display in displays {
            guard let windows = byDisplay[display.id], windows.count == activeWindows.count else { continue }
            cover.punchHoles(indices.map { windows[$0].frame }, on: display)
        }
    }

    /// Index of the item among the items of the same app (left → right) and how many there are.
    private func position(of item: MenuBarItem, in snapshot: MenuBarSnapshot) -> (Int, Int) {
        let siblings = snapshot.items.filter { $0.identity.namespace == item.identity.namespace && $0.appPID == item.appPID }
        return (siblings.firstIndex { $0.windowID == item.windowID } ?? 0, siblings.count)
    }

    /// Frame of the item once revealed, or nil if it stays off screen / behind the notch.
    private func waitUntilVisible(_ item: MenuBarItem, on display: DisplayInfo) async -> CGRect? {
        let deadline = ContinuousClock.now + .milliseconds(500)
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(30))
            guard let frame = WindowServer.windows(ids: [item.windowID]).first?.frame else { return nil }
            let onScreen = frame.minX >= display.bounds.minX && frame.maxX <= display.bounds.maxX
            let behindNotch = display.notchSpan.map { frame.maxX > $0.lowerBound && frame.minX < $0.upperBound } ?? false
            if onScreen && !behindNotch { return frame }
        }
        return nil
    }

    /// Fallback: ⌘-drag the item into view, click it, wait, move it back. Moves the pointer.
    private func activateByMoving(_ item: MenuBarItem, in snapshot: MenuBarSnapshot) async {
        guard let main = snapshot.controlItem(.main) else { return }
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
        let pid = item.appPID ?? item.windowOwnerPID
        let (axIndex, axCount) = position(of: item, in: snapshot)
        if await !AX.pressMenuBarItem(pid: pid, frame: frame, index: axIndex, count: axCount) {
            click(at: CGPoint(x: frame.midX, y: frame.midY))
        }
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
