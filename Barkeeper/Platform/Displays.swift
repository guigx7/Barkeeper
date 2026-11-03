import AppKit
import CoreGraphics

struct DisplayInfo: Sendable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    /// CG global coordinates (top-left origin).
    let bounds: CGRect
    let hasNotch: Bool
    let menuBarHeight: CGFloat
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
                menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY)
        }
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
