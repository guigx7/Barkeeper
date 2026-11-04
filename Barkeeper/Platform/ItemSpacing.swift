import Foundation

/// Horizontal spacing between all menu bar items. A global macOS setting (`NSStatusItemSpacing` and
/// `NSStatusItemSelectionPadding`, current host): each app reads it when it starts, so a change
/// shows up as apps relaunch.
enum ItemSpacing: String, CaseIterable, Identifiable, Sendable {
    case standard, small, smaller, smallest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Default Spacing"
        case .small: "Small"
        case .smaller: "Smaller"
        case .smallest: "Smallest"
        }
    }

    /// (spacing, selection padding) in points; nil restores the system default.
    var values: (spacing: Int, padding: Int)? {
        switch self {
        case .standard: nil
        case .small: (12, 10)
        case .smaller: (8, 8)
        case .smallest: (4, 6)
        }
    }

    private static var spacingKey: CFString { "NSStatusItemSpacing" as CFString }
    private static var paddingKey: CFString { "NSStatusItemSelectionPadding" as CFString }

    static var current: ItemSpacing {
        let spacing = CFPreferencesCopyValue(spacingKey, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
                                             kCFPreferencesCurrentHost) as? Int
        guard let spacing else { return .standard }
        return allCases.first { $0.values?.spacing == spacing } ?? .small
    }

    func apply() {
        let v = values
        CFPreferencesSetValue(Self.spacingKey, v.map { $0.spacing as CFNumber }, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue(Self.paddingKey, v.map { $0.padding as CFNumber }, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        Log.app.info("Menu bar item spacing set to \(self.rawValue, privacy: .public)")
    }
}
