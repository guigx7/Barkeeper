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
    static let iconChoices: [String] = [
        "ellipsis", "ellipsis.circle", "ellipsis.circle.fill", "ellipsis.rectangle", "circle.grid.2x1.fill",
        "circle.grid.3x3", "circle.hexagongrid", "square.grid.2x2", "square.grid.3x3", "rectangle.grid.1x2",
        "line.3.horizontal", "line.3.horizontal.decrease", "list.bullet", "chevron.left.2", "chevron.left.circle",
        "chevron.down.circle", "chevron.up.chevron.down", "arrow.left.and.right", "menubar.rectangle",
        "menubar.dock.rectangle", "eye", "eye.slash", "archivebox", "tray", "tray.2", "shippingbox", "cube",
        "folder", "square.stack.3d.up", "slider.horizontal.3", "switch.2", "gearshape", "command", "option",
        "star", "heart", "bolt", "sparkles", "wand.and.stars", "flame", "leaf", "moon", "sun.max", "cloud",
        "snowflake", "drop", "wineglass", "mug", "cup.and.saucer", "takeoutbag.and.cup.and.straw", "fork.knife",
        "birthday.cake", "party.popper", "crown", "dice", "gamecontroller", "puzzlepiece", "pawprint", "hare",
        "tortoise", "ant", "cat", "dog", "bird", "fish", "hexagon", "diamond", "seal", "rosette", "flag",
    ].filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }

    /// The Barkeeper icon, optionally with the "‹" divider drawn on its left. A collapsed divider
    /// is wider than the screen and macOS does not draw status items that cross the screen edge, so
    /// the divider shown while items are hidden is part of the icon.
    static func iconImage(_ symbol: String, withDivider: Bool = false) -> NSImage? {
        guard let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: "Barkeeper")
            ?? NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Barkeeper") else { return nil }
        guard withDivider, let chevron = NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular)) else {
            icon.isTemplate = true
            return icon
        }
        let gap: CGFloat = 8
        let size = NSSize(width: chevron.size.width + gap + icon.size.width, height: max(chevron.size.height, icon.size.height))
        let image = NSImage(size: size, flipped: false) { rect in
            chevron.draw(in: NSRect(x: 0, y: (rect.height - chevron.size.height) / 2,
                                    width: chevron.size.width, height: chevron.size.height),
                         from: .zero, operation: .sourceOver, fraction: 0.55)
            icon.draw(in: NSRect(x: chevron.size.width + gap, y: (rect.height - icon.size.height) / 2,
                                 width: icon.size.width, height: icon.size.height))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Barkeeper"
        return image
    }

    private var iconSymbol = Preferences.shared.iconSymbol
    private var iconShowsDivider = false

    func setIcon(_ symbol: String) {
        iconSymbol = symbol
        mainItem.button?.image = Self.iconImage(symbol, withDivider: iconShowsDivider)
    }

    func setIconDivider(_ shows: Bool) {
        guard shows != iconShowsDivider else { return }
        iconShowsDivider = shows
        mainItem.button?.image = Self.iconImage(iconSymbol, withDivider: shows)
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
