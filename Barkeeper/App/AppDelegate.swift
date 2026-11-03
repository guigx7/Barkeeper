import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissions = PermissionsModel()
    private var controlItems: ControlItems?
    private var hider: Hider?
    private lazy var permissionsWindow = PermissionsWindowController(model: permissions)
    private lazy var debugItemsWindow = DebugItemsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Barkeeper \(Bundle.main.versionString, privacy: .public) launched")
        let items = ControlItems()
        let hider = Hider(items: items)
        items.onClick = { [weak hider] flags in hider?.handleClick(modifiers: flags) }
        items.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        controlItems = items
        self.hider = hider
        if !permissions.allGranted {
            showPermissions()
        }
        if ProcessInfo.processInfo.arguments.contains("--debug-items") {
            showDebugItems()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Leave the bar usable if Barkeeper quits: reveal everything.
        hider?.apply(.revealedAll)
    }

    /// Reopening the app (Finder/Spotlight) shows the permissions or settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPermissions()
        return false
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
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
