import SwiftUI

struct GeneralView: View {
    @ObservedObject var prefs: Preferences
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "General")

            SettingsCard(footnote: loginItem.lastError) {
                SettingsRow(label: "Start at login",
                            detail: loginItem.needsApproval
                                ? "Allow Barkeeper in System Settings → General → Login Items."
                                : "Opens automatically every time you log in.",
                            symbol: "laptopcomputer", showsDivider: false) {
                    if loginItem.needsApproval {
                        Button("Open Settings…") { loginItem.openSystemSettings() }
                    }
                    Toggle("", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.set($0) }))
                        .labelsHidden().toggleStyle(.switch)
                }
            }

            MenuBarIconCard(prefs: prefs)

            SettingsCard(title: "Show Hidden Items") {
                SettingsRow(label: "Click on empty menu bar space", detail: "Click again to hide them.",
                            symbol: "cursorarrow.click") {
                    Toggle("", isOn: $prefs.revealOnEmptyClick).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Hover over empty menu bar space", symbol: "cursorarrow.motionlines",
                            showsDivider: false) {
                    Toggle("", isOn: $prefs.revealOnHover).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Delay", indented: true, showsDivider: false) {
                    HStack(spacing: 10) {
                        Slider(value: $prefs.hoverDelay, in: 0...1, step: 0.1).frame(width: 160)
                        Text(String(format: "%.1f s", prefs.hoverDelay))
                            .monospacedDigit().foregroundStyle(.secondary)
                            .fixedSize().frame(width: 36, alignment: .trailing)
                    }
                    .disabled(!prefs.revealOnHover)
                }
            }

            SettingsCard(title: "Scroll in the Menu Bar",
                         footnote: "Switching desktops uses the Mission Control shortcuts in System Settings → Keyboard → Keyboard Shortcuts.") {
                SettingsRow(label: "Scroll or swipe in the menu bar",
                            detail: "Anywhere on the menu bar, with a mouse wheel or a trackpad.",
                            symbol: "scroll", showsDivider: false) {
                    Toggle("", isOn: $prefs.scrollEnabled).labelsHidden().toggleStyle(.switch)
                }
                ForEach(Preferences.ScrollDirection.allCases) { direction in
                    ScrollActionRow(direction: direction, prefs: prefs)
                        .disabled(!prefs.scrollEnabled)
                }
            }

            SettingsCard(title: "Barkeeper Bar",
                         footnote: "Shows hidden items in a bar below the menu bar instead of expanding them in place. Useful on screens with a notch.") {
                SettingsRow(label: "Use the Barkeeper Bar for hidden items",
                            detail: "When off, hidden items expand in the menu bar itself.",
                            symbol: "rectangle.topthird.inset.filled", showsDivider: false) {
                    Toggle("", isOn: $prefs.useBarkeeperBar).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Only on screens with a notch", indented: true, showsDivider: false) {
                    Toggle("", isOn: $prefs.barOnlyOnNotch).labelsHidden().toggleStyle(.switch)
                        .disabled(!prefs.useBarkeeperBar)
                }
                SettingsRow(label: "Show items to the right when there's no room",
                            detail: "A clicked item that would land behind the notch goes after the shown items.",
                            indented: true, showsDivider: false) {
                    Toggle("", isOn: $prefs.showItemsToRight).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Hiding") {
                SettingsRow(label: "Automatically rehide",
                            detail: "Hide revealed items again when you click outside the menu bar.",
                            symbol: "eye.slash") {
                    Toggle("", isOn: $prefs.autoRehide).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Shift-click the icon to show all items",
                            detail: "Reveals Hidden and Always Hidden items, as long as they fit.",
                            symbol: "shift") {
                    Toggle("", isOn: $prefs.shiftClickShowsAll).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Option-click the icon shows", symbol: "option", showsDivider: false) {
                    Picker("", selection: $prefs.optionClickItems) {
                        Text("All Hidden").tag(Preferences.OptionClickItems.allHidden)
                        Text("Always Hidden").tag(Preferences.OptionClickItems.alwaysHidden)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
        .onAppear { loginItem.refresh() }
    }
}

private struct ScrollActionRow: View {
    let direction: Preferences.ScrollDirection
    @ObservedObject var prefs: Preferences

    var body: some View {
        SettingsRow(label: direction.title, indented: true, showsDivider: false) {
            Picker("", selection: Binding(
                get: { prefs.scrollActions[direction] ?? Preferences.ScrollAction.none },
                set: { prefs.scrollActions[direction] = $0 })) {
                ForEach(Preferences.ScrollAction.allCases) { action in
                    Text(action.title).tag(action)
                    if action == .none { Divider() }
                }
            }
            .labelsHidden()
            .frame(width: 210)
        }
    }
}

// MARK: - Menu bar icon

/// The menu bar icon choice: a header with the current icon, then every icon as a grid of tiles.
private struct MenuBarIconCard: View {
    @ObservedObject var prefs: Preferences
    @State private var expanded = false
    private static let collapsedCount = 43

    private var visible: [String] {
        let all = ControlItems.iconChoices
        guard !expanded else { return all }
        var shown = Array(all.prefix(Self.collapsedCount))
        if !shown.contains(prefs.iconSymbol), all.contains(prefs.iconSymbol) {
            shown[shown.count - 1] = prefs.iconSymbol // keep the current choice visible
        }
        return shown
    }

    var body: some View {
        SettingsCard {
            HStack(spacing: 12) {
                IconGlyph(name: prefs.iconSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu bar icon").font(.system(size: 13, weight: .semibold))
                    Text("Choose the icon Barkeeper shows in the menu bar.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Metrics.inset)
            .padding(.top, 10)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36, maximum: 40), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(visible, id: \.self) { symbol in
                    IconTileButton(selected: symbol == prefs.iconSymbol) {
                        prefs.iconSymbol = symbol
                    } label: {
                        IconGlyph(name: symbol)
                    }
                    .help(symbol.replacingOccurrences(of: "custom.", with: ""))
                }
                IconTileButton(selected: false) {
                    withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "ellipsis")
                }
                .help(expanded ? "Show fewer" : "Show all icons")
            }
            .padding(.horizontal, Metrics.inset)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Text("The Barkeeper icon always stays visible: it cannot be moved into a hidden section.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, Metrics.inset)
                .padding(.bottom, 10)
        }
    }
}

private struct IconTileButton<Label: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 14))
                .frame(width: 36, height: 34)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var background: Color {
        if selected { return Color.accentColor.opacity(0.18) }
        return Color.primary.opacity(hovering ? 0.10 : 0.05)
    }
}

/// An SF Symbol, or one of Barkeeper's own drawn icons.
struct IconGlyph: View {
    let name: String

    var body: some View {
        if let custom = CustomIcons.image(name) {
            Image(nsImage: custom).renderingMode(.template)
        } else {
            Image(systemName: name)
        }
    }
}
