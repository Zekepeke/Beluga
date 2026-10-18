import XCTest
@testable import OpenSuperWhisper

final class EscapeRoutingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testEscCancelsWhenSearchIsNotInvolved() {
        XCTAssertTrue(EscapeRouting.shouldCancelRecording(searchFieldFocused: false, searchConsumedAt: nil, now: now))
    }

    func testEscDoesNotCancelWhileSearchFieldIsFocused() {
        XCTAssertFalse(EscapeRouting.shouldCancelRecording(searchFieldFocused: true, searchConsumedAt: nil, now: now))
    }

    func testKeyUpAfterSearchClosedDoesNotCancel() {
        let consumed = now.addingTimeInterval(-0.1)
        XCTAssertFalse(EscapeRouting.shouldCancelRecording(searchFieldFocused: false, searchConsumedAt: consumed, now: now))
    }

    func testLaterEscCancelsAgain() {
        let consumed = now.addingTimeInterval(-EscapeRouting.consumeWindow - 0.1)
        XCTAssertTrue(EscapeRouting.shouldCancelRecording(searchFieldFocused: false, searchConsumedAt: consumed, now: now))
    }
}
