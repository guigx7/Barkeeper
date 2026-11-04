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

    /// Display whose top edge a menu bar window sits on. Displays side by side can share the top edge;
    /// then the one containing the window's center wins (right for on-screen windows; hidden items
    /// are off-screen, use `assignMenuBarWindows` for those).
    static func display(forMenuBarWindow frame: CGRect, in displays: [DisplayInfo]) -> DisplayInfo? {
        let sameTop = displays.filter { abs($0.bounds.minY - frame.minY) < 2 && frame.height <= $0.bounds.height }
        return sameTop.first { $0.bounds.minX <= frame.midX && frame.midX < $0.bounds.maxX } ?? sameTop.first
    }

    /// Groups status item windows by the menu bar they belong to. When several displays share a top
    /// edge, their bars overlap in x once hidden items are pushed off-screen; each bar is then a chain
    /// of edge-to-edge windows ending at its display's right edge, followed right → left.
    static func assignMenuBarWindows(_ windows: [WindowInfo], in displays: [DisplayInfo]) -> [CGDirectDisplayID: [WindowInfo]] {
        var result: [CGDirectDisplayID: [WindowInfo]] = [:]
        var shared: [[DisplayInfo]: [WindowInfo]] = [:]
        for w in windows {
            let sameTop = displays.filter { abs($0.bounds.minY - w.frame.minY) < 2 && w.frame.height <= $0.bounds.height }
            if sameTop.count == 1 {
                result[sameTop[0].id, default: []].append(w)
            } else if sameTop.count > 1 {
                shared[sameTop, default: []].append(w)
            }
        }
        for (group, ws) in shared {
            var free = ws
            for display in group.sorted(by: { $0.bounds.maxX > $1.bounds.maxX }) {
                // Rightmost window ending near this display's right edge (items can overhang by a point or two).
                guard let startIndex = free.indices
                    .filter({ free[$0].frame.maxX <= display.bounds.maxX + 8 && free[$0].frame.maxX > display.bounds.minX })
                    .max(by: { free[$0].frame.maxX < free[$1].frame.maxX }) else { continue }
                var chain = [free.remove(at: startIndex)]
                while let next = free.firstIndex(where: { abs($0.frame.maxX - chain[chain.count - 1].frame.minX) < 1.5 }) {
                    chain.append(free.remove(at: next))
                }
                result[display.id, default: []].append(contentsOf: chain)
            }
            if !free.isEmpty {
                Log.menuBar.notice("\(free.count) menu bar window(s) not attributed to a display")
            }
        }
        return result
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
