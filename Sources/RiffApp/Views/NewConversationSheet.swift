import AppKit
import RiffCore
import SwiftUI

struct NewConversationSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private let seed: Conversation?
    let onOpenSettings: () -> Void
    @State private var title: String
    @State private var prompt: String
    @State private var maxRounds: Int
    @State private var supportFolders: [URL]
    @State private var choosingSupportFolder = false
    @State private var roleDrafts: [RoleDraft]

    /// When `seed` is non-nil the sheet acts as a fork: every field is
    /// pre-filled from the source conversation so the user can tweak the
    /// setup and launch a fresh debate. The title gets a "(fork)" suffix so
    /// it stays distinct in the sidebar.
    init(seed: Conversation? = nil, onOpenSettings: @escaping () -> Void = {}) {
        self.seed = seed
        self.onOpenSettings = onOpenSettings
        _title = State(initialValue: seed.map { "\($0.title) (fork)" } ?? "")
        _prompt = State(initialValue: seed?.prompt ?? "")
        _maxRounds = State(initialValue: seed?.maxRounds ?? 10)
        _supportFolders = State(initialValue: seed?.supportFolders ?? [])
        _roleDrafts = State(initialValue: Self.seededRoleDrafts(from: seed))
    }

    private static func seededRoleDrafts(from seed: Conversation?) -> [RoleDraft] {
        guard let seed, !seed.agents.isEmpty else {
            return [RoleDraftFactory.initial()]
        }
        return seed.agents.map { RoleDraft(agent: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(seed == nil ? "New Riff" : "Fork Riff")
                .font(.system(size: 20, weight: .semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldGroup(label: "Title") {
                        styledField {
                            TextField("Architecture debate", text: $title)
                                .textFieldStyle(.plain)
                        }
                    }

                    fieldGroup(label: "Prompt") {
                        styledField {
                            MultilineTextField(
                                placeholder: "What should the agents debate?",
                                text: $prompt,
                                minHeight: 72,
                                maxHeight: 220
                            )
                        }
                    }

                    HStack(spacing: 14) {
                        Stepper("Rounds: \(maxRounds)", value: $maxRounds, in: 1...12)
                            .controlSize(.small)
                        Spacer()
                    }

                    folderRow

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
                Button("Cancel") { dismiss() }
                Button("Create") {
                    Task {
                        let created = await model.createConversation(
                            title: trimmedTitle,
                            prompt: prompt,
                            maxRounds: maxRounds,
                            supportFolders: supportFolders,
                            roleDrafts: roleDrafts
                        )
                        if created {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
        }
        .padding(22)
        .frame(width: 640)
        .fileImporter(isPresented: $choosingSupportFolder, allowedContentTypes: [.directory]) { result in
            if case .success(let url) = result {
                addSupportFolder(url)
            }
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
            Button {
                dismiss()
                onOpenSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 12))
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
    }

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func styledField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.Color.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.Color.surfaceStroke)
            )
    }

    private var folderRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    choosingSupportFolder = true
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                        .font(.system(size: 12))
                }
                .controlSize(.small)
                Text("Agents can read these folders; Riff stores the chat under ~/.riff/conversations/<id>.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            ForEach(supportFolders, id: \.self) { folder in
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(folder.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        removeSupportFolder(folder)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var basePromptRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Base prompt")
                        .font(.system(size: 12, weight: .medium))
                    Text(displayPath(model.basePromptURL))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button {
                    NSWorkspace.shared.open(model.basePromptURL)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .controlSize(.small)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([model.basePromptURL])
                } label: {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")
                Button {
                    model.reloadBasePrompt()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Reload from disk")
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

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Roles")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    addRole()
                } label: {
                    Label("Add Role", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .controlSize(.small)
            }
            ForEach($roleDrafts) { $role in
                RoleEditor(
                    role: $role,
                    canDelete: roleDrafts.count > 1,
                    onDelete: { removeRole(role.id) }
                )
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

    private var canCreate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && roleDrafts.contains(where: \.isValid)
            && runtimeSettingsMessage == nil
    }

    private var runtimeSettingsMessage: String? {
        model.runtimeSettingsPrompt(for: roleDrafts)
    }

    private var trimmedTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled Riff" : cleaned
    }

    private func addRole() {
        roleDrafts.append(RoleDraftFactory.additional(after: roleDrafts.last))
    }

    private func removeRole(_ id: String) {
        guard roleDrafts.count > 1 else { return }
        roleDrafts.removeAll { $0.id == id }
    }

    private func addSupportFolder(_ folder: URL) {
        let standardized = folder.standardizedFileURL
        guard !supportFolders.contains(standardized) else {
            return
        }
        supportFolders.append(standardized)
    }

    private func removeSupportFolder(_ folder: URL) {
        supportFolders.removeAll { $0 == folder }
    }
}

private struct RoleEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var role: RoleDraft
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                AgentAvatar(
                    initials: AgentAvatar.initials(from: role.agentName.isEmpty ? "?" : role.agentName),
                    emoji: role.emoji,
                    color: Theme.color(forSpeakerID: role.id, runtime: role.runtime),
                    size: 28
                )
                agentNameField
                runtimePicker
                if canDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 7)
                }
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
                }
                fieldWithLabel("Reasoning") {
                    Picker("", selection: reasoningBinding) {
                        ForEach(reasoningOptions, id: \.id) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Role prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                MultilineTextField(
                    placeholder: "Make a sharp case for…",
                    text: $role.rolePrompt,
                    minHeight: 52,
                    maxHeight: 140
                )
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

    private var agentNameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Agent name")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Agent name", text: $role.agentName)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.Color.surfaceStroke)
                )
        }
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
        .padding(.bottom, 1)
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

    /// Prefers live-detected models for this runtime, falls back to the
    /// hard-coded list in RuntimeDefinitions when detection failed.
    private var modelOptions: [RuntimeModelOption] {
        if let detected = model.detectedRuntimes[role.runtime]?.models, !detected.isEmpty {
            return detected
        }
        return RuntimeDefinitions.definition(for: role.runtime).fallbackModels
    }

    private var modelBinding: Binding<String> {
        Binding {
            let current = role.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if current.isEmpty { return "default" }
            return modelOptions.contains(where: { $0.id == current }) ? current : "default"
        } set: { value in
            role.model = value
        }
    }

    private var reasoningBinding: Binding<String> {
        Binding {
            let current = role.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if current.isEmpty { return "default" }
            return reasoningOptions.contains(where: { $0.id == current }) ? current : "default"
        } set: { value in
            role.reasoning = value == "default" ? nil : value
        }
    }

    private var reasoningOptions: [RuntimeReasoningOption] {
        reasoningOptions(for: role.runtime)
    }

    private func reasoningOptions(for runtime: RuntimeID) -> [RuntimeReasoningOption] {
        RuntimeDefinitions.reasoningOptions(for: runtime)
    }
}
