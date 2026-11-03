import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, layout, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .layout: "Menu Bar Layout"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .layout: "menubar.rectangle"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage = .layout
}

struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var layout: LayoutModel
    @ObservedObject var prefs: Preferences

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: Binding(
                get: { navigation.page }, set: { if let p = $0 { navigation.page = p } })
            ) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            ScrollView {
                Group {
                    switch navigation.page {
                    case .general: GeneralView(prefs: prefs)
                    case .layout: MenuBarLayoutView(model: layout)
                    case .about: AboutView()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                if navigation.page == .layout {
                    ToolbarItem(placement: .primaryAction) {
                        Button { Task { await layout.refresh() } } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Reload menu bar items")
                    }
                }
            }
            .navigationTitle(navigation.page.title)
        }
        .task(id: navigation.page) {
            if navigation.page == .layout { await layout.refresh() }
        }
    }
}
