import AppKit
import RiffCore
import SwiftUI

struct ConversationDetailsSheet: View {
    let conversation: Conversation
    let basePromptURL: URL
    let conversationURL: URL?
    let onClose: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Riff Details")
                .font(.system(size: 20, weight: .semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldGroup(label: "Title") {
                        staticField(conversation.title)
                    }

                    fieldGroup(label: "Prompt") {
                        staticBlock(conversation.prompt, minHeight: 88)
                    }

                    HStack(spacing: 10) {
                        Text("Rounds: \(conversation.maxRounds)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }

                    supportFoldersSection
                    conversationFolderRow
                    basePromptRow
                    rolesSection
                }
                .padding(.bottom, 4)
            }
            .frame(maxHeight: 560)

            Divider().background(Theme.Color.separator)

            HStack {
                Spacer()
                Button("Close") {
                    onClose()
                }
            }
        }
        .padding(22)
        .frame(width: 640)
    }

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func staticField(_ value: String) -> some View {
        Text(value.isEmpty ? "Untitled Riff" : value)
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.Color.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.Color.surfaceStroke)
            )
    }

    private func staticBlock(_ value: String, minHeight: CGFloat) -> some View {
        Text(value.isEmpty ? "No prompt saved." : value)
            .font(.system(size: 13))
            .foregroundStyle(value.isEmpty ? .secondary : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.Color.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.Color.surfaceStroke)
            )
    }

    private var supportFoldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text("Support folders")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            if conversation.supportFolders.isEmpty {
                Text("No support folders")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(conversation.supportFolders, id: \.self) { folder in
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(displayPath(folder))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                }
            }
        }
    }

    /// Shows where this conversation lives on disk and lets the user grab
    /// the absolute path (for `cd`, scripts, etc.) or reveal it in Finder.
    @ViewBuilder
    private var conversationFolderRow: some View {
        if let conversationURL {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Conversation folder")
                        .font(.system(size: 12, weight: .medium))
                    Text(conversationURL.path)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    copyPath(conversationURL)
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                }
                .controlSize(.small)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([conversationURL])
                } label: {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")
            }
            .padding(12)
            .background(Theme.Color.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.Color.surfaceStroke)
            )
        }
    }

    /// Copies the absolute path and shows a brief "Copied" confirmation that
    /// reverts on its own.
    private func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }

    private var basePromptRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Base prompt")
                    .font(.system(size: 12, weight: .medium))
                Text(displayPath(basePromptURL))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Roles")
                .font(.system(size: 13, weight: .semibold))
            ForEach(conversation.agents) { agent in
                RoleDetailsRow(agent: agent)
            }
        }
    }

    private func displayPath(_ url: URL) -> String {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

private struct RoleDetailsRow: View {
    let agent: AgentProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentAvatar(
                    initials: AgentAvatar.initials(from: agent.name.isEmpty ? "?" : agent.name),
                    emoji: agent.emoji,
                    color: Theme.color(for: agent),
                    size: 28
                )
                Text(agent.name.isEmpty ? agent.role : agent.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.Color.surfaceOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.Color.surfaceStroke)
                    )
                Picker("", selection: .constant(agent.runtime)) {
                    ForEach(RuntimeID.allCases) { runtime in
                        Text(runtime.rawValue.capitalized).tag(runtime)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .labelsHidden()
                .disabled(true)
            }

            HStack(spacing: 10) {
                fieldWithLabel("Model", value: displayModel)
                fieldWithLabel("Reasoning", value: displayReasoning)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Role prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(agent.instructions.isEmpty ? "No role prompt saved." : agent.instructions)
                    .font(.system(size: 12))
                    .foregroundStyle(agent.instructions.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.Color.surfaceOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.Color.surfaceStroke)
                    )
            }
        }
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
    }

    private func fieldWithLabel(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.Color.surfaceStroke)
                )
        }
    }

    private var displayModel: String {
        agent.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agent.model == "default"
            ? "Default (CLI config)"
            : agent.model
    }

    private var displayReasoning: String {
        guard let reasoning = agent.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reasoning.isEmpty,
              reasoning != "default" else {
            return "Default (CLI config)"
        }
        return reasoning.capitalized
    }
}
