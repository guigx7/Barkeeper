import CoreGraphics

enum MenuBarSection: String, CaseIterable, Codable, Sendable {
    case shown, hidden, alwaysHidden

    var title: String {
        switch self {
        case .shown: "Shown"
        case .hidden: "Hidden"
        case .alwaysHidden: "Always Hidden"
        }
    }
}

extension MenuBarSnapshot {
    func controlItem(_ name: ControlItems.Name) -> MenuBarItem? {
        items.first { $0.isBarkeeper && $0.identity.name == name.rawValue }
    }

    /// Section of every non-Barkeeper item, from its position relative to the dividers.
    func section(of item: MenuBarItem) -> MenuBarSection? {
        guard let hidden = controlItem(.hidden), let alwaysHidden = controlItem(.alwaysHidden) else { return nil }
        if item.frame.midX < alwaysHidden.frame.minX { return .alwaysHidden }
        if item.frame.midX < hidden.frame.minX { return .hidden }
        return .shown
    }

    /// Destination that puts an item at the right end of a section (next to its divider/icon).
    func destination(for section: MenuBarSection) -> Mover.Destination? {
        switch section {
        case .shown: controlItem(.main).map { .rightOf($0.windowID) }
        case .hidden: controlItem(.hidden).map { .leftOf($0.windowID) }
        case .alwaysHidden: controlItem(.alwaysHidden).map { .leftOf($0.windowID) }
        }
    }
}
