import SwiftUI

/// Large page header: tinted icon tile, title, subtitle.
struct PageHeader: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 22, weight: .semibold)).tracking(-0.3)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 6)
    }
}

/// Titled group of rows on a rounded card, with an optional footnote.
struct SettingsCard<Content: View>: View {
    var title: String?
    var footnote: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title).font(.system(size: 13, weight: .semibold)).padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.cardBorder))
            if let footnote {
                Text(footnote).font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
    }
}

/// One row inside a `SettingsCard`.
struct SettingsRow<Accessory: View>: View {
    let label: String
    var detail: String?
    var showsDivider = true
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 13))
                    if let detail {
                        Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                accessory
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            if showsDivider { Divider().padding(.leading, 12) }
        }
    }
}

extension Color {
    static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.6)
    static let cardBorder = Color.primary.opacity(0.07)
    /// The menu bar strip: a dark translucent band, the same in light and dark mode.
    static let barStrip = Color(white: 0.11)
}
