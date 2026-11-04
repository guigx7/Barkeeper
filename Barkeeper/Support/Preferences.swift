import Foundation

/// Typed access to Barkeeper's UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    /// What scrolling or swiping in the menu bar does, per direction.
    enum ScrollAction: String, CaseIterable, Identifiable, Sendable {
        case none, toggleHidden, showHidden, hideHidden, desktopLeft, desktopRight
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: "Do Nothing"
            case .toggleHidden: "Show / Hide Hidden Items"
            case .showHidden: "Show Hidden Items"
            case .hideHidden: "Hide Hidden Items"
            case .desktopLeft: "Desktop on the Left"
            case .desktopRight: "Desktop on the Right"
            }
        }
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
        var defaultAction: ScrollAction {
            switch self {
            case .up: .hideHidden
            case .down: .showHidden
            case .left: .desktopLeft
            case .right: .desktopRight
            }
        }
        var key: String { "scrollAction.\(rawValue)" }
    }

    @Published var scrollActions: [ScrollDirection: ScrollAction] {
        didSet { for (d, a) in scrollActions { defaults.set(a.rawValue, forKey: d.key) } }
    }

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
    @Published var scrollEnabled: Bool { didSet { defaults.set(scrollEnabled, forKey: Keys.scrollEnabled) } }
    @Published var revealOnHover: Bool { didSet { defaults.set(revealOnHover, forKey: Keys.revealOnHover) } }
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: Keys.hoverDelay) } }
    @Published var iconSymbol: String { didSet { defaults.set(iconSymbol, forKey: Keys.iconSymbol) } }

    private enum Keys {
        static let showDivider = "showDivider"
        static let shiftClickShowsAll = "shiftClickShowsAll"
        static let optionClickItems = "optionClickItems"
        static let autoRehide = "autoRehide"
        static let useBarkeeperBar = "useBarkeeperBar"
        static let barOnlyOnNotch = "barOnlyOnNotch"
        static let showItemsToRight = "showItemsToRight"
        static let revealOnEmptyClick = "revealOnEmptyClick"
        static let scrollEnabled = "scrollEnabled"
        static let revealOnHover = "revealOnHover"
        static let hoverDelay = "hoverDelay"
        static let iconSymbol = "iconSymbol"
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
            Keys.scrollEnabled: true,
            Keys.revealOnHover: false,
            Keys.hoverDelay: 0.2,
            Keys.iconSymbol: "custom.bee",
        ])
        showDivider = defaults.bool(forKey: Keys.showDivider)
        shiftClickShowsAll = defaults.bool(forKey: Keys.shiftClickShowsAll)
        optionClickItems = OptionClickItems(rawValue: defaults.string(forKey: Keys.optionClickItems) ?? "") ?? .alwaysHidden
        autoRehide = defaults.bool(forKey: Keys.autoRehide)
        useBarkeeperBar = defaults.bool(forKey: Keys.useBarkeeperBar)
        barOnlyOnNotch = defaults.bool(forKey: Keys.barOnlyOnNotch)
        showItemsToRight = defaults.bool(forKey: Keys.showItemsToRight)
        revealOnEmptyClick = defaults.bool(forKey: Keys.revealOnEmptyClick)
        scrollEnabled = defaults.bool(forKey: Keys.scrollEnabled)
        let store = defaults
        scrollActions = Dictionary(uniqueKeysWithValues: ScrollDirection.allCases.map { d in
            (d, store.string(forKey: d.key).flatMap(ScrollAction.init(rawValue:)) ?? d.defaultAction)
        })
        revealOnHover = defaults.bool(forKey: Keys.revealOnHover)
        hoverDelay = defaults.double(forKey: Keys.hoverDelay)
        iconSymbol = defaults.string(forKey: Keys.iconSymbol) ?? "custom.bee"
    }
}
