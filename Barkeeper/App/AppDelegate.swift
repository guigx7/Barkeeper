import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controlItems: ControlItems?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Barkeeper \(Bundle.main.versionString, privacy: .public) launched")
        controlItems = ControlItems()
    }
}

extension Bundle {
    var versionString: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
