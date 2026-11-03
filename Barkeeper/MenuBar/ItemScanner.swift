import AppKit

/// Enumerates menu bar items per display.
///
/// - macOS 14–15: item windows belong to the owning app's process.
/// - macOS 26+: every item window belongs to Control Center and the window title carries the
///   app's bundle ID or the item's autosave name, depending on the display. The owning app is
///   recovered by matching the window frame against the apps' `AXExtrasMenuBar` items, which
///   macOS reports only for the active menu bar.
enum ItemScanner {
    struct AppRef: Sendable {
        let pid: pid_t
        let bundleID: String?
        let name: String
    }

    private struct AXItem {
        let app: AppRef
        let identifier: String?
        let label: String?
        let frame: CGRect
    }

    @MainActor
    static func scan() async -> [MenuBarSnapshot] {
        let displays = Displays.current()
        let apps = NSWorkspace.shared.runningApplications.map {
            AppRef(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier, name: $0.localizedName ?? "?")
        }
        return await Task.detached(priority: .userInitiated) {
            scanSync(displays: displays, apps: apps)
        }.value
    }

    nonisolated static func scanSync(displays: [DisplayInfo], apps: [AppRef]) -> [MenuBarSnapshot] {
        let started = Date()
        let appsByPID = Dictionary(apps.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        let windows = itemWindows()
        let axItems = apps.flatMap(axItems(of:))

        // Active bar = the display where AX reports item frames.
        let activeID = axItems.lazy.compactMap { Displays.display(forMenuBarWindow: $0.frame.insetBy(dx: 0, dy: -4), in: displays) }.first?.id
            ?? axItems.compactMap { ax in displays.first { $0.bounds.minY <= ax.frame.midY && ax.frame.midY <= $0.bounds.minY + 40 } }.first?.id

        var byDisplay: [CGDirectDisplayID: [WindowInfo]] = [:]
        for w in windows {
            guard let d = Displays.display(forMenuBarWindow: w.frame, in: displays) else { continue }
            byDisplay[d.id, default: []].append(w)
        }

        // Resolve identities on the active display first (AX available there).
        var snapshots: [MenuBarSnapshot] = []
        var activeItems: [MenuBarItem] = []
        if let activeID, let display = displays.first(where: { $0.id == activeID }) {
            let sorted = (byDisplay[activeID] ?? []).sorted { $0.frame.minX < $1.frame.minX }
            activeItems = resolve(sorted, display: display, axItems: axItems, appsByPID: appsByPID)
            snapshots.append(MenuBarSnapshot(display: display, isActive: true, items: activeItems))
        }

        // Other displays mirror the same items in the same order; borrow identities by position + width.
        for display in displays where display.id != activeID {
            let sorted = (byDisplay[display.id] ?? []).sorted { $0.frame.minX < $1.frame.minX }
            let items = mirror(sorted, display: display, reference: activeItems, appsByPID: appsByPID)
            snapshots.append(MenuBarSnapshot(display: display, isActive: false, items: items))
        }

        let ms = Int(Date().timeIntervalSince(started) * 1000)
        Log.menuBar.info("Scan: \(windows.count) windows, \(axItems.count) AX items, \(snapshots.count) displays in \(ms) ms")
        return snapshots
    }

    // MARK: - Sources

    /// Status-layer windows that are menu bar items (excludes macOS drag clones and empty windows).
    nonisolated static func itemWindows() -> [WindowInfo] {
        let all = WindowServer.allWindows()
        var candidates = all.filter {
            $0.layer == WindowServer.statusItemLayer && $0.frame.width > 0 && $0.frame.height > 0
                && $0.ownerName != "Window Server"
        }
        // Prefer the WindowServer's own menu bar list to drop popovers/panels living at status level.
        if let ids = WindowServer.menuBarWindowIDs() {
            let set = Set(ids)
            let filtered = candidates.filter { set.contains($0.windowID) }
            if !filtered.isEmpty { candidates = filtered }
        }
        return candidates
    }

    private nonisolated static func axItems(of app: AppRef) -> [AXItem] {
        AX.extrasMenuBarItems(pid: app.pid).compactMap { el in
            guard let frame = AX.frame(el), frame.width > 0 else { return nil }
            let label = [AX.attribute(el, kAXDescriptionAttribute, as: String.self),
                         AX.attribute(el, kAXTitleAttribute, as: String.self)]
                .compactMap { $0 }.first { !$0.isEmpty }
            return AXItem(app: app, identifier: AX.attribute(el, "AXIdentifier", as: String.self),
                          label: label, frame: frame)
        }
    }

    // MARK: - Resolution

    private nonisolated static func resolve(_ windows: [WindowInfo], display: DisplayInfo, axItems: [AXItem],
                                            appsByPID: [pid_t: AppRef]) -> [MenuBarItem] {
        var indexPerApp: [String: Int] = [:]
        return windows.map { w in
            let ax = axItems
                .filter { abs($0.frame.midX - w.frame.midX) < max(4, w.frame.width / 2) && abs($0.frame.midY - w.frame.midY) < 8 }
                .min { abs($0.frame.midX - w.frame.midX) < abs($1.frame.midX - w.frame.midX) }
            let windowOwner = appsByPID[w.ownerPID]
            let app = ax?.app ?? windowOwner
            let title = w.title?.isEmpty == false ? w.title : nil
            let namespace = ax?.app.bundleID ?? (title.flatMap(looksLikeBundleID) ?? app?.bundleID ?? w.ownerName)
            let index = indexPerApp[namespace, default: 0]
            indexPerApp[namespace] = index + 1
            let name = ax?.identifier
                ?? title.flatMap { looksLikeBundleID($0) == nil ? $0 : nil }
                ?? "#\(index)"
            let displayName = ax?.label.flatMap { $0.count > 1 ? $0 : nil } ?? app?.name ?? namespace
            return MenuBarItem(identity: ItemIdentity(namespace: namespace, name: name), windowID: w.windowID,
                               appPID: ax?.app.pid ?? (windowOwner?.bundleID == "com.apple.controlcenter" ? nil : w.ownerPID),
                               windowOwnerPID: w.ownerPID, displayID: display.id, frame: w.frame,
                               displayName: displayName, isOnScreen: w.frame.maxX > display.bounds.minX)
        }
    }

    private nonisolated static func mirror(_ windows: [WindowInfo], display: DisplayInfo, reference: [MenuBarItem],
                                           appsByPID: [pid_t: AppRef]) -> [MenuBarItem] {
        let aligned = windows.count == reference.count
            && zip(windows, reference).allSatisfy { abs($0.frame.width - $1.frame.width) < 2 }
        if !aligned && !reference.isEmpty {
            Log.menuBar.notice("Display \(display.id) does not mirror the active bar (\(windows.count) vs \(reference.count)); identities by title")
        }
        if aligned {
            return zip(windows, reference).map { w, ref in
                MenuBarItem(identity: ref.identity, windowID: w.windowID, appPID: ref.appPID, windowOwnerPID: w.ownerPID,
                            displayID: display.id, frame: w.frame, displayName: ref.displayName,
                            isOnScreen: w.frame.maxX > display.bounds.minX)
            }
        }
        return resolve(windows, display: display, axItems: [], appsByPID: appsByPID)
    }

    /// Returns the string if it looks like a reverse-DNS bundle identifier.
    nonisolated static func looksLikeBundleID(_ s: String) -> String? {
        let parts = s.split(separator: ".")
        return parts.count >= 3 && !s.contains(" ") ? s : nil
    }
}
