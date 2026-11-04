import AppKit
import OSLog
import UniformTypeIdentifiers

/// Exports this run's log (every Barkeeper category) to a text file the user picks, to attach to
/// bug reports.
@MainActor
enum LogExporter {
    static func export() {
        let panel = NSSavePanel()
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "Barkeeper Logs \(stamp).txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task.detached(priority: .userInitiated) {
            let text = collect()
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            } catch {
                Log.app.error("Log export failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    nonisolated static func collect() -> String {
        let info = ProcessInfo.processInfo
        var lines = [
            "Barkeeper \(Bundle.main.versionString)",
            "macOS \(info.operatingSystemVersionString)",
            "Exported \(Date().formatted(date: .abbreviated, time: .standard))",
            "",
        ]
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let subsystem = Log.subsystem
            let entries = try store.getEntries(matching: NSPredicate(format: "subsystem == %@", subsystem))
            for case let entry as OSLogEntryLog in entries {
                let level = switch entry.level {
                case .error: "ERROR"
                case .fault: "FAULT"
                case .notice: "NOTICE"
                case .debug: "DEBUG"
                default: "INFO"
                }
                lines.append("\(entry.date.formatted(.iso8601.time(includingFractionalSeconds: true))) [\(entry.category)] \(level) \(entry.composedMessage)")
            }
        } catch {
            lines.append("Could not read the log: \(error.localizedDescription)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
