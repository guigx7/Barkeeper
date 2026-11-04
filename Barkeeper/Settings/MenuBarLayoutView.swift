import SwiftUI
import UniformTypeIdentifiers

struct MenuBarLayoutView: View {
    @ObservedObject var model: LayoutModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Menu Bar Layout",
                       subtitle: "Drag items between sections to rearrange your menu bar.")

            if model.status == .noPermission {
                PermissionNotice()
            } else {
                StatusCard(model: model)
                SettingsCard(title: "Sections") {
                    VStack(spacing: 14) {
                        ForEach(MenuBarSection.allCases, id: \.self) { section in
                            SectionStrip(model: model, section: section)
                        }
                    }
                    .padding(.horizontal, Metrics.inset)
                    .padding(.top, 6)
                    .padding(.bottom, 14)
                }
                PaletteCard(model: model)
            }
        }
        .sheet(item: $model.editingGroup) { group in
            GroupEditorView(model: model, draft: group, original: group.members)
        }
    }
}

private extension MenuBarSection {
    var symbol: String {
        switch self {
        case .shown: "eyeglasses"
        case .hidden: "eye.slash"
        case .alwaysHidden: "eye.trianglebadge.exclamationmark"
        }
    }

    var hint: String {
        switch self {
        case .shown: "Always visible."
        case .hidden: "Shown when you click the Barkeeper icon."
        case .alwaysHidden: "Shown only with ⌥-click on the Barkeeper icon."
        }
    }
}

// MARK: - Status

private struct StatusCard: View {
    @ObservedObject var model: LayoutModel

    var body: some View {
        SettingsCard(title: "On-Demand Layout") {
            HStack(spacing: 10) {
                icon.font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                if model.status == .unorganized || isFailure {
                    Button("Organize Now") { Task { await model.organize() } }
                        .controlSize(.regular)
                }
            }
            .padding(12)
        }
    }

    private var isFailure: Bool {
        if case .failed = model.status { return true }
        return false
    }

    @ViewBuilder private var icon: some View {
        switch model.status {
        case .organized: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .unorganized: Image(systemName: "arrow.left.arrow.right.circle.fill").foregroundStyle(.orange)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        default: ProgressView().controlSize(.small).frame(width: 18)
        }
    }

    private var title: String {
        switch model.status {
        case .loading: "Reading menu bar…"
        case .organized: "Menu Items Organized"
        case .unorganized: "Menu Bar Differs From Layout"
        case .organizing: "Organizing…"
        case .failed: "Couldn't Organize"
        case .noPermission: "Permission Needed"
        }
    }

    private var detail: String {
        switch model.status {
        case .loading: "Looking for items on the active menu bar."
        case .organized: "Your menu bar matches the layout below."
        case .unorganized: "Some items moved since the layout was saved."
        case .organizing: "Your mouse may pause briefly while items move."
        case .failed(let message): message
        case .noPermission: ""
        }
    }
}

private struct PermissionNotice: View {
    var body: some View {
        SettingsCard {
            SettingsRow(label: "Accessibility permission required",
                        detail: "Barkeeper needs it to read and move menu bar items.", showsDivider: false) {
                Button("Grant…") { Permission.accessibility.request() }
            }
        }
    }
}

// MARK: - Strips

private struct SectionStrip: View {
    @ObservedObject var model: LayoutModel
    let section: MenuBarSection

    private let padding: CGFloat = 10
    private let height: CGFloat = 34

