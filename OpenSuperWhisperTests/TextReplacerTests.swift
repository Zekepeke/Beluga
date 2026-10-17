import XCTest
@testable import OpenSuperWhisper

final class TextReplacerTests: XCTestCase {

    private func rule(_ find: String, _ replace: String, enabled: Bool = true) -> TextReplacement {
        TextReplacement(id: UUID(), find: find, replace: replace, isEnabled: enabled)
    }

    func testApply_matchesCaseInsensitively() {
        let rules = [rule("jay pee morgan", "JPMorgan")]

        XCTAssertEqual(TextReplacer.apply("I work at Jay Pee Morgan", rules: rules), "I work at JPMorgan")
        XCTAssertEqual(TextReplacer.apply("JAY PEE MORGAN rocks", rules: rules), "JPMorgan rocks")
    }

    func testApply_wholeWordOnly() {
        let rules = [rule("cat", "dog")]

        XCTAssertEqual(TextReplacer.apply("category", rules: rules), "category")
        XCTAssertEqual(TextReplacer.apply("concat", rules: rules), "concat")
        XCTAssertEqual(TextReplacer.apply("the cat sat", rules: rules), "the dog sat")
        XCTAssertEqual(TextReplacer.apply("cat.", rules: rules), "dog.")
    }

    func testApply_multiWordPhrase() {
        let rules = [rule("data bricks", "Databricks")]

        XCTAssertEqual(TextReplacer.apply("we use data bricks daily", rules: rules), "we use Databricks daily")
        XCTAssertEqual(TextReplacer.apply("data brickset", rules: rules), "data brickset")
    }

    func testApply_regexSpecialCharactersInFindAreLiteral() {
        let rules = [rule("c++", "C plus plus")]

        XCTAssertEqual(TextReplacer.apply("I like c++ a lot", rules: rules), "I like C plus plus a lot")
        XCTAssertEqual(TextReplacer.apply("I like c a lot", rules: rules), "I like c a lot")
        XCTAssertEqual(TextReplacer.apply("a.b", rules: [rule("a.b", "x")]), "x")
        XCTAssertEqual(TextReplacer.apply("axb", rules: [rule("a.b", "x")]), "axb")
    }

    func testApply_spacesAndHyphensInFindAreInterchangeable() {
        let rules = [rule("t mux", "tmux")]

        XCTAssertEqual(TextReplacer.apply("T-Mux", rules: rules), "tmux")
        XCTAssertEqual(TextReplacer.apply("T Mux", rules: rules), "tmux")
        XCTAssertEqual(TextReplacer.apply("t mux", rules: rules), "tmux")
        XCTAssertEqual(TextReplacer.apply("t - mux", rules: rules), "tmux")
        XCTAssertEqual(TextReplacer.apply("t  mux", rules: rules), "tmux")
        XCTAssertEqual(TextReplacer.apply("tmux", rules: rules), "tmux")
    }

    func testApply_matchFollowedByPunctuationKeepsPunctuation() {
        let rules = [rule("webster", "WezTerm")]

        XCTAssertEqual(TextReplacer.apply("I use Webster.", rules: rules), "I use WezTerm.")
        XCTAssertEqual(TextReplacer.apply("I use Webster, mostly", rules: rules), "I use WezTerm, mostly")
    }

    func testApply_matchAtStartOfText() {
        let rules = [rule("jay pee morgan", "JPMorgan")]

        XCTAssertEqual(TextReplacer.apply("Jay Pee Morgan called", rules: rules), "JPMorgan called")
    }

    func testApply_replacementCasingIsUsedExactly() {
        let rules = [rule("webster", "WezTerm")]

        XCTAssertEqual(TextReplacer.apply("WEBSTER", rules: rules), "WezTerm")
        XCTAssertEqual(TextReplacer.apply("webster", rules: rules), "WezTerm")
    }

    func testApply_replacementIsLiteral() {
        XCTAssertEqual(TextReplacer.apply("price", rules: [rule("price", "$1 \\1")]), "$1 \\1")
    }

    func testApply_escapedNewlineInReplacementBecomesNewline() {
        let rules = [rule("new line", "\\n")]

        XCTAssertEqual(TextReplacer.apply("hello new line world", rules: rules), "hello \n world")
    }

    func testApply_replacesEveryOccurrence() {
        let rules = [rule("tmux", "tmux")]

        XCTAssertEqual(TextReplacer.apply("a b a", rules: [rule("a", "x")]), "x b x")
        XCTAssertEqual(TextReplacer.apply("TMUX and Tmux", rules: rules), "tmux and tmux")
    }

    func testApply_disabledRuleIsSkipped() {
        let rules = [rule("foo", "bar", enabled: false)]

        XCTAssertEqual(TextReplacer.apply("foo", rules: rules), "foo")
    }

    func testApply_emptyFindIsSkipped() {
        XCTAssertEqual(TextReplacer.apply("hello world", rules: [rule("", "X")]), "hello world")
        XCTAssertEqual(TextReplacer.apply("hello world", rules: [rule("   ", "X")]), "hello world")
    }

