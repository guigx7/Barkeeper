import AppKit

extension Notification.Name {
    /// The set of menu bar items or the screens changed; views showing the bar should reload.
    static let barkeeperMenuBarChanged = Notification.Name("BarkeeperMenuBarChanged")
}

/// Watches for changes that affect the menu bar: screens added/removed/resized, apps launching or
/// quitting (their items appear, vanish or are recreated with new windows). Invalidates cached state
/// and moves never-seen items out of Always Hidden, where macOS puts every new item.
@MainActor
final class BarWatcher {
    private unowned let services: AppServices
    private var observers: [NSObjectProtocol] = []
    private var pendingCheck: Task<Void, Never>?
    private var runningObservation: NSKeyValueObservation?
    private static let knownKey = "knownItems"

    init(services: AppServices) {
        self.services = services
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        })
        // Launch notifications skip agent apps (no Dock icon), which is most menu bar apps; the
        // running applications list covers everything.
        runningObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new]) { [weak self] _, change in
            let launched = !(change.newValue ?? []).isEmpty
            let quit = !(change.oldValue ?? []).isEmpty
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if launched { self?.appsChanged(launched: true) }
                    if quit { self?.appsChanged(launched: false) }
                }
            }
        }
    }

    private func screensChanged() {
        Log.menuBar.info("Screens changed: \(NSScreen.screens.count, privacy: .public) screen(s)")
        services.invalidateSnapshot()
        services.barPanel.close(animated: false)
        // Dividers are sized from the widest screen; re-apply once the new layout settles.
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            services.hider.apply(services.hider.state)
            NotificationCenter.default.post(name: .barkeeperMenuBarChanged, object: nil)
        }
    }

    private func appsChanged(launched: Bool) {
        Log.menuBar.info("App \(launched ? "launched" : "quit", privacy: .public)")
        services.invalidateSnapshot()
        NotificationCenter.default.post(name: .barkeeperMenuBarChanged, object: nil)
        if launched { scheduleNewItemCheck() }
    }

    /// Apps create their items some time after launching: look twice.
    func scheduleNewItemCheck() {
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            for delay in [2, 5] {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await self?.placeNewItems()
            }
        }
    }

    // MARK: - New items

    private var known: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.knownKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.knownKey) }
    }

    /// Items never seen before that landed in Always Hidden are moved to the start of Shown (decided
    /// with the user: a new app's icon should be visible, as it would be without Barkeeper). The first
    /// run only records what exists.
    func placeNewItems() async {
        guard !services.mover.isMoving, !services.activator.isBusy,
              let snapshot = await services.activeSnapshot(), let main = snapshot.controlItem(.main) else { return }
        let candidates = snapshot.items.filter { !$0.isBarkeeper && !$0.identity.name.hasPrefix("#") }
        let ids = Set(candidates.map(\.identity.description))
        var known = self.known
        defer { self.known = known.union(ids) }
        guard !known.isEmpty else {
            Log.menuBar.info("New items: recorded \(ids.count, privacy: .public) existing items")
            return
        }
        let members = services.groups.allMembers
        let fresh = candidates.filter { item in
            !known.contains(item.identity.description) && item.isMovable && !members.contains(item.identity)
                && snapshot.section(of: item) == .alwaysHidden
        }
        known.formUnion(ids)
        guard !fresh.isEmpty else { return }
        Log.menuBar.info("New items: moving \(fresh.map(\.identity.description).joined(separator: ", "), privacy: .public) to Shown")
        let moves = fresh.map { Mover.Move(item: $0, destination: .rightOf(main.windowID)) }
        await services.mover.perform(moves, on: snapshot.display)
        services.invalidateSnapshot()
        NotificationCenter.default.post(name: .barkeeperMenuBarChanged, object: nil)
    }
}
