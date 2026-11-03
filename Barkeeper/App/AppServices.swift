import AppKit

/// Long-lived services shared across the app.
@MainActor
final class AppServices {
    static var shared: AppServices!

    let controlItems: ControlItems
    let hider: Hider
    let mover: Mover

    init() {
        controlItems = ControlItems()
        hider = Hider(items: controlItems)
        mover = Mover(hider: hider)
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
        return snapshots.first(where: \.isActive) ?? snapshots.first
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
