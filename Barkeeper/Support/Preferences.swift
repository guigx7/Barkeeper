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

    private enum Keys {
        static let showDivider = "showDivider"
        static let shiftClickShowsAll = "shiftClickShowsAll"
        static let optionClickItems = "optionClickItems"
        static let autoRehide = "autoRehide"
        static let useBarkeeperBar = "useBarkeeperBar"
        static let barOnlyOnNotch = "barOnlyOnNotch"
        static let showItemsToRight = "showItemsToRight"
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
        ])
        showDivider = defaults.bool(forKey: Keys.showDivider)
        shiftClickShowsAll = defaults.bool(forKey: Keys.shiftClickShowsAll)
        optionClickItems = OptionClickItems(rawValue: defaults.string(forKey: Keys.optionClickItems) ?? "") ?? .alwaysHidden
        autoRehide = defaults.bool(forKey: Keys.autoRehide)
        useBarkeeperBar = defaults.bool(forKey: Keys.useBarkeeperBar)
        barOnlyOnNotch = defaults.bool(forKey: Keys.barOnlyOnNotch)
        showItemsToRight = defaults.bool(forKey: Keys.showItemsToRight)
    }
}
