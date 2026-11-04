import AppKit
import Combine

/// Long-lived services shared across the app.
@MainActor
final class AppServices {
    static var shared: AppServices!

    let controlItems: ControlItems
    let hider: Hider
    let mover: Mover
    let spacers = SpacerItems()
    let barPanel = BarPanel()
    let groups = GroupStore()
    let activator: ItemActivator
    let prefs = Preferences.shared
    let triggers = BarTriggers()
    private var subscriptions: Set<AnyCancellable> = []
    private var watcher: BarWatcher?
    /// Last full scan of the active bar; lets the Barkeeper Bar open without waiting for AX.
    private(set) var cachedSnapshot: MenuBarSnapshot?

    init() {
        controlItems = ControlItems()
        hider = Hider(items: controlItems)
        mover = Mover(hider: hider)
        activator = ItemActivator(mover: mover, hider: hider)
        hider.repairOrder = { [weak self] in await self?.repairControlItemOrder() }
        groups.onActivate = { [weak self] group, windowID in
            Task { await self?.openGroup(group, anchorWindowID: windowID) }
        }
        triggers.isRevealed = { [weak self] in
            guard let self else { return false }
            return self.barPanel.isVisible || self.hider.state != .hidden
        }
        triggers.perform = { [weak self] action in self?.handleTrigger(action) }
        triggers.isOverRevealedUI = { [weak self] point in self?.barPanel.contains(cgPoint: point) ?? false }
        triggers.canHideNow = { [weak self] in
            guard let self else { return true }
            return !self.activator.isBusy && !self.mover.isMoving
        }
        triggers.start()
        prefs.$iconSymbol.dropFirst().sink { [weak self] symbol in self?.controlItems.setIcon(symbol) }
            .store(in: &subscriptions)
        watcher = BarWatcher(services: self)
        // Status item windows get their frames on the next layout pass.
        Task { [hider, weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            hider.apply(.hidden)
            try? await Task.sleep(for: .seconds(1))
            await self?.watcher?.placeNewItems()
        }
    }

    /// Moves the Barkeeper icon right of the Hidden divider and the Always Hidden divider left of it,
    /// touching only what is actually out of order (moving a divider changes which items it hides).
    func repairControlItemOrder() async {
        guard let mainID = controlItems.windowID(.main), let hiddenID = controlItems.windowID(.hidden),
              let ahID = controlItems.windowID(.alwaysHidden) else { return }
        let frames = Dictionary(WindowServer.windows(ids: [mainID, hiddenID, ahID]).map { ($0.windowID, $0.frame) },
                                uniquingKeysWith: { a, _ in a })
        guard let mainFrame = frames[mainID], let hiddenFrame = frames[hiddenID], let ahFrame = frames[ahID],
              let display = Displays.display(forMenuBarWindow: mainFrame, in: Displays.current()) else { return }
        let me = Bundle.main.bundleIdentifier ?? ""
        func item(_ id: CGWindowID, _ name: ControlItems.Name) -> MenuBarItem {
            MenuBarItem(identity: ItemIdentity(namespace: me, name: name.rawValue), windowID: id,
                        appPID: ProcessInfo.processInfo.processIdentifier,
                        windowOwnerPID: 0, displayID: display.id, frame: .zero, displayName: "Barkeeper", isOnScreen: true)
        }
        var moves: [Mover.Move] = []
        if mainFrame.midX < hiddenFrame.midX {
            moves.append(Mover.Move(item: item(mainID, .main), destination: .rightOf(hiddenID)))
        }
        if ahFrame.midX > hiddenFrame.midX {
            moves.append(Mover.Move(item: item(ahID, .alwaysHidden), destination: .leftOf(hiddenID)))
        }
        await mover.perform(moves, on: display)
    }

    func invalidateSnapshot() {
        cachedSnapshot = nil
    }

    /// The display showing the active menu bar: the one holding the Barkeeper icon's window, which
    /// carries its autosave name only there.
    func activeDisplay() -> DisplayInfo? {
        guard let mainID = controlItems.windowID(.main),
              let frame = WindowServer.windows(ids: [mainID]).first?.frame else { return nil }
        return Displays.display(forMenuBarWindow: frame, in: Displays.current())
    }

    /// Fresh snapshot of the active menu bar.
    func activeSnapshot() async -> MenuBarSnapshot? {
        let snapshots = await ItemScanner.scan()
        let snapshot = snapshots.first(where: \.isActive) ?? snapshots.first
        if snapshot != nil { cachedSnapshot = snapshot }
        return snapshot
    }

    /// Cached snapshot with frames re-read from the WindowServer (fast), or a full scan if the cache
    /// is missing or stale (a window vanished).
    func quickSnapshot() async -> MenuBarSnapshot? {
        // The active menu bar moves with the user between screens; each bar has its own item windows,
        // so a cache taken on another screen is stale even when all its windows still exist.
        if let cached = cachedSnapshot, let display = activeDisplay(), display.id != cached.display.id {
            Log.menuBar.info("Active menu bar moved to \(display.name, privacy: .public); rescanning")
            return await activeSnapshot()
        }
        if let cached = cachedSnapshot {
            let infos = Dictionary(WindowServer.windows(ids: cached.items.map(\.windowID)).map { ($0.windowID, $0) },
                                   uniquingKeysWith: { a, _ in a })
            if infos.count == cached.items.count {
                let items = cached.items.map { item -> MenuBarItem in
                    let frame = infos[item.windowID]?.frame ?? item.frame
                    return MenuBarItem(identity: item.identity, windowID: item.windowID, appPID: item.appPID,
                                       windowOwnerPID: item.windowOwnerPID, displayID: item.displayID, frame: frame,
                                       displayName: item.displayName, isOnScreen: frame.maxX > cached.display.bounds.minX)
                }.sorted { $0.frame.minX < $1.frame.minX }
                Task { _ = await self.activeSnapshot() } // refresh the cache in the background
                return MenuBarSnapshot(display: cached.display, isActive: true, items: items)
            }
        }
        return await activeSnapshot()
    }

    // MARK: - Triggers

    /// Click / scroll / hover on empty menu bar space.
    private func handleTrigger(_ action: BarTriggers.Action) {
        let revealed = barPanel.isVisible || hider.state != .hidden
        switch action {
        case .toggle:
            // The panel closes itself on outside clicks; a click on empty bar space while it is
            // open only closes it.
            if barPanel.isVisible {
                barPanel.close(animated: true)
            } else if revealed {
                hider.apply(.hidden)
            } else {
                handleIconClick([])
            }
        case .reveal:
            if !revealed { handleIconClick([]) }
        case .hide:
            if barPanel.isVisible { barPanel.close(animated: true) }
            if hider.state != .hidden { hider.apply(.hidden) }
        case .scroll(let scrollAction):
            switch scrollAction {
            case .none: break
            case .toggleHidden: handleTrigger(revealed ? .hide : .reveal)
            case .showHidden: handleTrigger(.reveal)
            case .hideHidden: handleTrigger(.hide)
            case .desktopLeft: SpaceSwitcher.move(.left)
            case .desktopRight: SpaceSwitcher.move(.right)
            }
        }
    }

    // MARK: - Barkeeper icon

    /// Click on the Barkeeper icon: reveal on the bar, or open the Barkeeper Bar when enabled.
    func handleIconClick(_ flags: NSEvent.ModifierFlags) {
        if barPanel.isVisible {
            barPanel.close(animated: true)
            return
        }
        guard prefs.useBarkeeperBar else {
            hider.handleClick(modifiers: flags)
            return
        }
        if flags.contains(.shift), prefs.shiftClickShowsAll {
            hider.handleClick(modifiers: flags) // "show all" expands the real bar
            return
        }
        let sections: [MenuBarSection] = flags.contains(.option)
            ? (prefs.optionClickItems == .allHidden ? [.hidden, .alwaysHidden] : [.alwaysHidden])
            : [.hidden]
        Task { await openBar(sections) }
    }

    private func openBar(_ sections: [MenuBarSection]) async {
        guard let snapshot = await quickSnapshot(), let main = snapshot.controlItem(.main) else { return }
        if prefs.barOnlyOnNotch && !snapshot.display.hasNotch {
            hider.handleClick(modifiers: sections.contains(.alwaysHidden) ? .option : [])
            return
        }
        let members = groups.allMembers
        let items = snapshot.items.filter { item in
            !item.isBarkeeper && !members.contains(item.identity)
                && snapshot.section(of: item).map(sections.contains) == true
        }
        guard !items.isEmpty else {
            Log.menuBar.info("Barkeeper Bar: nothing to show")
            return
        }
        await presentBar(items, snapshot: snapshot, anchor: main.frame, anchorWindowID: main.windowID)
    }

    // MARK: - Groups

    private func openGroup(_ group: MenuBarGroup, anchorWindowID: CGWindowID?) async {
        if barPanel.isVisible {
            let sameGroup = barPanel.anchorWindowID == anchorWindowID
            barPanel.close(animated: !sameGroup)
            if sameGroup { return }
        }
        guard let snapshot = await quickSnapshot() else { return }
        let byID = Dictionary(snapshot.items.map { ($0.identity, $0) }, uniquingKeysWith: { a, _ in a })
        let items = group.members.compactMap { byID[$0] }
        let anchor = anchorWindowID.flatMap { id in WindowServer.windows(ids: [id]).first?.frame }
            ?? snapshot.controlItem(.main)?.frame ?? .zero
        guard !items.isEmpty else {
            Log.menuBar.info("Group \(group.id, privacy: .public) has no running members")
            return
        }
        await presentBar(items, snapshot: snapshot, anchor: anchor, anchorWindowID: anchorWindowID)
    }

    /// Applies membership changes on the real bar: new members go to Always Hidden, removed members
    /// go back to Hidden.
    func applyGroupChange(old: [ItemIdentity], new: [ItemIdentity]) async {
        let added = Set(new).subtracting(old), removed = Set(old).subtracting(new)
        guard !added.isEmpty || !removed.isEmpty, let snapshot = await activeSnapshot(),
              let hidden = snapshot.controlItem(.hidden), let ah = snapshot.controlItem(.alwaysHidden) else { return }
        var moves: [Mover.Move] = []
        for item in snapshot.items where item.isMovable {
            if added.contains(item.identity), snapshot.section(of: item) != .alwaysHidden {
                moves.append(Mover.Move(item: item, destination: .leftOf(ah.windowID)))
            } else if removed.contains(item.identity) {
                moves.append(Mover.Move(item: item, destination: .leftOf(hidden.windowID)))
            }
        }
        await mover.perform(moves, on: snapshot.display)
    }

    /// New status items appear at the far left (inside Always Hidden). Move one next to the
    /// Barkeeper icon, at the left end of the shown items.
    func placeNewItem(autosaveName: String) async {
        var windowID: CGWindowID?
        for _ in 0..<10 {
            windowID = WindowServer.allWindows().first {
                $0.layer == WindowServer.statusItemLayer && $0.title == autosaveName
            }?.windowID
            if windowID != nil { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard let windowID, let mainID = controlItems.windowID(.main),
              let mainFrame = WindowServer.windows(ids: [mainID]).first?.frame,
              let display = Displays.display(forMenuBarWindow: mainFrame, in: Displays.current()) else { return }
        let item = MenuBarItem(identity: ItemIdentity(namespace: Bundle.main.bundleIdentifier ?? "", name: autosaveName),
                               windowID: windowID, appPID: ProcessInfo.processInfo.processIdentifier, windowOwnerPID: 0,
                               displayID: display.id, frame: .zero, displayName: autosaveName, isOnScreen: false)
        await mover.perform([Mover.Move(item: item, destination: .rightOf(mainID))], on: display)
    }

    // MARK: - Panel

    private func presentBar(_ items: [MenuBarItem], snapshot: MenuBarSnapshot, anchor: CGRect, anchorWindowID: CGWindowID?) async {
        let images = await ScreenCapture.images(windowIDs: items.map(\.windowID))
        let entries = items.map { item in
            BarPanel.Entry(item: item, image: images[item.windowID].map { NSImage(cgImage: $0, size: item.frame.size) })
        }
        barPanel.onSelect = { [weak self] item in
            guard let self else { return }
            self.barPanel.close(animated: true)
            Task { await self.activator.activate(item, in: snapshot) }
        }
        barPanel.show(entries, anchor: anchor, anchorWindowID: anchorWindowID, display: snapshot.display)
    }

    func move(_ item: MenuBarItem, to section: MenuBarSection) async {
        guard let snapshot = await activeSnapshot(),
              let current = snapshot.items.first(where: { $0.identity == item.identity }),
              let destination = snapshot.destination(for: section) else {
            Log.menuBar.error("Cannot move \(item.identity.description, privacy: .public): missing snapshot or control items")
            return
        }
        await mover.perform([Mover.Move(item: current, destination: destination)], on: snapshot.display)
    }
}
