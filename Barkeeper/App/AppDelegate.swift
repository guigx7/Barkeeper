import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissions = PermissionsModel()
    private var controlItems: ControlItems?
    private lazy var permissionsWindow = PermissionsWindowController(model: permissions)

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Barkeeper \(Bundle.main.versionString, privacy: .public) launched")
        controlItems = ControlItems(appDelegate: self)
        if !permissions.allGranted {
            showPermissions()
        }
    }

    /// Reopening the app (Finder/Spotlight) shows the permissions or settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPermissions()
        return false
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
