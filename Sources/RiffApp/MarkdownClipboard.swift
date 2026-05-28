import AppKit

enum MarkdownClipboard {
    static func copy(_ markdown: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }
}
