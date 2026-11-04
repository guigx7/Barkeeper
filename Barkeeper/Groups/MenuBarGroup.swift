import AppKit

/// A menu bar item group: one Barkeeper status item that opens a panel with its member items.
struct MenuBarGroup: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var symbol: String? = "square.stack.3d.up"
    var title = ""
    var showOnHover = false
    var members: [ItemIdentity] = []

    nonisolated static let namePrefix = "BarkeeperGroup-"
    var autosaveName: String { Self.namePrefix + id.uuidString }

    static func id(fromName name: String) -> UUID? {
        guard name.hasPrefix(namePrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(namePrefix.count)))
    }
}

/// Owns the groups, their status items and persistence.
@MainActor
final class GroupStore: ObservableObject {
    @Published private(set) var groups: [MenuBarGroup] = []
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var hoverTrackers: [UUID: HoverTracker] = [:]
    private var clickTargets: [UUID: ClickTarget] = [:]
    private static let key = "menuBarGroups"

    /// Called when a group's icon is clicked or hovered (if enabled).
    var onActivate: ((MenuBarGroup, CGWindowID?) -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([MenuBarGroup].self, from: data) {
            groups = saved
        }
        for group in groups { installStatusItem(for: group) }
    }

    var allMembers: Set<ItemIdentity> { Set(groups.flatMap(\.members)) }

    func group(id: UUID) -> MenuBarGroup? { groups.first { $0.id == id } }

    func group(containing identity: ItemIdentity) -> MenuBarGroup? {
        groups.first { $0.members.contains(identity) }
    }

    @discardableResult
    func create() -> MenuBarGroup {
        let group = MenuBarGroup()
        groups.append(group)
        installStatusItem(for: group)
        save()
        return group
    }

    func update(_ group: MenuBarGroup) {
        guard let i = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[i] = group
        configure(statusItems[group.id], for: group)
        save()
    }

    func delete(_ id: UUID) {
        groups.removeAll { $0.id == id }
        if let item = statusItems.removeValue(forKey: id) {
            NSStatusBar.system.removeStatusItem(item)
        }
        hoverTrackers[id] = nil
        clickTargets[id] = nil
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position \(MenuBarGroup.namePrefix)\(id.uuidString)")
        save()
    }

    /// WindowServer ID of a group's status item on the active bar (found by autosave name on macOS 26).
    func windowID(of group: MenuBarGroup) -> CGWindowID? {
        WindowServer.allWindows().first {
            $0.layer == WindowServer.statusItemLayer && $0.title == group.autosaveName
        }?.windowID
    }

    private func save() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private func installStatusItem(for group: MenuBarGroup) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = group.autosaveName
        // Target-action needs an NSObject target; GroupStore is a plain Swift class.
        let target = ClickTarget { [weak self] in
            guard let self, let current = self.group(id: group.id) else { return }
            self.onActivate?(current, self.windowID(of: current))
        }
        clickTargets[group.id] = target
        item.button?.target = target
        item.button?.action = #selector(ClickTarget.fire(_:))
        statusItems[group.id] = item
        configure(item, for: group)
        if let button = item.button {
            hoverTrackers[group.id] = HoverTracker(view: button) { [weak self] in
                guard let self, let current = self.group(id: group.id), current.showOnHover else { return }
                self.onActivate?(current, self.windowID(of: current))
            }
        }
    }

    private func configure(_ item: NSStatusItem?, for group: MenuBarGroup) {
        guard let button = item?.button else { return }
        let image = group.symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: group.title) }
        image?.isTemplate = true
        button.image = image
        button.title = group.title
        button.imagePosition = group.title.isEmpty ? .imageOnly : (image == nil ? .noImage : .imageLeading)
        if image == nil && group.title.isEmpty { button.title = "Group" }
        button.toolTip = group.title.isEmpty ? "Menu bar item group" : group.title
        button.needsLayout = true
        button.needsDisplay = true
    }

}

/// NSObject trampoline for a button action.
@MainActor
final class ClickTarget: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func fire(_ sender: Any?) { action() }
}

/// Calls `onHover` after the pointer rests on a view for a short delay.
@MainActor
final class HoverTracker: NSResponder {
    private let onHover: () -> Void
    private var pending: Task<Void, Never>?
    static let delay: Duration = .milliseconds(200)

    init(view: NSView, onHover: @escaping () -> Void) {
        self.onHover = onHover
        super.init()
        view.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                            owner: self, userInfo: nil))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) {
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled else { return }
            self?.onHover()
        }
    }

    override func mouseExited(with event: NSEvent) {
        pending?.cancel()
    }
}
