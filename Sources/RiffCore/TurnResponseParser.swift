import Foundation

public struct ParsedTurnResponse: Equatable, Sendable {
    public var text: String
    public var attachments: [TranscriptAttachment]
    public var wordCount: Int
    public var warning: String?

    public init(text: String, attachments: [TranscriptAttachment], wordCount: Int, warning: String? = nil) {
        self.text = text
        self.attachments = attachments
        self.wordCount = wordCount
        self.warning = warning
    }
}

public enum TurnResponseParser {
    public static let targetWordCount = 280

    /// Reads a model's chat response without rewriting it, recording markdown
    /// attachment paths the agent says it wrote.
    public static func parse(_ response: String) -> ParsedTurnResponse {
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = attachmentPaths(in: text).map(TranscriptAttachment.init(path:))
        let count = wordCount(text)
        let warning = count > targetWordCount
            ? "Argument is \(count) words; prompt target is roughly \(targetWordCount)."
            : nil
        return ParsedTurnResponse(text: text, attachments: attachments, wordCount: count, warning: warning)
    }

    public static func attachmentPaths(in text: String) -> [String] {
        let pattern = #"files/[A-Za-z0-9._@%+\-/]+\.md"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        var output: [String] = []
        for match in regex.matches(in: text, range: range) {
            guard let matchRange = Range(match.range, in: text) else {
                continue
            }
            let path = String(text[matchRange])
            if seen.insert(path).inserted {
                output.append(path)
            }
        }
        return output
    }

    public static func wordCount(_ text: String) -> Int {
        text
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .filter { !$0.isEmpty }
            .count
    }
}
