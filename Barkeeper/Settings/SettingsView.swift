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

    /// Words the sidebar search matches besides the title.
    var keywords: [String] {
        switch self {
        case .general: ["login", "start", "hover", "click", "scroll", "swipe", "desktop", "space", "bar", "notch",
                        "rehide", "hide", "option", "shift", "icon", "divider", "bee"]
        case .layout: ["items", "hidden", "always hidden", "shown", "drag", "spacer", "group", "organize"]
        case .about: ["version", "website", "support", "feedback", "logs", "debug", "quit"]
        }
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty || title.lowercased().contains(q) || keywords.contains { $0.contains(q) }
    }

    static let sections: [(title: String, pages: [SettingsPage])] = [
        ("Settings", [.general, .layout]),
        ("App", [.about]),
    ]
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage = {
        // Debug: `--settings-page <general|layout|about>`.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--settings-page"), i + 1 < args.count, let p = SettingsPage(rawValue: args[i + 1]) {
            return p
        }
        return .layout
    }()
}

struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var layout: LayoutModel
    @ObservedObject var prefs: Preferences
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { navigation.page }, set: { if let p = $0 { navigation.page = p } })) {
                ForEach(SettingsPage.sections, id: \.title) { section in
                    let pages = section.pages.filter { $0.matches(search) }
                    if !pages.isEmpty {
                        Section(section.title) {
                            ForEach(pages) { page in
                                Label(page.title, systemImage: page.symbol).tag(page)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Search settings")
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            ScrollView {
                Group {
                    switch navigation.page {
                    case .general: GeneralView(prefs: prefs)
                    case .layout: MenuBarLayoutView(model: layout)
                    case .about: AboutView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: 680, alignment: .leading)
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
            .navigationTitle("Barkeeper Settings")
        }
        .task(id: navigation.page) {
            if navigation.page == .layout { await layout.refresh() }
        }
    }
}
