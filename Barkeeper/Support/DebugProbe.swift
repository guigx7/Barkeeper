import AppKit

/// Debug helpers: dump the scanner result to the log.
@MainActor
enum DebugProbe {
    static func logScan() async {
        let snapshots = await ItemScanner.scan()
        for snap in snapshots {
            let d = snap.display
            Log.menuBar.info("Display \(d.id) \(d.name, privacy: .public) bounds=\(NSStringFromRect(d.bounds), privacy: .public) notch=\(d.hasNotch) menuBar=\(d.menuBarHeight) active=\(snap.isActive) items=\(snap.items.count)")
            for item in snap.items {
                Log.menuBar.info("  item \(item.identity.description, privacy: .public) \"\(item.displayName, privacy: .public)\" win=\(item.windowID) pid=\(item.appPID.map(String.init) ?? "-", privacy: .public) frame=\(NSStringFromRect(item.frame), privacy: .public) onScreen=\(item.isOnScreen) movable=\(item.isMovable)")
            }
        }
    }
}
