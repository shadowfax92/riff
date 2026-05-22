import AppKit
import RiffCore
import SwiftUI

struct NewConversationSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onOpenSettings: () -> Void
    @State private var title = ""
    @State private var prompt = ""
    @State private var maxRounds = 10
    @State private var customFolder: URL?
    @State private var choosingFolder = false
    @State private var roleDrafts: [RoleDraft] = {
        let identity = RoleNameGenerator.generate()
        return [
            RoleDraft(
                id: UUID().uuidString.lowercased(),
                roleName: identity.name,
                rolePrompt: "",
                runtime: .claude,
                emoji: identity.emoji
            )
        ]
    }()

    init(onOpenSettings: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Riff")
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
                            TextField("What should the agents debate?", text: $prompt, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3...8)
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
                            customFolder: customFolder,
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
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.directory]) { result in
            if case .success(let url) = result {
                customFolder = url
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
        HStack(spacing: 10) {
            Button {
                choosingFolder = true
            } label: {
                Label("Choose Folder", systemImage: "folder")
                    .font(.system(size: 12))
            }
            .controlSize(.small)
            if let customFolder {
                Text(customFolder.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button {
                    self.customFolder = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("Default: ~/.riff/conversations/<id>")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
        let runtime: RuntimeID = roleDrafts.last?.runtime == .claude ? .codex : .claude
        let identity = RoleNameGenerator.generate()
        roleDrafts.append(RoleDraft(
            id: UUID().uuidString.lowercased(),
            roleName: identity.name,
            rolePrompt: "",
            runtime: runtime,
            reasoning: runtime == .codex ? "medium" : nil,
            emoji: identity.emoji
        ))
    }

    private func removeRole(_ id: String) {
        guard roleDrafts.count > 1 else { return }
        roleDrafts.removeAll { $0.id == id }
    }
}

private struct RoleEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var role: RoleDraft
    let canDelete: Bool
    let onDelete: () -> Void

    private static let codexReasoningOptions = ["default", "low", "medium", "high"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentAvatar(
                    initials: AgentAvatar.initials(from: role.roleName.isEmpty ? "?" : role.roleName),
                    emoji: role.emoji,
                    color: Theme.color(forSpeakerID: role.id, runtime: role.runtime),
                    size: 28
                )
                TextField("ROLE_NAME", text: $role.roleName)
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
                Picker("", selection: $role.runtime) {
                    ForEach(RuntimeID.allCases) { runtime in
                        Text(runtime.rawValue.capitalized).tag(runtime)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .labelsHidden()
                .onChange(of: role.runtime) { _, newRuntime in
                    role.model = "default"
                    role.reasoning = newRuntime == .codex ? "medium" : nil
                }
                if canDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
                if role.runtime == .codex {
                    fieldWithLabel("Reasoning") {
                        Picker("", selection: reasoningBinding) {
                            ForEach(Self.codexReasoningOptions, id: \.self) { option in
                                Text(option.capitalized).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Role prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Make a sharp case for…", text: $role.rolePrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...6)
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
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
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
            return current.isEmpty ? "default" : current
        } set: { value in
            role.reasoning = value == "default" ? nil : value
        }
    }
}
