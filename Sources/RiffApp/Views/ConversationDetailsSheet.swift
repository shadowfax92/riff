import AppKit
import RiffCore
import SwiftUI

struct ConversationDetailsSheet: View {
    @EnvironmentObject private var model: AppModel
    let conversation: Conversation
    let basePromptURL: URL
    let conversationURL: URL?
    let onClose: () -> Void
    @State private var copied = false
    @State private var isContinuing = false
    @State private var roleDrafts: [RoleDraft]

    init(conversation: Conversation, basePromptURL: URL, conversationURL: URL?, onClose: @escaping () -> Void) {
        self.conversation = conversation
        self.basePromptURL = basePromptURL
        self.conversationURL = conversationURL
        self.onClose = onClose
        _roleDrafts = State(initialValue: conversation.agents.map { RoleDraft(agent: $0) })
    }

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
                    if let runtimeSettingsMessage {
                        runtimeSettingsPrompt(message: runtimeSettingsMessage)
                    }
                    rolesSection
                }
                .padding(.bottom, 4)
            }
            .frame(maxHeight: 560)

            Divider().background(Theme.Color.separator)

            HStack {
                Spacer()
                Button {
                    Task {
                        isContinuing = true
                        let didContinue = await model.continueSelectedConversation(roleDrafts: roleDrafts)
                        isContinuing = false
                        if didContinue {
                            onClose()
                        }
                    }
                } label: {
                    Label(isContinuing ? "Continuing" : "Continue", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
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

    private func runtimeSettingsPrompt(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Text("Open Settings and set the missing executable path, then refresh runtimes.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
            ForEach($roleDrafts) { $role in
                RoleDetailsRow(role: $role, editable: !isConversationRunning)
            }
        }
    }

    private var canContinue: Bool {
        !isContinuing
            && !isConversationRunning
            && !roleDrafts.isEmpty
            && runtimeSettingsMessage == nil
    }

    private var isConversationRunning: Bool {
        model.isConversationRunning(conversation.id)
    }

    private var runtimeSettingsMessage: String? {
        let agents = roleDrafts
            .enumerated()
            .map { offset, draft in draft.agentProfile(index: offset + 1) }
        return RuntimeRequirement.settingsMessage(
            for: RuntimeRequirement.missingRuntimes(
                agents: agents,
                detectedRuntimes: model.detectedRuntimes
            ),
            action: "continuing this Riff"
        )
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
    @EnvironmentObject private var model: AppModel
    @Binding var role: RoleDraft
    let editable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentAvatar(
                    initials: AgentAvatar.initials(from: role.agentName.isEmpty ? "?" : role.agentName),
                    emoji: role.emoji,
                    color: Theme.color(forSpeakerID: role.id, runtime: role.runtime),
                    size: 28
                )
                Text(role.agentName.isEmpty ? "Unnamed Agent" : role.agentName)
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
                runtimePicker
            }

            HStack(spacing: 10) {
                fieldWithLabel("Model") {
                    Picker("", selection: modelBinding) {
                        ForEach(modelOptions, id: \.id) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(!editable)
                }
                fieldWithLabel("Reasoning") {
                    Picker("", selection: reasoningBinding) {
                        ForEach(reasoningOptions, id: \.id) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(!editable)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Role prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(role.rolePrompt.isEmpty ? "No role prompt saved." : role.rolePrompt)
                    .font(.system(size: 12))
                    .foregroundStyle(role.rolePrompt.isEmpty ? .secondary : .primary)
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

    private var runtimePicker: some View {
        Picker("", selection: $role.runtime) {
            ForEach(RuntimeID.allCases) { runtime in
                Text(runtime.rawValue.capitalized).tag(runtime)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
        .labelsHidden()
        .disabled(!editable)
        .onChange(of: role.runtime) { _, newRuntime in
            role.model = "default"
            if let reasoning = role.reasoning,
               !reasoningOptions(for: newRuntime).contains(where: { $0.id == reasoning }) {
                role.reasoning = nil
            }
        }
    }

    private func fieldWithLabel<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            content()
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.Color.surfaceStroke)
                )
        }
    }

    private var modelOptions: [RuntimeModelOption] {
        var options = if let detected = model.detectedRuntimes[role.runtime]?.models, !detected.isEmpty {
            detected
        } else {
            RuntimeDefinitions.definition(for: role.runtime).fallbackModels
        }
        let current = role.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty,
           current != "default",
           !options.contains(where: { $0.id == current }) {
            options.append(RuntimeModelOption(id: current, label: current))
        }
        return options
    }

    private var modelBinding: Binding<String> {
        Binding {
            let current = role.model.trimmingCharacters(in: .whitespacesAndNewlines)
            return current.isEmpty ? "default" : current
        } set: { value in
            role.model = value
        }
    }

    private var reasoningOptions: [RuntimeReasoningOption] {
        var options = reasoningOptions(for: role.runtime)
        if let current = role.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
           !current.isEmpty,
           current != "default",
           !options.contains(where: { $0.id == current }) {
            options.append(RuntimeReasoningOption(id: current, label: current.capitalized))
        }
        return options
    }

    private var reasoningBinding: Binding<String> {
        Binding {
            let current = role.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return current.isEmpty ? "default" : current
        } set: { value in
            role.reasoning = value == "default" ? nil : value
        }
    }

    private func reasoningOptions(for runtime: RuntimeID) -> [RuntimeReasoningOption] {
        RuntimeDefinitions.reasoningOptions(for: runtime)
    }
}
