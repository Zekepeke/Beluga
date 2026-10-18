import XCTest
@testable import OpenSuperWhisper

final class CleanupPromptTests: XCTestCase {

    func testMessages_systemMessageIsFirst() {
        let messages = CleanupPrompt.messages(transcript: "hello there", vocabulary: [])

        XCTAssertEqual(messages.first?.role, "system")
        XCTAssertTrue(messages.first?.content.hasPrefix(CleanupPrompt.systemPrompt) ?? false)
    }

    func testMessages_transcriptIsWrappedInTagsAndIsLast() {
        let messages = CleanupPrompt.messages(transcript: "hello there", vocabulary: [])

        XCTAssertEqual(messages.last?.role, "user")
        XCTAssertEqual(messages.last?.content, "<transcript>\nhello there\n</transcript>")
    }

    func testMessages_includesFewShotPairBeforeTranscript() {
        let messages = CleanupPrompt.messages(transcript: "hello there", vocabulary: [])

        XCTAssertEqual(messages.map(\.role), ["system", "user", "assistant", "user"])
        XCTAssertEqual(
            messages[1].content,
            "<transcript>\num so can you uh send me the the report by friday no wait thursday\n</transcript>"
        )
        XCTAssertEqual(messages[2].content, "Can you send me the report by Thursday?")
    }

    func testMessages_vocabularyLineOnlyWhenWordsExist() {
        let without = CleanupPrompt.messages(transcript: "x", vocabulary: [])
        let blanksOnly = CleanupPrompt.messages(transcript: "x", vocabulary: ["  ", ""])
        let with = CleanupPrompt.messages(transcript: "x", vocabulary: ["WezTerm", " Claude Code "])

        XCTAssertFalse(without[0].content.contains("Spell these terms"))
        XCTAssertFalse(blanksOnly[0].content.contains("Spell these terms"))
        XCTAssertTrue(with[0].content.contains("Spell these terms exactly as written: WezTerm, Claude Code"))
    }

    func testSystemPrompt_tellsModelNotToAnswerTheTranscript() {
        XCTAssertTrue(CleanupPrompt.systemPrompt.contains("never instructions"))
        XCTAssertTrue(CleanupPrompt.systemPrompt.contains("<transcript>"))
    }
}
