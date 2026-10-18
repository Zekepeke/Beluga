import AppKit
import Foundation

@MainActor
final class AppErrorCenter: ObservableObject {
    struct Issue: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    static let shared = AppErrorCenter()
    @Published var issue: Issue?

    func report(_ title: String, error: Error) {
        report(title, message: error.localizedDescription)
    }

    /// The alert itself lives in the main window's view. Bringing the window back here (not from
    /// that view) keeps a failure visible when the window was closed: it is recreated and shows
    /// the pending issue.
    func report(_ title: String, message: String) {
        Log.history.error("reported to user: \(title, privacy: .public)")
        issue = Issue(title: title, message: message)
        (NSApplication.shared.delegate as? AppDelegate)?.showMainWindow()
    }
}

struct RecordingStartFailure {
    let sessionID: UUID
    let message: String
}
