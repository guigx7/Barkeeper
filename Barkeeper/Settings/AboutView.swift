import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(
                        LinearGradient(colors: [Color(white: 0.28), Color(white: 0.1)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                Text("Barkeeper").font(.system(size: 26, weight: .semibold)).tracking(-0.4)
                Text("Version \(Bundle.main.versionString)")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            SettingsCard {
                LinkRow(label: "Website", symbol: "globe", url: "https://github.com/guigx7/g-bar")
                LinkRow(label: "Support", symbol: "lifepreserver", url: "https://github.com/guigx7/g-bar/issues")
                LinkRow(label: "Feedback", symbol: "bubble.left", url: "https://github.com/guigx7/g-bar/issues/new", last: true)
            }
            .frame(maxWidth: 380)

            Button("Quit Barkeeper") { NSApp.terminate(nil) }
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LinkRow: View {
    let label: String
    let symbol: String
    let url: String
    var last = false

    var body: some View {
        SettingsRow(label: label, showsDivider: !last) {
            Button {
                if let u = URL(string: url) { NSWorkspace.shared.open(u) }
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help(url)
        }
    }
}
