import AppKit

/// Barkeeper's own status items. For now only the main icon.
@MainActor
final class ControlItems: NSObject {
    let mainItem: NSStatusItem

    override init() {
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
        menu.addItem(withTitle: "Quit Barkeeper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
}
