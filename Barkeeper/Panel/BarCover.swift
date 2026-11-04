import AppKit

/// Still images of the menu bars laid over the real ones. Used to reveal one hidden item without the
/// user seeing the rest of its section: the bar is frozen, the section revealed underneath, then the
/// cover is split around the clicked item so that item (and nothing else) shows through.
///
/// The cover must not overlap the item's window at all: macOS closes a status item's popover when
/// another window covers the item, even a transparent region of one.
@MainActor
final class BarCover {
    private struct Cover {
        let image: CGImage
        let screenFrame: NSRect
        var windows: [NSWindow]
    }

    private var covers: [CGDirectDisplayID: Cover] = [:]

    /// Captures and covers every display's menu bar. Returns false if nothing could be captured
    /// (e.g. no Screen Recording permission); nothing is shown then.
    @discardableResult
    func show(on displays: [DisplayInfo]) -> Bool {
        close()
        for display in displays {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == display.id }) else { continue }
            let height = max(display.menuBarHeight, 24)
            let cgRect = CGRect(x: display.bounds.minX, y: display.bounds.minY, width: display.bounds.width, height: height)
            guard let image = ScreenCapture.screenImage(rect: cgRect) else { continue }
            let frame = NSRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
            let window = Self.window(frame: frame, image: image, crop: NSRect(origin: .zero, size: frame.size), full: frame)
            covers[display.id] = Cover(image: image, screenFrame: frame, windows: [window])
        }
        return !covers.isEmpty
    }

    /// Leaves `rects` (CG global coordinates) uncovered on `display`.
    func punchHoles(_ rects: [CGRect], on display: DisplayInfo) {
        guard var cover = covers[display.id] else { return }
        let full = cover.screenFrame
        // Covered spans = the bar minus the holes.
        var spans: [(CGFloat, CGFloat)] = []
        var cursor: CGFloat = 0
        for rect in rects.sorted(by: { $0.minX < $1.minX }) {
            let holeMin = rect.minX - display.bounds.minX, holeMax = rect.maxX - display.bounds.minX
            if holeMin > cursor { spans.append((cursor, holeMin)) }
            cursor = max(cursor, holeMax)
        }
        spans.append((cursor, full.width))
        var next: [NSWindow] = []
        for (start, end) in spans where end - start > 0.5 {
            let crop = NSRect(x: start, y: 0, width: end - start, height: full.height)
            let frame = NSRect(x: full.minX + start, y: full.minY, width: crop.width, height: full.height)
            next.append(Self.window(frame: frame, image: cover.image, crop: crop, full: full))
        }
        for w in cover.windows { w.orderOut(nil) }
        cover.windows = next
        covers[display.id] = cover
    }

    func close() {
        for cover in covers.values { for w in cover.windows { w.orderOut(nil) } }
        covers.removeAll()
    }

    /// Borderless window over the bar showing the part `crop` (in bar-local points) of the still image.
    private static func window(frame: NSRect, image: CGImage, crop: NSRect, full: NSRect) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = CroppedImageView(frame: NSRect(origin: .zero, size: frame.size))
        view.image = NSImage(cgImage: image, size: full.size)
        view.crop = crop
        window.contentView = view
        window.orderFrontRegardless()
        return window
    }
}

private final class CroppedImageView: NSView {
    var image: NSImage?
    var crop: NSRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds, from: crop, operation: .copy, fraction: 1)
    }
}
