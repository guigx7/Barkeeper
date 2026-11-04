import AppKit
import SwiftUI

/// The Barkeeper Bar: a pill-shaped floating panel just below the menu bar that shows item images.
@MainActor
final class BarPanel {
    struct Entry: Identifiable {
        let item: MenuBarItem
        let image: NSImage?
        var id: CGWindowID { item.windowID }
    }

    static let gap: CGFloat = 4
    static let inset: CGFloat = 8

    private var panel: NSPanel?
    private var outsideMonitor: Any?
    private(set) var anchorWindowID: CGWindowID?
    var onSelect: ((MenuBarItem) -> Void)?
    var onClose: (() -> Void)?

    var isVisible: Bool { panel?.isVisible == true }

    /// Whether a point (CG global coordinates) is over the panel, with a small margin.
    func contains(cgPoint point: CGPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let ns = NSPoint(x: point.x, y: primaryHeight - point.y)
        return panel.frame.insetBy(dx: -8, dy: -8).contains(ns)
    }

    /// Shows the panel under `anchor` (CG rect of the item that opened it), right edges aligned.
    func show(_ entries: [Entry], anchor: CGRect, anchorWindowID: CGWindowID?, display: DisplayInfo) {
        close(animated: false)
        self.anchorWindowID = anchorWindowID
        let height = max(display.menuBarHeight, 24)
        let width = entries.reduce(0) { $0 + max($1.item.frame.width, 24) } + Self.inset * 2
        let screen = NSScreen.screens.first { $0.displayID == display.id }
        let barBottom = Displays.appKitRect(CGRect(x: display.bounds.minX, y: display.bounds.minY,
                                                   width: display.bounds.width, height: height)).minY
        var x = Displays.appKitRect(anchor).maxX - width
        if let screen { x = min(max(x, screen.frame.minX + 6), screen.frame.maxX - width - 6) }
        let frame = NSRect(x: x, y: barBottom - Self.gap - height, width: width, height: height)

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let view = BarPanelView(entries: entries, height: height) { [weak self] item in self?.onSelect?(item) }
        panel.contentView = NSHostingView(rootView: view)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
        self.panel = panel

        // Clicking anywhere else closes the panel.
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close(animated: true) }
        }
    }

    func close(animated: Bool) {
        if let m = outsideMonitor { NSEvent.removeMonitor(m) }
        outsideMonitor = nil
        guard let panel else { return }
        self.panel = nil
        anchorWindowID = nil
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: { MainActor.assumeIsolated { panel.orderOut(nil) } })
        } else {
            panel.orderOut(nil)
        }
        onClose?()
    }
}

private struct BarPanelView: View {
    let entries: [BarPanel.Entry]
    let height: CGFloat
    let select: (MenuBarItem) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(entries) { entry in
                BarPanelButton(entry: entry, height: height) { select(entry.item) }
            }
        }
        .padding(.horizontal, BarPanel.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Color.black.opacity(0.35), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        .environment(\.colorScheme, .dark)
    }
}

private struct BarPanelButton: View {
    let entry: BarPanel.Entry
    let height: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let image = entry.image {
                    Image(nsImage: image).interpolation(.high)
                } else {
                    Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
                }
            }
            .frame(width: max(entry.item.frame.width, 24), height: height - 4)
            .background(hovering ? Color.white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(entry.item.displayName)
    }
}
