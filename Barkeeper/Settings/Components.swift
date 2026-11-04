import SwiftUI

// Visual language of the settings window: a plain bold page title, then rounded cards. A card can
// carry its own title and footnote inside it; rows start with a small icon tile, then a label with
// an optional explanation, and the control on the trailing edge.

/// Page title.
struct PageHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 20, weight: .bold)).tracking(-0.3)
            if let subtitle {
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 2)
    }
}

/// Rounded card grouping related rows, with an optional title and footnote inside it.
struct SettingsCard<Content: View>: View {
    var title: String?
    var footnote: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, Metrics.inset)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }
            content
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Metrics.inset)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Color.cardBorder))
    }
}

/// Small rounded tile with a tinted symbol, leading a row.
struct IconTile: View {
    let symbol: String
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .frame(width: size, height: size)
            .background(Color.tileBackground, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

/// One row inside a `SettingsCard`. `symbol` adds a leading icon tile; `indented` aligns a
/// sub-option with the text of a row that has one.
struct SettingsRow<Accessory: View>: View {
    let label: String
    var detail: String?
    var symbol: String?
    var indented = false
    var showsDivider = true
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let symbol {
                    IconTile(symbol: symbol)
                } else if indented {
                    Color.clear.frame(width: 26, height: 1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 13))
                    if let detail {
                        Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                accessory
            }
            .padding(.horizontal, Metrics.inset)
            .padding(.vertical, 9)
            if showsDivider {
                Divider().padding(.leading, Metrics.inset).padding(.trailing, Metrics.inset)
            }
        }
    }
}

enum Metrics {
    static let inset: CGFloat = 16
    static let cardRadius: CGFloat = 14
}

extension Color {
    static let cardBackground = Color.primary.opacity(0.035)
    static let cardBorder = Color.primary.opacity(0.06)
    static let tileBackground = Color.primary.opacity(0.07)
    /// The menu bar strip: a dark translucent band, the same in light and dark mode.
    static let barStrip = Color(white: 0.11)
}
