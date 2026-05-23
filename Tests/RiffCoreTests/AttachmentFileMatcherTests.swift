import Testing
@testable import RiffCore

@Test func attachmentFileMatcherFindsRelativePathMatch() {
    let file = ConversationFile(relativePath: "files/turn-001.dolphin.claude.md", name: "turn-001.dolphin.claude.md")
    let attachment = TranscriptAttachment(path: "files/turn-001.dolphin.claude.md")

    #expect(AttachmentFileMatcher.match(attachment: attachment, files: [file]) == file)
}

@Test func attachmentFileMatcherFindsFilenameMatch() {
    let file = ConversationFile(relativePath: "files/turn-001.dolphin.claude.md", name: "turn-001.dolphin.claude.md")
    let attachment = TranscriptAttachment(path: "turn-001.dolphin.claude.md")

    #expect(AttachmentFileMatcher.match(attachment: attachment, files: [file]) == file)
}
