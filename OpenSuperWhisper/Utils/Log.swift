import os

/// os_log loggers for the dictation pipeline, visible in Console.app under subsystem
/// `com.zekepeke.beluga`. Never log transcript text, file contents or API keys.
enum Log {
    static let subsystem = "com.zekepeke.beluga"

    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let recording = Logger(subsystem: subsystem, category: "recording")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let cleanup = Logger(subsystem: subsystem, category: "cleanup")
    static let paste = Logger(subsystem: subsystem, category: "paste")
    static let history = Logger(subsystem: subsystem, category: "history")
}
