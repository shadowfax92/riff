import AppKit
import Testing
@testable import RiffApp

@Test func markdownClipboardWritesMarkdownAsPlainText() {
    let pasteboard = NSPasteboard.withUniqueName()
    let markdown = "# Artifact\n\nImportant result."

    MarkdownClipboard.copy(markdown, to: pasteboard)

    #expect(pasteboard.string(forType: .string) == markdown)
}
