import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    let navigation = SettingsNavigation()
    let layout: LayoutModel
    private var changeObserver: NSObjectProtocol?

    init(services: AppServices) {
        layout = LayoutModel(services: services)
        // Tall by default: most pages are long lists of cards.
        let available = NSScreen.main?.visibleFrame.height ?? 900
        let height = min(900, max(560, available - 80))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: height),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.title = "Barkeeper Settings"
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.setFrameAutosaveName("BarkeeperSettingsWindow")
        window.minSize = NSSize(width: 720, height: 520)
        super.init(window: window)
        window.delegate = self
        changeObserver = NotificationCenter.default.addObserver(
            forName: .barkeeperMenuBarChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.window?.isVisible == true, self.navigation.page == .layout else { return }
                Task { await self.layout.refresh() }
            }
        }
        let hosting = NSHostingController(rootView: SettingsView(navigation: navigation, layout: layout, prefs: .shared))
        // Keep the window's own size: by default the hosting controller shrinks it to the content's ideal size.
        hosting.sizingOptions = []
        window.contentViewController = hosting
        if !window.setFrameUsingName("BarkeeperSettingsWindow") {
            window.setContentSize(NSSize(width: 860, height: height))
        }
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
