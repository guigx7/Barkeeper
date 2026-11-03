import AppKit

/// Barkeeper's own status items. Layout, right → left:
/// `[ Always Hidden … ][ AH divider ][ Hidden … ][ H divider ][ Barkeeper icon ][ Shown … ]`
/// A divider hides everything to its left by growing wider than any screen.
@MainActor
final class ControlItems: NSObject {
    enum Name: String, CaseIterable {
        case main = "BarkeeperMain"
        case hidden = "BarkeeperHidden"
        case alwaysHidden = "BarkeeperAlwaysHidden"

        /// Seed for `NSStatusItem Preferred Position` (smaller = further right) used on first launch:
        /// icon and Hidden divider at the right end, Always Hidden divider past every item on the left,
        /// so existing items start in Hidden and Always Hidden starts empty.
        var seedPosition: Double {
            switch self {
            case .main: 0
            case .hidden: 1
            case .alwaysHidden: 20_000
            }
        }
    }

    let mainItem: NSStatusItem
    let hiddenDivider: NSStatusItem
    let alwaysHiddenDivider: NSStatusItem

    var onClick: ((NSEvent.ModifierFlags) -> Void)?
    var menuProvider: (() -> NSMenu)?

    override init() {
        Self.seedPositionsIfNeeded()
        // Creation order matters on first launch: each new item is placed to the left.
        mainItem = Self.make(.main)
        hiddenDivider = Self.make(.hidden)
        alwaysHiddenDivider = Self.make(.alwaysHidden)
        super.init()
        if let button = mainItem.button {
            button.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Barkeeper")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(mainClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        for divider in [hiddenDivider, alwaysHiddenDivider] {
            divider.button?.image = NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: "Divider")
            divider.button?.image?.isTemplate = true
            divider.button?.appearsDisabled = true
        }
    }

    private static func make(_ name: Name) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = name.rawValue
        item.behavior = []
        return item
    }

    private static func seedPositionsIfNeeded() {
        let defaults = UserDefaults.standard
        for name in Name.allCases {
            let key = "NSStatusItem Preferred Position \(name.rawValue)"
            if defaults.object(forKey: key) == nil {
                defaults.set(name.seedPosition, forKey: key)
            }
        }
    }

    @objc private func mainClicked(_ sender: NSStatusBarButton) {
        // AXPress (VoiceOver, scripts) arrives without a mouse event: treat as a plain click.
        guard let event = NSApp.currentEvent, event.type == .leftMouseUp || event.type == .rightMouseUp else {
            onClick?([])
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .rightMouseUp || flags.contains(.control) {
            showMenu()
        } else {
            onClick?(flags)
        }
    }

    private func showMenu() {
        guard let menu = menuProvider?(), let button = mainItem.button else { return }
        mainItem.menu = menu
        button.performClick(nil)
        mainItem.menu = nil
    }

    // MARK: - Geometry

    /// Width that pushes everything to the left of a divider off every screen.
    static var collapsedLength: CGFloat {
        let widest = NSScreen.screens.map(\.frame.width).max() ?? 2000
        return max(5000, widest + 500)
    }

    func setDivider(_ divider: NSStatusItem, collapsed: Bool, visible: Bool) {
        if collapsed {
            divider.length = Self.collapsedLength
            divider.button?.image = nil
        } else {
            divider.length = visible ? NSStatusItem.variableLength : 0
            divider.button?.image = visible
                ? NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: "Divider") : nil
            divider.button?.image?.isTemplate = true
        }
    }
}
