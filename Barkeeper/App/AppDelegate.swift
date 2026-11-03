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
        let services = AppServices()
        AppServices.shared = services
        self.services = services
        services.controlItems.onClick = { [weak services] flags in services?.hider.handleClick(modifiers: flags) }
        services.controlItems.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        if !permissions.allGranted {
            showPermissions()
        }
        if ProcessInfo.processInfo.arguments.contains("--settings") {
            showSettings()
            settingsWindow?.runDebugDropIfRequested()
        }
        if ProcessInfo.processInfo.arguments.contains("--debug-items") {
            showDebugItems()
        }
        runDebugMoveIfRequested()
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
        menu.addItem(withTitle: "Log Menu Bar Items", action: #selector(logMenuBarItems), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Show Item Images (Debug)", action: #selector(showDebugItems), keyEquivalent: "").target = self
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