    var body: some View {
        let entries = model.entries(in: section)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                IconTile(symbol: section.symbol, size: 22)
                Text(section == .alwaysHidden ? "Always Hidden" : "\(section.title) Items")
                    .font(.system(size: 13, weight: .semibold))
                Text(section.hint).font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if isDropIndicator(at: index) { DropIndicator() }
                        ItemCell(entry: entry, isDragging: model.dragging == entry.id)
                            .onDrag {
                                model.dragging = entry.id
                                return NSItemProvider(object: entry.id.description as NSString)
                            }
                            .disabled(!entry.isDraggable)
                            .onTapGesture {
                                if let id = entry.groupID { model.editGroup(id) }
                            }
                            .contextMenu {
                                if let id = entry.groupID {
                                    Button("Edit Group…") { model.editGroup(id) }
                                }
                                if entry.isSpacer {
                                    Button("Remove Spacer") {
                                        AppServices.shared.spacers.remove(name: entry.item.identity.name)
                                        Task { await model.refresh() }
                                    }
                                }
                            }
                    }
                    if isDropIndicator(at: entries.count) { DropIndicator() }
                    if entries.isEmpty {
                        Text("Drop items here").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, padding)
                .frame(width: geo.size.width, height: height)
                .background(Color.barStrip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isTargeted ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isTargeted ? 2 : 1))
                .environment(\.colorScheme, .dark)
                .onDrop(of: [.plainText], delegate: StripDropDelegate(
                    model: model, section: section, entries: entries, stripWidth: geo.size.width, padding: padding))
            }
            .frame(height: height)
        }
    }

    private var isTargeted: Bool { model.dropTarget?.section == section }

    private func isDropIndicator(at index: Int) -> Bool {
        model.dropTarget?.section == section && model.dropTarget?.index == index
    }
}

private struct ItemCell: View {
    let entry: LayoutEntry
    let isDragging: Bool

    var body: some View {
        Group {
            if entry.isSpacer {
                RoundedRectangle(cornerRadius: 3).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: entry.width - 6, height: 18)
                    .frame(width: entry.width)
            } else if let image = entry.image {
                Image(nsImage: image).interpolation(.high)
                    .frame(width: entry.width, height: 30)
            } else {
                Text(entry.item.displayName.prefix(2)).font(.system(size: 11, weight: .medium))
                    .frame(width: entry.width)
            }
        }
        .opacity(isDragging ? 0.3 : (entry.isDraggable ? 1 : 0.55))
        .contentShape(Rectangle())
        .help(entry.isSpacer ? "Spacer" : entry.groupID != nil ? "Group — click to edit" : entry.item.displayName)
    }
}

private struct DropIndicator: View {
    var body: some View {
        Capsule().fill(Color.accentColor).frame(width: 3, height: 22).padding(.horizontal, 2)
    }
}

private struct StripDropDelegate: DropDelegate {
    let model: LayoutModel
    let section: MenuBarSection
    let entries: [LayoutEntry]
    let stripWidth: CGFloat
    let padding: CGFloat

    /// Index where the dragged item would land, from the pointer x (items are right-aligned).
    private func index(at x: CGFloat) -> Int {
        let total = entries.reduce(0) { $0 + $1.width }
        var edge = stripWidth - padding - total
        for (i, entry) in entries.enumerated() {
            if x < edge + entry.width / 2 { return i }
            edge += entry.width
        }
        return entries.count
    }

    func validateDrop(info: DropInfo) -> Bool { model.dragging != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        model.dropTarget = (section, index(at: info.location.x))
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if model.dropTarget?.section == section { model.dropTarget = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let id = model.dragging else { return false }
        var target = index(at: info.location.x)
        // Indices after the dragged item's old slot shift by one once it is removed.
        if let old = entries.firstIndex(where: { $0.id == id }), old < target { target -= 1 }
        model.dragging = nil
        model.dropTarget = nil
        Task { await model.drop(id, in: section, at: target) }
        return true
    }
}

// MARK: - Palette

private struct PaletteCard: View {
    @ObservedObject var model: LayoutModel

    var body: some View {
        SettingsCard(title: "Palette", footnote: "New spacers and groups appear right of the Barkeeper icon; drag them where you need them.") {
            HStack(spacing: 10) {
                Button {
                    Task { await model.addSpacer() }
                } label: {
                    Label("Add a Spacer", systemImage: "rectangle.dashed")
                }
                Button {
                    Task { await model.addGroup() }
                } label: {
                    Label("Add a Menu Bar Item Group", systemImage: "square.stack.3d.up")
                }
                Spacer()
            }
            .padding(12)
        }
    }
}
