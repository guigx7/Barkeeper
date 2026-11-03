import AppKit

/// Empty Barkeeper status items that add room between other items.
@MainActor
final class SpacerItems {
    nonisolated static let namePrefix = "BarkeeperSpacer-"
    nonisolated static let width: CGFloat = 20
    private static let key = "spacerIDs"

    private var items: [String: NSStatusItem] = [:]

    init() {
        for id in UserDefaults.standard.stringArray(forKey: Self.key) ?? [] {
            items[id] = Self.make(id)
        }
    }

    /// Creates a spacer; macOS places new status items at the left end of the shown area.
    @discardableResult
    func add() -> String {
        let id = UUID().uuidString
        items[id] = Self.make(id)
        persist()
        return id
    }

    func remove(name: String) {
        let id = String(name.dropFirst(Self.namePrefix.count))
        guard let item = items.removeValue(forKey: id) else { return }
        NSStatusBar.system.removeStatusItem(item)
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position \(Self.namePrefix)\(id)")
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(items.keys), forKey: Self.key)
    }

    private static func make(_ id: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: width)
        item.autosaveName = namePrefix + id
        item.button?.title = ""
        return item
    }
}
