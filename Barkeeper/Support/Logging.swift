import OSLog

enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "br.tec.guigx.Barkeeper"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let menuBar = Logger(subsystem: subsystem, category: "menubar")
    static let platform = Logger(subsystem: subsystem, category: "platform")
}
