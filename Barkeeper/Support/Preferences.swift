import Foundation

/// Typed access to Barkeeper's UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    enum OptionClickItems: String, CaseIterable, Sendable {
        case allHidden, alwaysHidden
    }

    @Published var showDivider: Bool { didSet { defaults.set(showDivider, forKey: Keys.showDivider) } }
    @Published var shiftClickShowsAll: Bool { didSet { defaults.set(shiftClickShowsAll, forKey: Keys.shiftClickShowsAll) } }
    @Published var optionClickItems: OptionClickItems { didSet { defaults.set(optionClickItems.rawValue, forKey: Keys.optionClickItems) } }
    @Published var autoRehide: Bool { didSet { defaults.set(autoRehide, forKey: Keys.autoRehide) } }
    @Published var useBarkeeperBar: Bool { didSet { defaults.set(useBarkeeperBar, forKey: Keys.useBarkeeperBar) } }
    @Published var barOnlyOnNotch: Bool { didSet { defaults.set(barOnlyOnNotch, forKey: Keys.barOnlyOnNotch) } }
    @Published var showItemsToRight: Bool { didSet { defaults.set(showItemsToRight, forKey: Keys.showItemsToRight) } }
    @Published var revealOnEmptyClick: Bool { didSet { defaults.set(revealOnEmptyClick, forKey: Keys.revealOnEmptyClick) } }
    @Published var revealOnScroll: Bool { didSet { defaults.set(revealOnScroll, forKey: Keys.revealOnScroll) } }
    @Published var revealOnHover: Bool { didSet { defaults.set(revealOnHover, forKey: Keys.revealOnHover) } }
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: Keys.hoverDelay) } }
    @Published var iconSymbol: String { didSet { defaults.set(iconSymbol, forKey: Keys.iconSymbol) } }
    @Published var showAllOnLargeScreen: Bool { didSet { defaults.set(showAllOnLargeScreen, forKey: Keys.showAllOnLargeScreen) } }
    @Published var largeScreenWidth: Double { didSet { defaults.set(largeScreenWidth, forKey: Keys.largeScreenWidth) } }

    private enum Keys {
        static let showDivider = "showDivider"
        static let shiftClickShowsAll = "shiftClickShowsAll"
        static let optionClickItems = "optionClickItems"
        static let autoRehide = "autoRehide"
        static let useBarkeeperBar = "useBarkeeperBar"
        static let barOnlyOnNotch = "barOnlyOnNotch"
        static let showItemsToRight = "showItemsToRight"
        static let revealOnEmptyClick = "revealOnEmptyClick"
        static let revealOnScroll = "revealOnScroll"
        static let revealOnHover = "revealOnHover"
        static let hoverDelay = "hoverDelay"
        static let iconSymbol = "iconSymbol"
        static let showAllOnLargeScreen = "showAllOnLargeScreen"
        static let largeScreenWidth = "largeScreenWidth"
    }

    private init() {
        defaults.register(defaults: [
            Keys.showDivider: false,
            Keys.shiftClickShowsAll: false,
            Keys.optionClickItems: OptionClickItems.alwaysHidden.rawValue,
            Keys.autoRehide: true,
            Keys.useBarkeeperBar: false,
            Keys.barOnlyOnNotch: false,
            Keys.showItemsToRight: true,
            Keys.revealOnEmptyClick: true,
            Keys.revealOnScroll: true,
            Keys.revealOnHover: false,
            Keys.hoverDelay: 0.2,
            Keys.iconSymbol: "ellipsis",
            Keys.showAllOnLargeScreen: false,
            Keys.largeScreenWidth: 3000.0,
        ])
        showDivider = defaults.bool(forKey: Keys.showDivider)
        shiftClickShowsAll = defaults.bool(forKey: Keys.shiftClickShowsAll)
        optionClickItems = OptionClickItems(rawValue: defaults.string(forKey: Keys.optionClickItems) ?? "") ?? .alwaysHidden
        autoRehide = defaults.bool(forKey: Keys.autoRehide)
        useBarkeeperBar = defaults.bool(forKey: Keys.useBarkeeperBar)
        barOnlyOnNotch = defaults.bool(forKey: Keys.barOnlyOnNotch)
        showItemsToRight = defaults.bool(forKey: Keys.showItemsToRight)
        revealOnEmptyClick = defaults.bool(forKey: Keys.revealOnEmptyClick)
        revealOnScroll = defaults.bool(forKey: Keys.revealOnScroll)
        revealOnHover = defaults.bool(forKey: Keys.revealOnHover)
        hoverDelay = defaults.double(forKey: Keys.hoverDelay)
        iconSymbol = defaults.string(forKey: Keys.iconSymbol) ?? "ellipsis"
        showAllOnLargeScreen = defaults.bool(forKey: Keys.showAllOnLargeScreen)
        largeScreenWidth = defaults.double(forKey: Keys.largeScreenWidth)
    }
}
