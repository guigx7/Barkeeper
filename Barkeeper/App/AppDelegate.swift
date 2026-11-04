import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissions = PermissionsModel()
    private var services: AppServices?
    private lazy var permissionsWindow = PermissionsWindowController(model: permissions)
    private lazy var debugItemsWindow = DebugItemsWindowController()
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Barkeeper \(Bundle.main.versionString, privacy: .public) launched")
        // The Dock caches icons per app path; set the tile from the asset catalog so it is always current.
        if let icon = NSImage(named: "AppIcon") { NSApp.applicationIconImage = icon }
        // Icons removed from the choices fall back to the default so the grid always shows the selection.
        if !ControlItems.iconChoices.contains(Preferences.shared.iconSymbol) {
            Preferences.shared.iconSymbol = "custom.bee"
        }
        let services = AppServices()
        AppServices.shared = services
        self.services = services
        services.controlItems.onClick = { [weak services] flags in services?.handleIconClick(flags) }
        services.controlItems.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        if !permissions.allGranted {
            showPermissions()
        }
        if ProcessInfo.processInfo.arguments.contains("--settings") {
            showSettings()
            settingsWindow?.runDebugDropIfRequested()
            settingsWindow?.runDebugEditGroupIfRequested()
        }
        if ProcessInfo.processInfo.arguments.contains("--debug-items") {
            showDebugItems()
        }
        runDebugMoveIfRequested()
        runDebugActivateIfRequested()
        runDebugGroupIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Leave the bar usable if Barkeeper quits: reveal everything.
        services?.hider.apply(.revealedAll)
    }

    /// Reopening the app (Finder/Spotlight) shows the permissions or settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if permissions.requiredGranted { showSettings() } else { showPermissions() }
        return false
    }

    @objc func showSettings() {
        guard let services else { return }
        if settingsWindow == nil { settingsWindow = SettingsWindowController(services: services) }
        settingsWindow?.show()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Permissions…", action: #selector(showPermissions), keyEquivalent: "").target = self
        // Diagnostics only when the menu is opened with ⌥ held.
        if NSEvent.modifierFlags.contains(.option) {
            menu.addItem(withTitle: "Log Menu Bar Items", action: #selector(logMenuBarItems), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Show Item Images (Debug)", action: #selector(showDebugItems), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Barkeeper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc func logMenuBarItems() {
        Task { await DebugProbe.logScan() }
    }

    /// `--debug-move <namespace/name> <shown|hidden|alwaysHidden>`: move one item after launch.
    private func runDebugMoveIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--debug-move"), i + 2 < args.count,
              let section = MenuBarSection(rawValue: args[i + 2]) else { return }
        let identity = args[i + 1]
        Task {
            try? await Task.sleep(for: .seconds(1))
            guard let snapshot = await services?.activeSnapshot(),
                  let item = snapshot.items.first(where: { $0.identity.description == identity }) else {
                Log.menuBar.error("debug-move: item \(identity, privacy: .public) not found")
                return
            }
            Log.menuBar.info("debug-move: \(identity, privacy: .public) from \(snapshot.section(of: item)?.rawValue ?? "?", privacy: .public) to \(section.rawValue, privacy: .public)")
            await services?.move(item, to: section)
            if let after = await services?.activeSnapshot(), let moved = after.items.first(where: { $0.identity.description == identity }) {
                Log.menuBar.info("debug-move: now in \(after.section(of: moved)?.rawValue ?? "?", privacy: .public)")
            }
        }
    }

    /// `--debug-activate <namespace/name>`: open a hidden item's menu like the Barkeeper Bar does.
    private func runDebugActivateIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--debug-activate"), i + 1 < args.count, let services else { return }
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard let snapshot = await services.activeSnapshot(),
                  let item = snapshot.items.first(where: { $0.identity.description == args[i + 1] }) else { return }
            await services.activator.activate(item, in: snapshot)
            let after = await services.activeSnapshot()
            let section = after?.items.first { $0.identity == item.identity }.flatMap { after?.section(of: $0) }
            Log.menuBar.info("debug-activate: back in \(section?.rawValue ?? "?", privacy: .public)")
        }
    }

    /// `--debug-group <namespace/name>...`: create a group with these members and apply it.
    private func runDebugGroupIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--debug-group"), let services else { return }
        let names = args[(i + 1)...].prefix { !$0.hasPrefix("--") }
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard let snapshot = await services.activeSnapshot() else { return }
            var group = services.groups.create()
            await services.placeNewItem(autosaveName: group.autosaveName)
            group.title = "Dev"
            group.symbol = "hammer"
            group.members = snapshot.items.filter { names.contains($0.identity.description) }.map(\.identity)
            services.groups.update(group)
            try? await Task.sleep(for: .milliseconds(400))
            await services.applyGroupChange(old: [], new: group.members)
            let after = await services.activeSnapshot()
            for m in group.members {
                let section = after?.items.first { $0.identity == m }.flatMap { after?.section(of: $0) }
                Log.menuBar.info("debug-group: \(m.description, privacy: .public) in \(section?.rawValue ?? "?", privacy: .public)")
            }
        }
    }

    @objc func showDebugItems() {
        debugItemsWindow.show()
    }

    @objc func showPermissions() {
        permissionsWindow.show()
    }
}

extension Bundle {
    var versionString: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
