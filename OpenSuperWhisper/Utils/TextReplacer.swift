import Foundation

enum TextReplacer {

    /// Applies enabled rules in list order. Matching is case-insensitive and
    /// whole-word/phrase. Runs of spaces or hyphens in `find` match each other.
    /// The replacement is inserted exactly as written; a typed `\n` becomes a newline.
    static func apply(_ text: String, rules: [TextReplacement]) -> String {
        guard !text.isEmpty else { return text }

        var result = text
        for rule in rules where rule.isEnabled {
            guard let regex = regex(for: rule.find) else { continue }
            let replacement = rule.replace.replacingOccurrences(of: "\\n", with: "\n")
            let template = NSRegularExpression.escapedTemplate(for: replacement)
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: template
            )
        }
        return result
    }

    /// Joins the user's initial prompt and vocabulary words into one prompt.
    static func vocabularyPrompt(base: String, words: [String]) -> String {
        let base = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        if list.isEmpty { return base }
        if base.isEmpty { return list }

        let endsWithPunctuation = base.last.map { ".!?:;,".contains($0) } ?? false
        return base + (endsWithPunctuation ? " " : ". ") + list
    }

    private static func regex(for find: String) -> NSRegularExpression? {
        let tokens = find
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard !tokens.isEmpty else { return nil }

        let word = #"[\p{L}\p{N}_]"#
        let pattern = "(?<!\(word))" + tokens.joined(separator: "[ \\-]+") + "(?!\(word))"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
