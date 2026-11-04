import SwiftUI

struct GeneralView: View {
    @ObservedObject var prefs: Preferences
    @StateObject private var loginItem = LoginItem()
    @State private var spacing = ItemSpacing.current

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
                SettingsRow(label: "Swipe or scroll in the menu bar",
                            detail: "Down reveals, up hides.") {
                    Toggle("", isOn: $prefs.revealOnScroll).labelsHidden().toggleStyle(.switch)
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
                    Picker("", selection: $prefs.iconSymbol) {
                        ForEach(ControlItems.iconChoices, id: \.symbol) { choice in
                            Label(choice.name, systemImage: choice.symbol).tag(choice.symbol)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsRow(label: "Show divider between shown and hidden items",
                            detail: "Keeps a ‹ next to the Barkeeper icon while items are hidden.",
                            showsDivider: false) {
                    Toggle("", isOn: $prefs.showDivider).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Menu Bar Item Spacing",
                         footnote: "A system-wide setting. Apps pick it up when they relaunch; log out to apply it everywhere.") {
                SettingsRow(label: "Spacing between all menu bar items", showsDivider: false) {
                    HStack(spacing: 12) {
                        SpacingPreview(spacing: spacing)
                        Picker("", selection: $spacing) {
                            ForEach(ItemSpacing.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .onChange(of: spacing) { _, new in new.apply() }
                    }
                }
            }

            SettingsCard(title: "Screens") {
                SettingsRow(label: "Show all items when the active screen is wide enough",
                            detail: "Nothing is hidden on screens at least this wide.") {
                    Toggle("", isOn: $prefs.showAllOnLargeScreen).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(label: "Minimum width", showsDivider: false) {
                    HStack(spacing: 8) {
                        Image(systemName: "laptopcomputer").foregroundStyle(.secondary)
                        Slider(value: $prefs.largeScreenWidth, in: 1000...6000, step: 100).frame(width: 160)
                        Image(systemName: "display").foregroundStyle(.secondary)
                        Text("\(Int(prefs.largeScreenWidth)) pt").monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .disabled(!prefs.showAllOnLargeScreen)
                }
            }
        }
        .onAppear { loginItem.refresh() }
    }
}

/// Three dots on a bar strip, spaced like the chosen setting.
private struct SpacingPreview: View {
    let spacing: ItemSpacing

    var body: some View {
        let gap = CGFloat((spacing.values?.spacing ?? 16) + (spacing.values?.padding ?? 16)) / 2.2
        HStack(spacing: gap) {
            ForEach(["wifi", "battery.75percent", "magnifyingglass"], id: \.self) {
                Image(systemName: $0).font(.system(size: 11))
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(Color.barStrip, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: spacing)
    }
}
