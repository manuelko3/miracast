import Foundation
@_exported import os.log
@_exported import os

/// Централизованные `os.Logger`-категории для всего приложения и broadcast extension.
/// Сообщения автоматически попадают в Console.app, отображаются с фильтром по subsystem.
enum Log {
    private static let subsystem = "miracast.Miracast"

    static let discovery = Logger(subsystem: subsystem, category: "discovery")
    static let dlna      = Logger(subsystem: subsystem, category: "dlna")
    static let chromecast = Logger(subsystem: subsystem, category: "chromecast")
    static let airplay   = Logger(subsystem: subsystem, category: "airplay")
    static let dial      = Logger(subsystem: subsystem, category: "dial")
    static let hls       = Logger(subsystem: subsystem, category: "hls")
    static let broadcast = Logger(subsystem: subsystem, category: "broadcast")
    static let state     = Logger(subsystem: subsystem, category: "state")
}
