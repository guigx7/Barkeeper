import AppKit

/// Opaque window over a display's menu bar showing a still image of the bar, so the user does not
/// see items shuffle while Barkeeper moves them. Mouse events pass through to the items below.
@MainActor
final class CoverWindow {
    private var window: NSWindow?

    func show(on display: DisplayInfo) {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == display.id }) else { return }
        let height = max(display.menuBarHeight, 24)
        let frame = NSRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
        let cgRect = CGRect(x: display.bounds.minX, y: display.bounds.minY, width: display.bounds.width, height: height)

        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.backgroundColor = .windowBackgroundColor
        if let image = ScreenCapture.screenImage(rect: cgRect) {
            let view = NSImageView(frame: NSRect(origin: .zero, size: frame.size))
            view.image = NSImage(cgImage: image, size: frame.size)
            view.imageScaling = .scaleAxesIndependently
            window.contentView = view
        }
        window.orderFrontRegardless()
        self.window = window
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
