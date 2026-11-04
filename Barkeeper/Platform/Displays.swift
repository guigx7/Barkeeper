import AppKit
import CoreGraphics

struct DisplayInfo: Sendable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    /// CG global coordinates (top-left origin).
    let bounds: CGRect
    let hasNotch: Bool
    let menuBarHeight: CGFloat
    /// Horizontal span (CG x) hidden by the notch, if any.
    var notchSpan: ClosedRange<CGFloat>? = nil
}

enum Displays {
    @MainActor
    static func current() -> [DisplayInfo] {
        NSScreen.screens.map { screen in
            DisplayInfo(
                id: screen.displayID,
                name: screen.localizedName,
                bounds: CGDisplayBounds(screen.displayID),
                hasNotch: screen.safeAreaInsets.top > 0,
                menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY,
                notchSpan: notchSpan(screen))
        }
    }

    @MainActor
    private static func notchSpan(_ screen: NSScreen) -> ClosedRange<CGFloat>? {
        guard screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea, left.maxX < right.minX else { return nil }
        // NS and CG share x for every display.
        return left.maxX...right.minX
    }

    /// Converts a CG global rect (top-left origin) to AppKit screen coordinates (bottom-left origin).
    @MainActor
    static func appKitRect(_ rect: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Display whose top edge a menu bar window sits on (x is ignored: hidden items are off-screen).
    static func display(forMenuBarWindow frame: CGRect, in displays: [DisplayInfo]) -> DisplayInfo? {
        displays.first { abs($0.bounds.minY - frame.minY) < 2 && frame.height <= $0.bounds.height }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
