import RiffCore
import SwiftUI

struct FilePaneView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.Color.separator)
            if model.selectedFile == nil {
                fileListOrEmpty
            } else {
                splitView
            }
        }
        .background(Theme.Color.filesBackground)
        .navigationSplitViewColumnWidth(min: 280, ideal: Theme.Metric.filesWidth, max: 520)
    }

    private var header: some View {
        HStack {
            Text("Artifacts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await model.reloadSelected() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh files")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var fileListOrEmpty: some View {
        if model.files.isEmpty {
            emptyState
        } else {
            fileList
        }
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(model.files) { file in
                    FileCardRow(file: file, isSelected: model.selectedFile?.id == file.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await model.selectFile(file) }
                        }
                }
            }
            .padding(12)
        }
    }

    private var splitView: some View {
        VSplitView {
            fileList
                .frame(minHeight: 100, idealHeight: 160, maxHeight: 240)
            markdownReader
        }
    }

    private var markdownReader: some View {
        VStack(spacing: 0) {
            if let file = model.selectedFile {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.secondary)
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button {
                        model.selectedFile = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close preview")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider().background(Theme.Color.separator)
            }
            ScrollView {
                MarkdownView(markdown: model.selectedMarkdown)
                    .padding(16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No Files")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Agent-written markdown files appear here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FileCardRow: View {
    let file: ConversationFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.Color.sidebarRowSelected : Theme.Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.cardStroke, lineWidth: 1)
        )
    }

    private var subtitle: String {
        if let modified = file.modifiedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Document · \(formatter.localizedString(for: modified, relativeTo: Date()))"
        }
        return "Document · MD"
    }
}
