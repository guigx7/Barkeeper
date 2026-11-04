import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    let navigation = SettingsNavigation()
    let layout: LayoutModel

    init(services: AppServices) {
        layout = LayoutModel(services: services)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.title = "Barkeeper"
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.setFrameAutosaveName("BarkeeperSettings")
        window.minSize = NSSize(width: 720, height: 520)
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: SettingsView(navigation: navigation, layout: layout, prefs: .shared))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show(page: SettingsPage? = nil) {
        if let page { navigation.page = page }
        if window?.isVisible != true { window?.center() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    /// `--debug-drop <namespace/name> <section> <index>`: simulates a drop in the Layout tab.
    func runDebugDropIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--debug-drop"), i + 3 < args.count,
              let section = MenuBarSection(rawValue: args[i + 2]), let index = Int(args[i + 3]) else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard let entry = MenuBarSection.allCases.flatMap({ layout.entries(in: $0) })
                .first(where: { $0.id.description == args[i + 1] }) else {
                Log.menuBar.error("debug-drop: \(args[i + 1], privacy: .public) not in layout")
                return
            }
            Log.menuBar.info("debug-drop: \(args[i + 1], privacy: .public) → \(section.rawValue, privacy: .public)[\(index)]")
            await layout.drop(entry.id, in: section, at: index)
            let names = layout.entries(in: section).map(\.item.displayName).joined(separator: ", ")
            Log.menuBar.info("debug-drop: \(section.rawValue, privacy: .public) now [\(names, privacy: .public)] status=\(String(describing: self.layout.status), privacy: .public)")
        }
    }

    /// `--debug-edit-group`: opens the editor of the first group after the layout loads.
    func runDebugEditGroupIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--debug-edit-group") else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            if let first = AppServices.shared.groups.groups.first { layout.editGroup(first.id) }
        }
    }

    /// Back to a menu bar–only app when settings close.
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
