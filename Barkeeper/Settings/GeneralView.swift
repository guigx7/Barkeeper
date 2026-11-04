import SwiftUI

struct GeneralView: View {
    @ObservedObject var prefs: Preferences
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(symbol: "gearshape.fill", tint: .gray, title: "General",
                       subtitle: "Configure the basics of Barkeeper.")

            SettingsCard(footnote: loginItem.lastError) {
                SettingsRow(label: "Start at login",
                            detail: loginItem.needsApproval ? "Allow Barkeeper in System Settings → Login Items." : nil,
                            showsDivider: false) {
                    if loginItem.needsApproval {
                        Button("Open Settings…") { loginItem.openSystemSettings() }
                    }
                    Toggle("", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.set($0) }))
                        .labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Show Hidden Items") {
                SettingsRow(label: "Click on empty menu bar space") {
                    Toggle("", isOn: $prefs.revealOnEmptyClick).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Hover over empty menu bar space") {
                    Toggle("", isOn: $prefs.revealOnHover).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Hover delay", showsDivider: false) {
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
                         footnote: "Works anywhere on the menu bar, with a mouse wheel or a trackpad swipe. Switching desktops uses the Mission Control shortcuts in System Settings → Keyboard → Keyboard Shortcuts.") {
                SettingsRow(label: "Scroll or swipe in the menu bar") {
                    Toggle("", isOn: $prefs.scrollEnabled).labelsHidden().toggleStyle(.switch)
                }
                ForEach(Preferences.ScrollDirection.allCases) { direction in
                    ScrollActionRow(direction: direction, prefs: prefs,
                                    showsDivider: direction != Preferences.ScrollDirection.allCases.last)
                        .disabled(!prefs.scrollEnabled)
                }
            }

            SettingsCard(title: "Barkeeper Bar",
                         footnote: "Show your hidden items in a bar below the menu bar. Useful on screens with a notch.") {
                SettingsRow(label: "Use Barkeeper Bar to show hidden items",
                            detail: "When off, hidden items expand in the menu bar itself.") {
                    Toggle("", isOn: $prefs.useBarkeeperBar).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Only on screens with a notch") {
                    Toggle("", isOn: $prefs.barOnlyOnNotch).labelsHidden().toggleStyle(.switch)
                        .disabled(!prefs.useBarkeeperBar)
                }
                SettingsRow(label: "Show items to the right when there's no room",
                            detail: "A clicked item that would land behind the notch is placed after the shown items.",
                            showsDivider: false) {
                    Toggle("", isOn: $prefs.showItemsToRight).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Show Always Hidden Items") {
                SettingsRow(label: "Shift-click the Barkeeper icon to show all items",
                            detail: "Reveals Hidden and Always Hidden items, as long as they fit.", showsDivider: false) {
                    Toggle("", isOn: $prefs.shiftClickShowsAll).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Hiding", footnote: "Option-click the Barkeeper icon to show hidden items.") {
                SettingsRow(label: "Automatically rehide",
                            detail: "Hide revealed items again when you click outside the menu bar.") {
                    Toggle("", isOn: $prefs.autoRehide).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Items to show on option-clicking the Barkeeper icon", showsDivider: false) {
                    Picker("", selection: $prefs.optionClickItems) {
                        Text("All Hidden").tag(Preferences.OptionClickItems.allHidden)
                        Text("Always Hidden").tag(Preferences.OptionClickItems.alwaysHidden)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsCard(title: "Barkeeper Menu Bar Item",
                         footnote: "The Barkeeper icon always stays visible: it cannot be moved into a hidden section.") {
                SettingsRow(label: "Icon") {
                    IconPicker(selection: $prefs.iconSymbol)
                }
                SettingsRow(label: "Show divider between shown and hidden items",
                            detail: "Keeps a ‹ next to the Barkeeper icon while items are hidden.",
                            showsDivider: false) {
                    Toggle("", isOn: $prefs.showDivider).labelsHidden().toggleStyle(.switch)
                }
            }

        }
        .onAppear { loginItem.refresh() }
    }
}

private struct ScrollActionRow: View {
    let direction: Preferences.ScrollDirection
    @ObservedObject var prefs: Preferences
    let showsDivider: Bool

    var body: some View {
        SettingsRow(label: direction.title, showsDivider: showsDivider) {
            Picker("", selection: Binding(
                get: { prefs.scrollActions[direction] ?? Preferences.ScrollAction.none },
                set: { prefs.scrollActions[direction] = $0 })) {
                ForEach(Preferences.ScrollAction.allCases) { action in
                    Text(action.title).tag(action)
                    if action == .none { Divider() }
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// The current icon as a button; opens a grid of every available symbol.
private struct IconPicker: View {
    @Binding var selection: String
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 6) {
                IconGlyph(name: selection).frame(width: 20)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 8), spacing: 6) {
                    ForEach(ControlItems.iconChoices, id: \.self) { symbol in
                        Button {
                            selection = symbol
                            isPresented = false
                        } label: {
                            IconGlyph(name: symbol)
                                .font(.system(size: 14))
                                .frame(width: 34, height: 30)
                                .background(symbol == selection ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(symbol == selection ? Color.accentColor : .clear, lineWidth: 1.5))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(symbol)
                    }
                }
                .padding(12)
            }
            .frame(height: 260)
        }
    }
}

/// An SF Symbol, or one of Barkeeper's own drawn icons.
private struct IconGlyph: View {
    let name: String

    var body: some View {
        if let custom = CustomIcons.image(name) {
            Image(nsImage: custom).renderingMode(.template)
        } else {
            Image(systemName: name)
        }
    }
}
