import AppKit

/// Barkeeper's own status items. Layout, right → left:
/// `[ Always Hidden … ][ AH divider ][ Hidden … ][ H divider ][ Barkeeper icon ][ Shown … ]`
/// A divider hides everything to its left by growing wider than any screen.
@MainActor
final class ControlItems: NSObject {
    enum Name: String, CaseIterable, Sendable {
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
            button.image = Self.iconImage(Preferences.shared.iconSymbol)
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

    /// Symbols offered for the Barkeeper icon (General → Barkeeper menu bar item).
    static let iconChoices: [String] = CustomIcons.names + [
        // Dots, lines, grids
        "ellipsis", "ellipsis.circle", "ellipsis.circle.fill", "ellipsis.rectangle", "circle.grid.2x1.fill",
        "circle.grid.3x3", "square.grid.2x2", "square.grid.3x3", "rectangle.grid.1x2", "line.3.horizontal",
        "line.3.horizontal.decrease", "list.bullet", "menubar.rectangle", "menubar.dock.rectangle",
        // Left-pointing arrows and chevrons
        "chevron.left", "chevron.compact.left", "chevron.left.2", "chevron.left.circle", "chevron.left.circle.fill",
        "chevron.left.square", "chevron.backward", "arrow.left", "arrow.left.circle", "arrow.left.circle.fill",
        "arrow.left.square", "arrowshape.left", "arrowshape.left.fill", "arrowtriangle.left",
        "arrowtriangle.left.fill", "arrowtriangle.left.circle", "arrow.uturn.left", "arrow.turn.down.left",
        "arrow.left.to.line", "arrow.backward", "decrease.indent",
        // Bees, honey, flowers
        "hexagon", "hexagon.fill", "circle.hexagongrid", "circle.hexagongrid.fill", "circle.hexagonpath",
        "camera.macro", "allergens", "ladybug", "ant", "leaf", "drop", "sun.max", "laurel.leading",
        // Things that hold things
        "eye", "eye.slash", "archivebox", "tray", "tray.2", "shippingbox", "cube", "folder",
        "square.stack.3d.up", "slider.horizontal.3", "switch.2", "gearshape", "command", "option",
        // Everything else
        "star", "heart", "bolt", "sparkles", "wand.and.stars", "flame", "moon", "cloud", "snowflake",
        "wineglass", "mug", "cup.and.saucer", "takeoutbag.and.cup.and.straw", "fork.knife", "birthday.cake",
        "party.popper", "crown", "dice", "gamecontroller", "puzzlepiece", "pawprint", "hare", "tortoise",
        "cat", "dog", "bird", "fish", "diamond", "seal", "rosette", "flag",
    ].filter { $0.hasPrefix(CustomIcons.prefix) || NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }

    static func iconImage(_ symbol: String) -> NSImage? {
        let icon = CustomIcons.image(symbol)
            ?? NSImage(systemSymbolName: symbol, accessibilityDescription: "Barkeeper")
            ?? CustomIcons.image("custom.bee")
        icon?.isTemplate = true
        return icon
    }

    func setIcon(_ symbol: String) {
        mainItem.button?.image = Self.iconImage(symbol)
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

    /// WindowServer ID of a control item's window on the active menu bar.
    ///
    /// macOS 14–15: the button's own window. macOS 26: status item windows live in Control Center and
    /// the local window number is a placeholder (≥ 2^32), so the window is found by its title, which
    /// on the active menu bar is the item's autosave name.
    func windowID(_ name: Name) -> CGWindowID? {
        let item = switch name {
        case .main: mainItem
        case .hidden: hiddenDivider
        case .alwaysHidden: alwaysHiddenDivider
        }
        if let number = item.button?.window?.windowNumber, let id = CGWindowID(exactly: number), id > 0,
           !WindowServer.windows(ids: [id]).isEmpty {
            return id
        }
        return WindowServer.allWindows().first {
            $0.layer == WindowServer.statusItemLayer && $0.title == name.rawValue
        }?.windowID
    }

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
