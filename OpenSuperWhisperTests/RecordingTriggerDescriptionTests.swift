import XCTest
@testable import OpenSuperWhisper

final class RecordingTriggerDescriptionTests: XCTestCase {
    func testKeyCombination() {
        XCTAssertEqual(RecordingTriggerDescription.describe(mouseButton: .none, modifierKey: .none, keyCombination: "⌥`"), "⌥`")
    }

    func testSingleModifierKey() {
        XCTAssertEqual(RecordingTriggerDescription.describe(mouseButton: .none, modifierKey: .leftCommand, keyCombination: "⌥`"), "⌘")
        XCTAssertEqual(RecordingTriggerDescription.describe(mouseButton: .none, modifierKey: .rightOption, keyCombination: nil), "⌥")
    }

    func testMouseButton() {
        XCTAssertEqual(RecordingTriggerDescription.describe(mouseButton: .button4, modifierKey: .none, keyCombination: "⌥`"), "🖱4")
    }

    func testMouseButtonWinsOverModifierAndCombination() {
        XCTAssertEqual(RecordingTriggerDescription.describe(mouseButton: .middle, modifierKey: .fn, keyCombination: "⌥`"), "🖱3")
    }

    func testModifierWinsOverCombination() {
        XCTAssertEqual(RecordingTriggerDescription.describe(mouseButton: .none, modifierKey: .leftControl, keyCombination: "⌥`"), "⌃")
    }

    func testNoTrigger() {
        XCTAssertEqual(RecordingTriggerDescription.describe(mouseButton: .none, modifierKey: .none, keyCombination: nil), "")
    }
}
