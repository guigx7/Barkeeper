import AppKit
import SwiftUI

@MainActor
final class PermissionsWindowController: NSWindowController, NSWindowDelegate {
    let model: PermissionsModel

    init(model: PermissionsModel) {
        self.model = model
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = "Barkeeper Permissions"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: PermissionsView(model: model) { [weak self] in self?.close() })
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        model.refresh()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
