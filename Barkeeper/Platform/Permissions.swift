import AppKit
import ApplicationServices
import CoreGraphics

/// System permissions Barkeeper depends on.
enum Permission: String, CaseIterable, Identifiable, Sendable {
    case accessibility
    case screenRecording

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        }
    }

    var purpose: String {
        switch self {
        case .accessibility:
            "Needed to read, click and move menu bar items."
        case .screenRecording:
            "Needed to show images of hidden menu bar items."
        }
    }

    var isRequired: Bool { self == .accessibility }

    var isGranted: Bool {
        switch self {
        case .accessibility: AXIsProcessTrusted()
        case .screenRecording: CGPreflightScreenCaptureAccess()
        }
    }

    /// Triggers the system prompt (first time) and opens the matching System Settings pane.
    func request() {
        switch self {
        case .accessibility:
            let key = "AXTrustedCheckOptionPrompt" as CFString
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
        }
        openSettings()
    }

    func openSettings() {
        let anchor = switch self {
        case .accessibility: "Privacy_Accessibility"
        case .screenRecording: "Privacy_ScreenCapture"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Observable permission state, polled while someone is watching.
@MainActor
final class PermissionsModel: ObservableObject {
    @Published private(set) var granted: [Permission: Bool] = [:]
    private var timer: Timer?

    init() { refresh() }

    var allGranted: Bool { Permission.allCases.allSatisfy { granted[$0] == true } }
    var requiredGranted: Bool { Permission.allCases.filter(\.isRequired).allSatisfy { granted[$0] == true } }

    func refresh() {
        var next: [Permission: Bool] = [:]
        for p in Permission.allCases { next[p] = p.isGranted }
        if next != granted {
            Log.platform.info("Permissions: \(next.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " "), privacy: .public)")
            granted = next
        }
    }

    func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
