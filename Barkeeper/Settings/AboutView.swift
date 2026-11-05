import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                Text("Barkeeper").font(.system(size: 17, weight: .bold))
                Text("Version \(Bundle.main.versionString)")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Text("Keeps your menu bar tidy.\nHide, group and rearrange menu bar items, and reach hidden ones in a click.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                HStack(spacing: 10) {
                    Button("Send Feedback") { open("https://github.com/guigx7/Barkeeper/issues/new") }
                    Button("Export Debug Logs…") { LogExporter.export() }
                    Button("View on GitHub") { open("https://github.com/guigx7/Barkeeper") }
                        .buttonStyle(.link)
                }
                .padding(.top, 10)
                Text("© 2026 Guilherme Abdelnor \"guigx7\"")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 20)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Color.cardBorder))

            SettingsCard(title: "Help") {
                SettingsRow(label: "Support", detail: "Questions and known issues.", symbol: "lifepreserver") {
                    Button("Open") { open("https://github.com/guigx7/Barkeeper/issues") }
                }
                SettingsRow(label: "Debug logs",
                            detail: "Saves this session's log to a text file you can attach to a bug report.",
                            symbol: "doc.text.magnifyingglass", showsDivider: false) {
                    Button("Export…") { LogExporter.export() }
                }
            }

            SettingsCard {
                SettingsRow(label: "Quit Barkeeper",
                            detail: "Hidden items come back to the menu bar while Barkeeper is not running.",
                            symbol: "power", showsDivider: false) {
                    Button("Quit") { NSApp.terminate(nil) }
                }
            }
        }
    }

    private func open(_ url: String) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }
}
