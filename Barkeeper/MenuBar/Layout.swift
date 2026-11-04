import AppKit

/// The user's desired menu bar arrangement: item identities per section, left → right.
struct SavedLayout: Codable, Equatable, Sendable {
    var sections: [MenuBarSection: [ItemIdentity]] = [:]

    subscript(section: MenuBarSection) -> [ItemIdentity] {
        get { sections[section] ?? [] }
        set { sections[section] = newValue }
    }

    func section(of identity: ItemIdentity) -> MenuBarSection? {
        MenuBarSection.allCases.first { self[$0].contains(identity) }
    }

    private static let key = "savedLayout"

    static func load() -> SavedLayout? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedLayout.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

/// One item as shown in Menu Bar Layout.
struct LayoutEntry: Identifiable, Equatable {
    let item: MenuBarItem
    var image: NSImage?
    var id: ItemIdentity { item.identity }
    var isDraggable: Bool { item.isMovable && !(item.isBarkeeper && item.identity.name == ControlItems.Name.main.rawValue) }
    var isSpacer: Bool { item.isBarkeeper && item.identity.name.hasPrefix(SpacerItems.namePrefix) }
    var groupID: UUID? { item.isBarkeeper ? MenuBarGroup.id(fromName: item.identity.name) : nil }
    var width: CGFloat { max(item.frame.width, 16) }
}

/// State behind the Menu Bar Layout tab: reads the real bar, keeps the saved layout, applies changes.
@MainActor
final class LayoutModel: ObservableObject {
    enum Status: Equatable {
        case loading
        case organized
        case unorganized
        case organizing
        case failed(String)
        case noPermission
    }

    @Published private(set) var entries: [MenuBarSection: [LayoutEntry]] = [:]
    @Published private(set) var status: Status = .loading
    @Published var dragging: ItemIdentity?
    @Published var dropTarget: (section: MenuBarSection, index: Int)?
    /// Group being edited in the sheet.
    @Published var editingGroup: MenuBarGroup?
    /// Every other app's item (any section, including group members), for the group editor palette.
    @Published private(set) var allItems: [LayoutEntry] = []

    private var snapshot: MenuBarSnapshot?
    private var saved: SavedLayout?
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
        saved = SavedLayout.load()
    }

    func entries(in section: MenuBarSection) -> [LayoutEntry] { entries[section] ?? [] }

    // MARK: - Reading the bar

    private var pendingRefresh: Task<Void, Never>?

