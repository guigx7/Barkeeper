import AppKit

/// Long-lived services shared across the app.
@MainActor
final class AppServices {
    static var shared: AppServices!

    let controlItems: ControlItems
    let hider: Hider
    let mover: Mover
    let spacers = SpacerItems()
    let barPanel = BarPanel()
    let activator: ItemActivator
    let prefs = Preferences.shared
    /// Last full scan of the active bar; lets the Barkeeper Bar open without waiting for AX.
    private(set) var cachedSnapshot: MenuBarSnapshot?

    init() {
        controlItems = ControlItems()
        hider = Hider(items: controlItems)
        mover = Mover(hider: hider)
        activator = ItemActivator(mover: mover)
        hider.repairOrder = { [weak self] in await self?.repairControlItemOrder() }
        // Status item windows get their frames on the next layout pass.
        Task { [hider] in
            try? await Task.sleep(for: .milliseconds(400))
            hider.apply(.hidden)
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
        let items = snapshot.items.filter { item in
            !item.isBarkeeper && snapshot.section(of: item).map(sections.contains) == true
        }
        guard !items.isEmpty else {
            Log.menuBar.info("Barkeeper Bar: nothing to show")
            return
        }
        let images = await ScreenCapture.images(windowIDs: items.map(\.windowID))
        let entries = items.map { item in
            BarPanel.Entry(item: item, image: images[item.windowID].map { NSImage(cgImage: $0, size: item.frame.size) })
        }
        barPanel.onSelect = { [weak self] item in
            guard let self else { return }
            self.barPanel.close(animated: true)
            Task { await self.activator.activate(item, in: snapshot) }
        }
        barPanel.show(entries, anchor: main.frame, anchorWindowID: main.windowID, display: snapshot.display)
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
