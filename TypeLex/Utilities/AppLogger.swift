import OSLog

enum AppLogger {
    private static let subsystem = "com.typelex.app"

    static let repository = Logger(subsystem: subsystem, category: "repository")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let migration = Logger(subsystem: subsystem, category: "migration")
    static let speech = Logger(subsystem: subsystem, category: "speech")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let app = Logger(subsystem: subsystem, category: "app")
    static let telemetry = Logger(subsystem: subsystem, category: "telemetry")
}