    /// Refresh for an outside change (apps, screens): coalesced, and deferred while Barkeeper is
    /// moving items or the user is dragging, so a mid-move scan never replaces the optimistic layout.
    func refreshWhenIdle() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            while let self, !Task.isCancelled,
                  self.status == .organizing || self.dragging != nil || self.services.mover.isMoving {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard let self, !Task.isCancelled else { return }
            await self.refresh()
        }
    }

    func refresh() async {
        guard Permission.accessibility.isGranted else {
            status = .noPermission
            return
        }
        if entries.isEmpty { status = .loading }
        // Right after launch Barkeeper's own items may not be on the bar yet; wait for the dividers.
        var found: MenuBarSnapshot?
        for _ in 0..<5 {
            found = await services.activeSnapshot()
            if found?.controlItem(.hidden) != nil && found?.controlItem(.alwaysHidden) != nil { break }
            try? await Task.sleep(for: .milliseconds(400))
        }
        guard let snap = found, snap.controlItem(.hidden) != nil else {
            status = .failed("Barkeeper's dividers were not found on the menu bar")
            return
        }
        snapshot = snap
        let images = Permission.screenRecording.isGranted
            ? await ScreenCapture.images(windowIDs: snap.items.map(\.windowID)) : [:]

        var next: [MenuBarSection: [LayoutEntry]] = [:]
        var all: [LayoutEntry] = []
        let members = services.groups.allMembers
        for item in snap.items {
            if item.isBarkeeper, item.identity.name == ControlItems.Name.hidden.rawValue
                || item.identity.name == ControlItems.Name.alwaysHidden.rawValue { continue }
            guard let section = snap.section(of: item) else { continue }
            let image = images[item.windowID].map { NSImage(cgImage: $0, size: item.frame.size) } ?? Self.fallbackImage(for: item)
            let entry = LayoutEntry(item: item, image: image)
            if !item.isBarkeeper && item.isMovable { all.append(entry) }
            // Group members live inside their group, not in the section strips.
            if members.contains(item.identity) { continue }
            next[section, default: []].append(entry)
        }
        entries = next
        allItems = all
        if saved == nil {
            saved = currentLayout()
            saved?.save()
        }
        status = isOrganized() ? .organized : .unorganized
    }

    private static func fallbackImage(for item: MenuBarItem) -> NSImage? {
        guard let pid = item.appPID else { return nil }
        let icon = NSRunningApplication(processIdentifier: pid)?.icon
        icon?.size = NSSize(width: 18, height: 18)
        return icon
    }

    private func currentLayout() -> SavedLayout {
        var layout = SavedLayout()
        for section in MenuBarSection.allCases {
            layout[section] = entries(in: section).filter(\.isDraggable).map(\.id)
        }
        return layout
    }

    /// The real bar matches the saved layout for every item present in both.
    private func isOrganized() -> Bool {
        guard let saved else { return true }
        let current = currentLayout()
        for section in MenuBarSection.allCases {
            let present = Set(current[section])
            let expected = saved[section].filter { present.contains($0) }
            let actual = current[section].filter { saved.section(of: $0) != nil }
            if expected != actual { return false }
        }
        return true
    }

    // MARK: - Editing

    /// Drop handler: moves `identity` to `index` within `section` (index counts draggable + fixed entries).
    func drop(_ identity: ItemIdentity, in section: MenuBarSection, at index: Int) async {
        guard let entry = MenuBarSection.allCases.lazy.compactMap({ s in self.entries(in: s).first { $0.id == identity } }).first,
              entry.isDraggable, let snapshot else { return }

        var list = entries(in: section).filter { $0.id != identity }
        let clamped = min(max(index, 0), list.count)
        // Never place anything right of an immovable system item (Control Center, clock).
        let lastMovable = (list.lastIndex { !$0.isDraggable && !$0.item.isBarkeeper }) ?? list.count
        let insertAt = section == .shown ? min(clamped, lastMovable) : clamped
        list.insert(entry, at: insertAt)

        let destination: Mover.Destination?
        if insertAt + 1 < list.count {
            destination = .leftOf(list[insertAt + 1].item.windowID)
        } else if insertAt > 0 {
            destination = .rightOf(list[insertAt - 1].item.windowID)
        } else {
            destination = snapshot.destination(for: section)
        }
        guard let destination else { return }

        // Optimistic update so the drop feels instant.
        for s in MenuBarSection.allCases { entries[s] = entries(in: s).filter { $0.id != identity } }
        entries[section] = list
        saved = currentLayout()
        saved?.save()

        status = .organizing
        let failures = await services.mover.perform([Mover.Move(item: entry.item, destination: destination)], on: snapshot.display)
        if let failure = failures.first {
            status = .failed("Could not move \(entry.item.displayName): \(failure.1.description)")
        }
        await refresh()
    }

    // MARK: - Groups

    func addGroup() async {
        let group = services.groups.create()
        status = .organizing
        await services.placeNewItem(autosaveName: group.autosaveName)
        await refresh()
        editingGroup = group
    }

    func addSpacer() async {
        let name = services.spacers.add()
        status = .organizing
        await services.placeNewItem(autosaveName: SpacerItems.namePrefix + name)
        await refresh()
    }

    func editGroup(_ id: UUID) {
        editingGroup = services.groups.group(id: id)
    }

    /// Live preview while editing (icon/title/hover); membership is applied on `finishEditing`.
    func previewGroup(_ group: MenuBarGroup) {
        guard var stored = services.groups.group(id: group.id) else { return }
        stored.symbol = group.symbol
        stored.title = group.title
        stored.showOnHover = group.showOnHover
        services.groups.update(stored)
    }

    func finishEditing(_ group: MenuBarGroup) async {
        let old = services.groups.group(id: group.id)?.members ?? []
        services.groups.update(group)
        editingGroup = nil
        status = .organizing
        await services.applyGroupChange(old: old, new: group.members)
        await refresh()
    }

    func deleteGroup(_ group: MenuBarGroup) async {
        let old = services.groups.group(id: group.id)?.members ?? []
        services.groups.delete(group.id)
        editingGroup = nil
        status = .organizing
        await services.applyGroupChange(old: old, new: [])
        await refresh()
    }

    /// Applies the saved layout to the real bar.
    func organize() async {
        guard let saved, let snapshot else { return }
        status = .organizing
        let byID = Dictionary(snapshot.items.map { ($0.identity, $0) }, uniquingKeysWith: { a, _ in a })
        var moves: [Mover.Move] = []

        // Shown: left → right, each right of the previous one, starting at the Barkeeper icon.
        var anchor = snapshot.controlItem(.main)?.windowID
        for id in saved[.shown] {
            guard let item = byID[id], item.isMovable, let a = anchor else { continue }
            moves.append(Mover.Move(item: item, destination: .rightOf(a)))
            anchor = item.windowID
        }
        // Hidden / Always Hidden: right → left, each left of the next one, starting at the divider.
        for (section, divider) in [(MenuBarSection.hidden, ControlItems.Name.hidden), (.alwaysHidden, .alwaysHidden)] {
            var anchor = snapshot.controlItem(divider)?.windowID
            for id in saved[section].reversed() {
                guard let item = byID[id], item.isMovable, let a = anchor else { continue }
                moves.append(Mover.Move(item: item, destination: .leftOf(a)))
                anchor = item.windowID
            }
        }
        let failures = await services.mover.perform(moves, on: snapshot.display)
        if !failures.isEmpty {
            status = .failed("\(failures.count) item(s) could not be moved")
        }
        await refresh()
    }
}
