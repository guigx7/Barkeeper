import Foundation

/// Typed access to Barkeeper's UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    /// What a click on empty menu bar space or a scroll/swipe in the menu bar does.
    enum BarAction: String, CaseIterable, Identifiable, Sendable {
        case none, toggleHidden, showHidden, hideHidden, desktopLeft, desktopRight, missionControl, appExpose, showDesktop
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: "Do Nothing"
            case .toggleHidden: "Show / Hide Hidden Items"
            case .showHidden: "Show Hidden Items"
            case .hideHidden: "Hide Hidden Items"
            case .desktopLeft: "Desktop on the Left"
            case .desktopRight: "Desktop on the Right"
            case .missionControl: "Mission Control"
            case .appExpose: "App Exposé"
            case .showDesktop: "Show Desktop"
            }
        }
        /// Picker groups: hidden items, desktops, Mission Control.
        var startsGroup: Bool { self == .toggleHidden || self == .desktopLeft || self == .missionControl }
    }

    /// Mouse buttons that can run an action on empty menu bar space.
    enum ClickButton: String, CaseIterable, Identifiable, Sendable {
        case left, right, middle
        var id: String { rawValue }
        var title: String {
            switch self {
            case .left: "Left Click"
            case .right: "Right Click"
            case .middle: "Middle Click"
            }
        }
        var defaultAction: BarAction { self == .left ? .toggleHidden : .none }
        var key: String { "clickAction.\(rawValue)" }
    }

    enum ScrollDirection: String, CaseIterable, Identifiable, Sendable {
        case up, down, left, right
        var id: String { rawValue }
        var title: String {
            switch self {
            case .up: "Scroll Up"
            case .down: "Scroll Down"
            case .left: "Scroll Left"
            case .right: "Scroll Right"
            }
        }
        var symbol: String { "arrow.\(rawValue)" }
        var defaultAction: BarAction {
            switch self {
            case .up: .hideHidden
            case .down: .showHidden
            case .left: .desktopLeft
            case .right: .desktopRight
            }
        }
        var key: String { "scrollAction.\(rawValue)" }
    }

    @Published var scrollActions: [ScrollDirection: BarAction] {
        didSet { for (d, a) in scrollActions { defaults.set(a.rawValue, forKey: d.key) } }
    }
    @Published var clickActions: [ClickButton: BarAction] {
        didSet { for (b, a) in clickActions { defaults.set(a.rawValue, forKey: b.key) } }
    }

    enum OptionClickItems: String, CaseIterable, Sendable {
        case allHidden, alwaysHidden
    }

    @Published var shiftClickShowsAll: Bool { didSet { defaults.set(shiftClickShowsAll, forKey: Keys.shiftClickShowsAll) } }
    @Published var optionClickItems: OptionClickItems { didSet { defaults.set(optionClickItems.rawValue, forKey: Keys.optionClickItems) } }
    @Published var autoRehide: Bool { didSet { defaults.set(autoRehide, forKey: Keys.autoRehide) } }
    @Published var useBarkeeperBar: Bool { didSet { defaults.set(useBarkeeperBar, forKey: Keys.useBarkeeperBar) } }
    @Published var barOnlyOnNotch: Bool { didSet { defaults.set(barOnlyOnNotch, forKey: Keys.barOnlyOnNotch) } }
    @Published var showItemsToRight: Bool { didSet { defaults.set(showItemsToRight, forKey: Keys.showItemsToRight) } }
    @Published var revealOnHover: Bool { didSet { defaults.set(revealOnHover, forKey: Keys.revealOnHover) } }
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: Keys.hoverDelay) } }
    @Published var iconSymbol: String { didSet { defaults.set(iconSymbol, forKey: Keys.iconSymbol) } }

    private enum Keys {
        static let shiftClickShowsAll = "shiftClickShowsAll"
        static let optionClickItems = "optionClickItems"
        static let autoRehide = "autoRehide"
        static let useBarkeeperBar = "useBarkeeperBar"
        static let barOnlyOnNotch = "barOnlyOnNotch"
        static let showItemsToRight = "showItemsToRight"
        /// Replaced by per-button / per-direction actions; read once to migrate.
        static let legacyRevealOnEmptyClick = "revealOnEmptyClick"
        static let legacyScrollEnabled = "scrollEnabled"
        static let revealOnHover = "revealOnHover"
        static let hoverDelay = "hoverDelay"
        static let iconSymbol = "iconSymbol"
    }

    private init() {
        Self.migrateLegacyToggles(defaults)
        defaults.register(defaults: [
            Keys.shiftClickShowsAll: false,
            Keys.optionClickItems: OptionClickItems.alwaysHidden.rawValue,
            Keys.autoRehide: true,
            Keys.useBarkeeperBar: false,
            Keys.barOnlyOnNotch: false,
            Keys.showItemsToRight: true,
            Keys.revealOnHover: false,
            Keys.hoverDelay: 0.2,
            Keys.iconSymbol: "custom.bee",
        ])
        shiftClickShowsAll = defaults.bool(forKey: Keys.shiftClickShowsAll)
        optionClickItems = OptionClickItems(rawValue: defaults.string(forKey: Keys.optionClickItems) ?? "") ?? .alwaysHidden
        autoRehide = defaults.bool(forKey: Keys.autoRehide)
        useBarkeeperBar = defaults.bool(forKey: Keys.useBarkeeperBar)
        barOnlyOnNotch = defaults.bool(forKey: Keys.barOnlyOnNotch)
        showItemsToRight = defaults.bool(forKey: Keys.showItemsToRight)
        let store = defaults
        scrollActions = Dictionary(uniqueKeysWithValues: ScrollDirection.allCases.map { d in
            (d, store.string(forKey: d.key).flatMap(BarAction.init(rawValue:)) ?? d.defaultAction)
        })
        clickActions = Dictionary(uniqueKeysWithValues: ClickButton.allCases.map { b in
            (b, store.string(forKey: b.key).flatMap(BarAction.init(rawValue:)) ?? b.defaultAction)
        })
        revealOnHover = defaults.bool(forKey: Keys.revealOnHover)
        hoverDelay = defaults.double(forKey: Keys.hoverDelay)
        iconSymbol = defaults.string(forKey: Keys.iconSymbol) ?? "custom.bee"
    }

    /// The old on/off switches for click and scroll become "Do Nothing" actions.
    private static func migrateLegacyToggles(_ defaults: UserDefaults) {
        if defaults.object(forKey: Keys.legacyRevealOnEmptyClick) != nil {
            if !defaults.bool(forKey: Keys.legacyRevealOnEmptyClick) {
                defaults.set(BarAction.none.rawValue, forKey: ClickButton.left.key)
            }
            defaults.removeObject(forKey: Keys.legacyRevealOnEmptyClick)
        }
        if defaults.object(forKey: Keys.legacyScrollEnabled) != nil {
            if !defaults.bool(forKey: Keys.legacyScrollEnabled) {
                for d in ScrollDirection.allCases { defaults.set(BarAction.none.rawValue, forKey: d.key) }
            }
            defaults.removeObject(forKey: Keys.legacyScrollEnabled)
        }
    }
}
