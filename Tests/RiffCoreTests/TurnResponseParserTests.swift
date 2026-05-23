import Testing
@testable import RiffCore

@Test func plainTextHasNoAttachments() {
    let parsed = TurnResponseParser.parse("This is my concise argument.")

    #expect(parsed.text == "This is my concise argument.")
    #expect(parsed.attachments.isEmpty)
    #expect(parsed.warning == nil)
}

@Test func pathMentionsBecomeAttachmentsWithoutChangingText() {
    let response = "I wrote the supporting memo at `files/turn-003.critic.codex.md`."

    let parsed = TurnResponseParser.parse(response)

    #expect(parsed.text == response)
    #expect(parsed.attachments == [TranscriptAttachment(path: "files/turn-003.critic.codex.md")])
}

@Test func parserFindsMultipleAttachmentMentionStyles() {
    let response = """
    Attachment: files/turn-001.advocate.claude.md
    See [critic notes](files/turn-002.critic.codex.md).
    """

    let parsed = TurnResponseParser.parse(response)

    #expect(parsed.attachments.map(\.path) == [
        "files/turn-001.advocate.claude.md",
        "files/turn-002.critic.codex.md",
    ])
}

@Test func wordCountIsRecordedWithoutWarning() {
    let response = Array(repeating: "word", count: 281).joined(separator: " ")

    let parsed = TurnResponseParser.parse(response)

    #expect(parsed.wordCount == 281)
    #expect(parsed.warning == nil)
    #expect(parsed.text == response)
}
