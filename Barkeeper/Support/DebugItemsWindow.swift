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
        let section: MenuBarSection?
        var id: CGWindowID { item.windowID }
    }

    @Published var entries: [Entry] = []
    @Published var status = "Loading…"

    func move(_ item: MenuBarItem, to section: MenuBarSection) async {
        status = "Moving \(item.displayName) to \(section.title)…"
        await AppServices.shared.move(item, to: section)
        await reload()
    }

    func reload() async {
        let snapshots = await ItemScanner.scan()
        guard let active = snapshots.first(where: \.isActive) ?? snapshots.first else {
            status = "No menu bar found"
            return
        }
        let images = await ScreenCapture.images(windowIDs: active.items.map(\.windowID))
        entries = active.items.map { item in
            let image = images[item.windowID].map { NSImage(cgImage: $0, size: item.frame.size) }
            return Entry(item: item, image: image, section: item.isBarkeeper ? nil : active.section(of: item))
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
                            Text(entry.section?.title ?? "Barkeeper").font(.caption2)
                                .foregroundStyle(entry.item.isOnScreen ? .green : .orange)
                        }
                        .contextMenu {
                            if !entry.item.isBarkeeper && entry.item.isMovable {
                                ForEach(MenuBarSection.allCases, id: \.self) { section in
                                    Button("Move to \(section.title)") {
                                        Task { await model.move(entry.item, to: section) }
                                    }
                                    .disabled(section == entry.section)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 480, minHeight: 300)
    }
}
