import XCTest
import GRDB
@testable import OpenSuperWhisper

@MainActor
private final class PasteTrackingIndicator: IndicatorViewModel {
    var inserted: [String] = []
    override func insertText(_ text: String) { inserted.append(text) }
}

/// The dictation pipeline is owned by the indicator view model, not by the main window:
/// these tests run it with no ContentView or ContentViewModel in existence.
@MainActor
final class DictationPipelineTests: XCTestCase {
    func testDictationCompletesIntoHistoryWithoutAnyMainWindow() async throws {
        let store = try RecordingStore(databaseQueue: DatabaseQueue())
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try Data([1]).write(to: source)
        let service = TranscriptionService(engine: NamedTestEngine("recognized"))
        let vm = PasteTrackingIndicator(transcriptionService: service, recordingStore: store,
            stopRecording: { RecordedAudio(url: source, samples: []) }, cancelAudioRecording: {})
        vm.state = .recording
        vm.startDecoding()
        var rows: [Recording] = []
        for _ in 0..<200 where rows.isEmpty {
            try await Task.sleep(nanoseconds: 10_000_000)
            rows = try await store.fetchRecordings(limit: 10, offset: 0)
        }
        defer { rows.forEach { try? FileManager.default.removeItem(at: $0.url) }; vm.cleanup() }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.status, .completed)
        // Post-processing may adjust case and punctuation; the saved and pasted text must agree.
        XCTAssertEqual(rows.first?.transcription.lowercased().trimmingCharacters(in: .punctuationCharacters), "recognized")
        XCTAssertEqual(vm.inserted, rows.map(\.transcription))
    }

    func testErrorCenterKeepsIssuePendingForAWindowThatIsRecreated() {
        let center = AppErrorCenter.shared
        center.issue = nil
        center.report("Recording failed", message: "details")
        XCTAssertEqual(center.issue?.title, "Recording failed")
        center.issue = nil
    }
}
