import Foundation

enum CleanupSanitizer {

    /// Strips the wrappers models add around their answer. Returns `nil` when
    /// the output is unusable and the caller should fall back to `raw`.
    static func sanitize(output: String, raw: String) -> String? {
        var text = output

        text = replacing(#"<think>.*?</think>"#, in: text, options: [.caseInsensitive, .dotMatchesLineSeparators])
        text = replacing(#"</?transcript>"#, in: text, options: [.caseInsensitive])
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !raw.contains("```") {
            text = unwrapCodeFence(text)
        }

        // The words after "Here is" must mention "clean" so that dictated
        // text that happens to start with "Here is the plan:" survives.
        text = replacing(
            #"^\s*(?:here(?:'s|’s| is)[^\n:]*\bclean[^\n:]*|cleaned(?:[- ]up)?(?: text| version)?)\s*:\s*"#,
            in: text,
            options: [.caseInsensitive]
        )

        if !isQuoted(raw) {
            text = unwrapQuotes(text)
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty || text.count > raw.count * 2 + 100 { return nil }
        return text
    }

    private static func replacing(_ pattern: String, in text: String, options: NSRegularExpression.Options) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    private static func unwrapCodeFence(_ text: String) -> String {
        guard text.hasPrefix("```"), text.hasSuffix("```"),
              text.components(separatedBy: "```").count == 3 else { return text }
        var inner = String(text.dropFirst(3).dropLast(3))
        // Drop an optional language tag on the opening fence line.
        if let newline = inner.firstIndex(of: "\n") {
            let tag = inner[inner.startIndex..<newline]
            if !tag.contains(" ") { inner = String(inner[inner.index(after: newline)...]) }
        }
        return inner.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let quotePairs: [(open: Character, close: Character)] = [("\"", "\""), ("\u{201C}", "\u{201D}")]

    private static func isQuoted(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, let last = trimmed.last, trimmed.count >= 2 else { return false }
        return quotePairs.contains { $0.open == first && $0.close == last }
    }

    /// Only unwraps one pair that encloses the whole text, never `"Hi," she said, "bye."`.
    private static func unwrapQuotes(_ text: String) -> String {
        guard let first = text.first, let last = text.last, text.count >= 2,
              let pair = quotePairs.first(where: { $0.open == first && $0.close == last }) else { return text }
        let inner = String(text.dropFirst().dropLast())
        if inner.contains(pair.open) || inner.contains(pair.close) { return text }
        return inner
    }
}
