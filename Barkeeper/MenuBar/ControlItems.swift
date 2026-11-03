import AppKit

/// Barkeeper's own status items. For now only the main icon.
@MainActor
final class ControlItems: NSObject {
    let mainItem: NSStatusItem
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        mainItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        mainItem.autosaveName = "BarkeeperMain"
        super.init()
        if let button = mainItem.button {
            button.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Barkeeper")
            button.image?.isTemplate = true
        }
        mainItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let perms = menu.addItem(withTitle: "Permissions…", action: #selector(AppDelegate.showPermissions), keyEquivalent: "")
        perms.target = appDelegate
        let scan = menu.addItem(withTitle: "Log Menu Bar Items", action: #selector(AppDelegate.logMenuBarItems), keyEquivalent: "")
        scan.target = appDelegate
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Barkeeper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
}
