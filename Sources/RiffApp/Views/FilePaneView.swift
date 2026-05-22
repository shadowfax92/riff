import SwiftUI

struct FilePaneView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.files.isEmpty {
                ContentUnavailableView("No Files", systemImage: "doc.text", description: Text("Agent-written markdown files appear here."))
            } else {
                List(model.files, selection: Binding(
                    get: { model.selectedFile?.id },
                    set: { id in
                        guard let file = model.files.first(where: { $0.id == id }) else { return }
                        Task {
                            await model.selectFile(file)
                        }
                    }
                )) { file in
                    Label(file.name, systemImage: "doc.text")
                        .font(.system(size: 12))
                        .tag(file.id)
                }
                .frame(minHeight: 150, maxHeight: 220)
                Divider()
                MarkdownTextView(markdown: model.selectedMarkdown)
            }
        }
        .navigationSplitViewColumnWidth(min: 320, ideal: 400)
    }

    private var header: some View {
        HStack {
            Text("Files")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button {
                Task {
                    await model.reloadSelected()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh files")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            Text(attributedMarkdown)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }

    private var attributedMarkdown: AttributedString {
        (try? AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}
