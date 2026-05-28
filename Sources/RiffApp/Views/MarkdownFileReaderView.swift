import MarkdownUI
import RiffCore
import SwiftUI

struct MarkdownFileReaderView: View {
    let file: ConversationFile
    let markdown: String
    let mode: Mode
    let onDock: (() -> Void)?
    let onClose: () -> Void
    @State private var copied = false

    enum Mode {
        case sidebar
        case popup
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.Color.separator)
            ScrollView {
                Markdown(markdown)
                    .markdownTheme(.gitHub)
                    .textSelection(.enabled)
                    .padding(16)
            }
        }
        .background(Theme.Color.filesBackground)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(.secondary)
            Text(file.name)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Button {
                MarkdownClipboard.copy(markdown)
                showCopied()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(copied ? "Copied" : "Copy Markdown")
            if let onDock {
                Button(action: onDock) {
                    Image(systemName: mode == .sidebar ? "arrow.up.right.square" : "sidebar.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(mode == .sidebar ? "Open files in popup" : "Show files in sidebar")
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close preview")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func showCopied() {
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