    func testApply_rulesAppliedInListOrder() {
        let chained = [rule("a", "b"), rule("b", "c")]
        XCTAssertEqual(TextReplacer.apply("a", rules: chained), "c")

        let reversed = [rule("b", "c"), rule("a", "b")]
        XCTAssertEqual(TextReplacer.apply("a", rules: reversed), "b")
    }

    func testApply_emptyTextStaysEmpty() {
        XCTAssertEqual(TextReplacer.apply("", rules: [rule("", "X"), rule("a", "b")]), "")
        XCTAssertEqual(TextReplacer.apply("", rules: [rule("^", "X")]), "")
    }

    func testApply_noRules_returnsInputUnchanged() {
        XCTAssertEqual(TextReplacer.apply("unchanged text", rules: []), "unchanged text")
    }

    func testVocabularyPrompt_joinsBaseAndWords() {
        XCTAssertEqual(
            TextReplacer.vocabularyPrompt(base: "Meeting notes.", words: ["JPMorgan", "Databricks"]),
            "Meeting notes. JPMorgan, Databricks"
        )
    }

    func testVocabularyPrompt_baseWithoutTrailingPunctuationGetsSeparator() {
        XCTAssertEqual(
            TextReplacer.vocabularyPrompt(base: "Meeting notes", words: ["tmux"]),
            "Meeting notes. tmux"
        )
    }

    func testVocabularyPrompt_emptyWordsReturnsTrimmedBase() {
        XCTAssertEqual(TextReplacer.vocabularyPrompt(base: "  Hello.  ", words: []), "Hello.")
        XCTAssertEqual(TextReplacer.vocabularyPrompt(base: "Hello.", words: ["", "   "]), "Hello.")
    }

    func testVocabularyPrompt_emptyBaseReturnsWordsOnly() {
        XCTAssertEqual(TextReplacer.vocabularyPrompt(base: "", words: ["JPMorgan", "tmux"]), "JPMorgan, tmux")
        XCTAssertEqual(TextReplacer.vocabularyPrompt(base: "   ", words: ["tmux"]), "tmux")
    }

    func testVocabularyPrompt_bothEmptyReturnsEmpty() {
        XCTAssertEqual(TextReplacer.vocabularyPrompt(base: "", words: []), "")
    }

    func testVocabularyPrompt_skipsEmptyAndTrimsWords() {
        XCTAssertEqual(
            TextReplacer.vocabularyPrompt(base: "", words: [" JPMorgan ", "", "tmux"]),
            "JPMorgan, tmux"
        )
    }
}

final class TextReplacementPreferencesTests: XCTestCase {

    private let wordsKey = "vocabularyWords"
    private let rulesKey = "textReplacements"
    private var originalWords: Any?
    private var originalRules: Any?

    override func setUp() {
        super.setUp()
        originalWords = UserDefaults.standard.object(forKey: wordsKey)
        originalRules = UserDefaults.standard.object(forKey: rulesKey)
        UserDefaults.standard.removeObject(forKey: wordsKey)
        UserDefaults.standard.removeObject(forKey: rulesKey)
    }

    override func tearDown() {
        for (key, value) in [(wordsKey, originalWords), (rulesKey, originalRules)] {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testVocabulary_defaultsToEmpty() {
        XCTAssertEqual(AppPreferences.shared.vocabularyWords, [])
        XCTAssertEqual(AppPreferences.shared.textReplacements, [])
    }

    func testVocabularyWords_persistChanges() {
        AppPreferences.shared.vocabularyWords = ["JPMorgan", "tmux"]
        XCTAssertEqual(AppPreferences.shared.vocabularyWords, ["JPMorgan", "tmux"])
    }

    func testTextReplacements_persistChanges() {
        let rules = [
            TextReplacement(id: UUID(), find: "jay pee morgan", replace: "JPMorgan", isEnabled: true),
            TextReplacement(id: UUID(), find: "new line", replace: "\\n", isEnabled: false),
        ]
        AppPreferences.shared.textReplacements = rules
        XCTAssertEqual(AppPreferences.shared.textReplacements, rules)
    }

    func testSettingsSnapshot_includesReplacementsAndVocabularyPrompt() {
        let originalPrompt = AppPreferences.shared.initialPrompt
        defer { AppPreferences.shared.initialPrompt = originalPrompt }

        AppPreferences.shared.initialPrompt = "Notes."
        AppPreferences.shared.vocabularyWords = ["JPMorgan"]
        let rule = TextReplacement(id: UUID(), find: "jay pee morgan", replace: "JPMorgan", isEnabled: true)
        AppPreferences.shared.textReplacements = [rule]

        let settings = Settings()

        XCTAssertEqual(settings.initialPrompt, "Notes. JPMorgan")
        XCTAssertEqual(settings.textReplacements, [rule])
    }
}
