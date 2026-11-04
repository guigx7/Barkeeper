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
    private var pendingAppChange: Task<Void, Never>?
    private var lastItemIDs: Set<String> = []
    private static let knownKey = "knownItems"
    private static let knownAppsKey = "knownItemApps"

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
        // Dividers are sized from the widest screen; re-apply once the new layout settles. This is the
        // only screen observer that touches the dividers; it waits for any move session to finish.
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            while services.mover.isMoving || services.activator.isBusy {
                try? await Task.sleep(for: .milliseconds(200))
            }
            services.hider.apply(services.hider.state)
            NotificationCenter.default.post(name: .barkeeperMenuBarChanged, object: nil)
        }
    }

    /// Helpers and agents start and stop all the time: coalesce bursts, and only tell views to reload
    /// when the set of items actually changed.
    private func appsChanged(launched: Bool) {
        services.invalidateSnapshot()
        if launched { scheduleNewItemCheck() }
        pendingAppChange?.cancel()
        pendingAppChange = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.postIfItemsChanged()
        }
    }

    private func postIfItemsChanged() async {
        guard !services.mover.isMoving, let snapshot = await services.activeSnapshot() else { return }
        let ids = Set(snapshot.items.map(\.identity.description))
        guard ids != lastItemIDs else { return }
        lastItemIDs = ids
        Log.menuBar.info("Menu bar items changed: \(ids.count, privacy: .public) items")
        NotificationCenter.default.post(name: .barkeeperMenuBarChanged, object: nil)
    }

    /// Apps create their items some time after launching: look twice.
    func scheduleNewItemCheck() {
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            for delay in [2, 5] {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await self?.placeNewItems()
                await self?.postIfItemsChanged()
            }
        }
    }

    // MARK: - New items

    private var known: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.knownKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.knownKey) }
    }

    /// Apps (identity namespaces) that ever had an item. Item names can change between scans when the
    /// Accessibility match is missing, so "new" also requires an app never seen before.
    private var knownApps: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.knownAppsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.knownAppsKey) }
    }

    /// Items of apps never seen before that landed in Always Hidden are moved to the start of Shown
    /// (decided with the user: a new app's icon should be visible, as it would be without Barkeeper).
    /// The first run only records what exists. Items whose move fails stay unknown and are retried.
    func placeNewItems() async {
        // Without Accessibility, identities fall back to window titles and cannot be trusted.
        guard Permission.accessibility.isGranted, !services.mover.isMoving, !services.activator.isBusy,
              let snapshot = await services.activeSnapshot(), let main = snapshot.controlItem(.main),
              !services.mover.isMoving else { return }
        let candidates = snapshot.items.filter { !$0.isBarkeeper && !$0.identity.name.hasPrefix("#") }
        let known = self.known
        // Older builds recorded only items: derive their apps (`namespace/name`).
        let knownApps = self.knownApps.isEmpty
            ? Set(known.compactMap { $0.split(separator: "/", maxSplits: 1).first.map(String.init) }) : self.knownApps
        guard !known.isEmpty || !knownApps.isEmpty else {
            self.known = Set(candidates.map(\.identity.description))
            self.knownApps = Set(candidates.map(\.identity.namespace))
            Log.menuBar.info("New items: recorded \(candidates.count, privacy: .public) existing items")
            return
        }
        let members = services.groups.allMembers
        let fresh = candidates.filter { item in
            !known.contains(item.identity.description) && !knownApps.contains(item.identity.namespace)
                && item.isMovable && !members.contains(item.identity) && snapshot.section(of: item) == .alwaysHidden
        }
        var failed: Set<String> = []
        if !fresh.isEmpty {
            Log.menuBar.info("New items: moving \(fresh.map(\.identity.description).joined(separator: ", "), privacy: .public) to Shown")
            let moves = fresh.map { Mover.Move(item: $0, destination: .rightOf(main.windowID)) }
            let failures = await services.mover.perform(moves, on: snapshot.display)
            failed = Set(failures.map(\.0.item.identity.description))
            if !failed.isEmpty {
                Log.menuBar.notice("New items: could not move \(failed.sorted().joined(separator: ", "), privacy: .public); will retry")
            }
            services.invalidateSnapshot()
        }
        let settled = candidates.filter { !failed.contains($0.identity.description) }
        self.known = known.union(settled.map(\.identity.description))
        self.knownApps = knownApps.union(settled.map(\.identity.namespace))
    }
}
