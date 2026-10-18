import Foundation

/// Beluga shares models and history with OpenSuperWhisper, so these locations
/// stay pinned to OpenSuperWhisper's bundle-ID folder instead of following ours.
enum SharedPaths {
    static let directoryName = "ru.starmel.OpenSuperWhisper"

    static var appSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(directoryName)
    }

    static var modelsDirectory: URL {
        appSupportDirectory.appendingPathComponent("whisper-models")
    }

    static var recordingsDirectory: URL {
        appSupportDirectory.appendingPathComponent("recordings")
    }

    static var databaseURL: URL {
        appSupportDirectory.appendingPathComponent("recordings.sqlite")
    }
}
