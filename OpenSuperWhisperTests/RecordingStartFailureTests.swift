import XCTest
@testable import OpenSuperWhisper

@MainActor
final class RecordingStartFailureTests: XCTestCase {
    func testLateRecorderEventsCannotReviveFailedIndicator() async throws {
        let vm = IndicatorViewModel(transcriptionService: TranscriptionService(engine: NamedTestEngine("test")))
        let recorder = AudioRecorder.shared
        let previousRecording = recorder.isRecording
        let previousConnecting = recorder.isConnecting
        defer {
            recorder.isRecording = previousRecording
            recorder.isConnecting = previousConnecting
            vm.cleanup()
        }
        vm.state = .connecting
        recorder.isConnecting = true
        recorder.isRecording = true
        vm.resetAfterRecordingFailure()
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(vm.state, .idle)
        XCTAssertFalse(vm.isBlinking)
    }

    func testMainWindowClearsConnectingWhenRecorderStartFails() async throws {
        let vm = ContentViewModel(fetchPage: { _, _, _ in [] })
        let recorder = AudioRecorder.shared
        vm.state = .connecting
        recorder.isRecording = false
        recorder.isConnecting = false
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(vm.state, .idle)
    }
    func testIndicatorClearsOptimisticCaptureStateAfterFailure() {
        let vm = IndicatorViewModel(transcriptionService: TranscriptionService(engine: NamedTestEngine("test")))
        for state in [RecordingState.connecting, .recording] {
            vm.state = state
            vm.isBlinking = true
            vm.recordingStartedAt = Date()
            vm.resetAfterRecordingFailure()
            XCTAssertEqual(vm.state, .idle)
            XCTAssertFalse(vm.isBlinking)
            XCTAssertNil(vm.recordingStartedAt)
        }
        vm.cleanup()
    }
}
