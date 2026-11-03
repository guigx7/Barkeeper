import SwiftUI

struct GeneralView: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(symbol: "gearshape.fill", tint: .gray, title: "General",
                       subtitle: "Configure the basics of Barkeeper.")

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
        }
    }
}
