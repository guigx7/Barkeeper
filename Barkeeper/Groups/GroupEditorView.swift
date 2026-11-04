import SwiftUI

/// Sheet to edit a menu bar item group: icon and title, hover, members.
struct GroupEditorView: View {
    @ObservedObject var model: LayoutModel
    @State var draft: MenuBarGroup
    let original: [ItemIdentity]
    @State private var showingSymbols = false
    @State private var dragging: ItemIdentity?
    @State private var membersTargeted = false
    @State private var paletteTargeted = false
    @FocusState private var titleFocused: Bool

    private var byID: [ItemIdentity: LayoutEntry] {
        Dictionary(model.allItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Items free to add: not in this group and not in another group.
    private var paletteEntries: [LayoutEntry] {
        model.allItems.filter { entry in
            !draft.members.contains(entry.id)
                && (AppServices.shared.groups.group(containing: entry.id).map { $0.id == draft.id } ?? true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Menu bar item group").font(.system(size: 17, weight: .semibold))

            SettingsCard(title: "Group menu bar item") {
                SettingsRow(label: "Icon and title") {
                    HStack(spacing: 6) {
                        Button { showingSymbols.toggle() } label: {
                            Image(systemName: draft.symbol ?? "square.dashed")
                                .frame(width: 22, height: 18)
                                .foregroundStyle(draft.symbol == nil ? .tertiary : .primary)
                        }
                        .popover(isPresented: $showingSymbols, arrowEdge: .bottom) {
                            SymbolPicker(selection: $draft.symbol) { showingSymbols = false }
                        }
                        .help("Choose icon")
                        Button { draft.symbol = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                            .disabled(draft.symbol == nil)
                            .help("Clear icon")
                        TextField("Title", text: $draft.title)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 130)
                            .focused($titleFocused)
                        Button {
                            titleFocused = true
                            DispatchQueue.main.async { NSApp.orderFrontCharacterPalette(nil) }
                        } label: {
                            Label("Emoji", systemImage: "face.smiling").fixedSize()
                        }
                    }
                }
                SettingsRow(label: "Show on hover over menu bar item", showsDivider: false) {
                    Toggle("", isOn: $draft.showOnHover).labelsHidden().toggleStyle(.switch)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Group items").font(.system(size: 13, weight: .semibold)).padding(.leading, 4)
                ItemWell(entries: draft.members.compactMap { byID[$0] }, placeholder: "Drag items here from the palette below",
                         isTargeted: membersTargeted, dragging: $dragging) { entry in
                    Button("Remove from Group") { draft.members.removeAll { $0 == entry.id } }
                }
                .onDrop(of: [.plainText], isTargeted: $membersTargeted) { _ in
                    guard let id = dragging, !draft.members.contains(id) else { return false }
                    draft.members.append(id)
                    dragging = nil
                    return true
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Menu bar item palette, drag from here to the Group items")
                    .font(.system(size: 13, weight: .semibold)).padding(.leading, 4)
                ItemWell(entries: paletteEntries, placeholder: "No other items",
                         isTargeted: paletteTargeted, dragging: $dragging) { entry in
                    Button("Add to Group") { draft.members.append(entry.id) }
                }
                .onDrop(of: [.plainText], isTargeted: $paletteTargeted) { _ in
                    guard let id = dragging, draft.members.contains(id) else { return false }
                    draft.members.removeAll { $0 == id }
                    dragging = nil
                    return true
                }
            }

            HStack {
                Button("Delete Menu Bar Item Group", role: .destructive) {
                    Task { await model.deleteGroup(draft) }
                }
                Spacer()
                Button("Done") { Task { await model.finishEditing(draft) } }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
        .onChange(of: draft) { _, new in model.previewGroup(new) }
    }
}

/// Dark strip of item images that wraps onto several rows.
private struct ItemWell<Menu: View>: View {
    let entries: [LayoutEntry]
    let placeholder: String
    let isTargeted: Bool
    @Binding var dragging: ItemIdentity?
    @ViewBuilder var menu: (LayoutEntry) -> Menu

    var body: some View {
        ZStack(alignment: .leading) {
            if entries.isEmpty {
                Text(placeholder).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 2)], alignment: .leading, spacing: 2) {
                ForEach(entries) { entry in
                    Group {
                        if let image = entry.image {
                            Image(nsImage: image).interpolation(.high)
                        } else {
                            Text(entry.item.displayName.prefix(2)).font(.system(size: 11, weight: .medium))
                        }
                    }
                    .frame(width: max(entry.width, 30), height: 28)
                    .opacity(dragging == entry.id ? 0.3 : 1)
                    .contentShape(Rectangle())
                    .help(entry.item.displayName)
                    .onDrag {
                        dragging = entry.id
                        return NSItemProvider(object: entry.id.description as NSString)
                    }
                    .contextMenu { menu(entry) }
                }
            }
        }
        .padding(8)
        .frame(minHeight: 44)
        .background(Color.barStrip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(isTargeted ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isTargeted ? 2 : 1))
        .environment(\.colorScheme, .dark)
    }
}

/// Small grid of SF Symbols for the group icon.
private struct SymbolPicker: View {
    @Binding var selection: String?
    let done: () -> Void

    static let symbols = [
        "square.stack.3d.up", "folder", "tray.full", "archivebox", "shippingbox", "star", "heart", "bolt",
        "flame", "leaf", "cloud", "moon", "sun.max", "sparkles", "gearshape", "wrench.and.screwdriver",
        "hammer", "paintbrush", "music.note", "headphones", "gamecontroller", "cup.and.saucer", "wineglass",
        "terminal", "chevron.left.forwardslash.chevron.right", "network", "wifi", "lock", "key", "bell",
        "bookmark", "tag", "flag", "globe", "person.2", "briefcase", "cart", "creditcard", "chart.bar",
        "calendar", "clock", "timer", "eye", "lightbulb", "camera", "photo", "film", "doc.text",
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), spacing: 4) {
            ForEach(Self.symbols, id: \.self) { name in
                Button {
                    selection = name
                    done()
                } label: {
                    Image(systemName: name).frame(width: 30, height: 26)
                        .background(selection == name ? Color.accentColor.opacity(0.25) : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(name)
            }
        }
        .padding(10)
    }
}
