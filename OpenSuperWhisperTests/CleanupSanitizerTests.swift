import XCTest
@testable import OpenSuperWhisper

final class CleanupSanitizerTests: XCTestCase {

    private func sanitize(_ output: String, raw: String = "um so the meeting is on wednesday") -> String? {
        CleanupSanitizer.sanitize(output: output, raw: raw)
    }

    func testSanitize_passesNormalTextThrough() {
        XCTAssertEqual(sanitize("The meeting is on Wednesday."), "The meeting is on Wednesday.")
    }

    func testSanitize_stripsThinkBlocks() {
        XCTAssertEqual(sanitize("<think>The user wants...</think>\nThe meeting is on Wednesday."), "The meeting is on Wednesday.")
        XCTAssertEqual(sanitize("<THINK>line one\nline two</THINK>Done."), "Done.")
    }

    func testSanitize_unwrapsSurroundingCodeFence() {
        XCTAssertEqual(sanitize("```\nThe meeting is on Wednesday.\n```"), "The meeting is on Wednesday.")
        XCTAssertEqual(sanitize("```text\nThe meeting is on Wednesday.\n```"), "The meeting is on Wednesday.")
    }

    func testSanitize_keepsCodeFenceWhenRawLookedLikeCode() {
        let raw = "```\nlet x = 1\n```"
        XCTAssertEqual(sanitize("```\nlet x = 1\n```", raw: raw), "```\nlet x = 1\n```")
    }

    func testSanitize_dropsPreambleLine() {
        XCTAssertEqual(sanitize("Here is the cleaned text:\nThe meeting is on Wednesday."), "The meeting is on Wednesday.")
        XCTAssertEqual(sanitize("Here's the cleaned-up version:\n\nThe meeting is on Wednesday."), "The meeting is on Wednesday.")
        XCTAssertEqual(sanitize("Cleaned text: The meeting is on Wednesday."), "The meeting is on Wednesday.")
    }

    func testSanitize_unwrapsSurroundingQuotes() {
        XCTAssertEqual(sanitize("\"The meeting is on Wednesday.\""), "The meeting is on Wednesday.")
        XCTAssertEqual(sanitize("\u{201C}The meeting is on Wednesday.\u{201D}"), "The meeting is on Wednesday.")
    }

    func testSanitize_keepsQuotesWhenRawWasQuoted() {
        let raw = "\"the meeting is on wednesday\""
        XCTAssertEqual(sanitize("\"The meeting is on Wednesday.\"", raw: raw), "\"The meeting is on Wednesday.\"")
    }

    func testSanitize_keepsInnerQuotes() {
        XCTAssertEqual(sanitize("She said \"hi\" to me."), "She said \"hi\" to me.")
    }

    func testSanitize_stripsEchoedTranscriptTags() {
        XCTAssertEqual(sanitize("<transcript>\nThe meeting is on Wednesday.\n</transcript>"), "The meeting is on Wednesday.")
    }

    func testSanitize_emptyResultIsNil() {
        XCTAssertNil(sanitize(""))
        XCTAssertNil(sanitize("   \n  "))
        XCTAssertNil(sanitize("<think>only thoughts</think>"))
    }

    func testSanitize_runawayLengthIsNil() {
        let raw = "what time is it"
        let answer = String(repeating: "It is a long answer. ", count: 20)

        XCTAssertGreaterThan(answer.count, raw.count * 2 + 100)
        XCTAssertNil(sanitize(answer, raw: raw))
    }

    func testSanitize_outputAtLengthLimitIsKept() {
        let raw = "abc"
        let output = String(repeating: "a", count: raw.count * 2 + 100)

        XCTAssertEqual(sanitize(output, raw: raw), output)
    }

    func testSanitize_trimsWhitespace() {
        XCTAssertEqual(sanitize("  \n The meeting is on Wednesday. \n\n"), "The meeting is on Wednesday.")
    }
}
