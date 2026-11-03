import AppKit
import SwiftUI

/// Debug window: grid with the captured image of every item on the active menu bar.
@MainActor
final class DebugItemsWindowController: NSWindowController {
    private let model = DebugItemsModel()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: true)
        window.title = "Menu Bar Items (Debug)"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: DebugItemsView(model: model))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        Task { await model.reload() }
    }
}

@MainActor
final class DebugItemsModel: ObservableObject {
    struct Entry: Identifiable {
        let item: MenuBarItem
        let image: NSImage?
        var id: CGWindowID { item.windowID }
    }

    @Published var entries: [Entry] = []
    @Published var status = "Loading…"

    func reload() async {
        let snapshots = await ItemScanner.scan()
        guard let active = snapshots.first(where: \.isActive) ?? snapshots.first else {
            status = "No menu bar found"
            return
        }
        let images = await ScreenCapture.images(windowIDs: active.items.map(\.windowID))
        entries = active.items.map { item in
            let image = images[item.windowID].map { NSImage(cgImage: $0, size: item.frame.size) }
            return Entry(item: item, image: image)
        }
        status = "\(active.display.name): \(entries.count) items, \(images.count) images"
    }
}

struct DebugItemsView: View {
    @ObservedObject var model: DebugItemsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.status).foregroundStyle(.secondary)
                Spacer()
                Button("Reload") { Task { await model.reload() } }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(model.entries) { entry in
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.85))
                                if let image = entry.image {
                                    Image(nsImage: image).interpolation(.high)
                                } else {
                                    Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 40)
                            Text(entry.item.displayName).font(.caption).lineLimit(1)
                            Text(entry.item.identity.description).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Text(entry.item.isOnScreen ? "on screen" : "off screen").font(.caption2)
                                .foregroundStyle(entry.item.isOnScreen ? .green : .orange)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 480, minHeight: 300)
    }
}
