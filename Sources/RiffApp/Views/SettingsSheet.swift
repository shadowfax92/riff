import AppKit
import MarkdownUI
import RiffCore
import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var basePrompt = ""
    @State private var summaryPrompt = ""
    @State private var summaryAgent = ConfigStore.defaultSummaryAgent
    @State private var claudePath = ""
    @State private var codexPath = ""
    @State private var isSaving = false

    private static let codexReasoningOptions = ["default", "low", "medium", "high"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    basePromptSection
                    summaryAgentSection
                    summaryPromptSection
                    agentPathsSection
                    runtimesSection
                }
                .padding(.bottom, 2)
            }
            .frame(maxHeight: 760)

            Divider().background(Theme.Color.separator)

            HStack {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([model.runtimeSettingsURL])
                } label: {
                    Label("Config", systemImage: "folder")
                        .font(.system(size: 12))
                }
                .controlSize(.small)

                Spacer()

                Button("Cancel") { dismiss() }
                Button("Save") {
                    isSaving = true
                    Task {
                        await model.saveSettings(
                            claudePath: claudePath,
                            codexPath: codexPath,
                            basePrompt: basePrompt,
                            summaryPrompt: summaryPrompt,
                            summaryAgent: normalizedSummaryAgent
                        )
                        await MainActor.run {
                            isSaving = false
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || basePrompt.trimmedForSettings.isEmpty || summaryPrompt.trimmedForSettings.isEmpty || !summaryAgentIsValid)
            }
        }
        .padding(22)
        .frame(width: 860)
        .frame(minHeight: 720)
        .onAppear {
            basePrompt = model.basePrompt
            summaryPrompt = model.summaryPrompt
            summaryAgent = model.summaryAgent
            claudePath = model.runtimeSettings.claudePath
            codexPath = model.runtimeSettings.codexPath
        }
    }

    private var basePromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Base Prompt")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    NSWorkspace.shared.open(model.basePromptURL)
                } label: {
                    Label("Edit File", systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .controlSize(.small)
                Button {
                    model.reloadBasePrompt()
                    basePrompt = model.basePrompt
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Reload from disk")
            }
            ScrollView {
                Markdown(basePrompt)
                    .markdownTheme(.settingsPreview)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
                .frame(minHeight: 180, maxHeight: 240)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.Color.surfaceStroke)
                )
            Text(model.basePromptURL.path)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
    }

    private var summaryAgentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Summary Agent")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    model.reloadSummaryAgent()
                    summaryAgent = model.summaryAgent
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Reload from disk")
            }

            HStack(spacing: 10) {
                AgentAvatar(
                    initials: AgentAvatar.initials(from: summaryAgent.name.isEmpty ? "S" : summaryAgent.name),
                    color: Theme.color(forSpeakerID: "summary", runtime: summaryAgent.runtime),
                    size: 28
                )
                TextField("Summary", text: $summaryAgent.name)
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
                Picker("", selection: summaryRuntimeBinding) {
                    ForEach(RuntimeID.allCases) { runtime in
                        Text(runtime.rawValue.capitalized).tag(runtime)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .labelsHidden()
            }

            HStack(spacing: 10) {
                settingPicker("Model") {
                    Picker("", selection: summaryModelBinding) {
                        ForEach(summaryModelOptions, id: \.id) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                if summaryAgent.runtime == .codex {
                    settingPicker("Reasoning") {
                        Picker("", selection: summaryReasoningBinding) {
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
                Text("Profile prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Neutral summary behavior", text: $summaryAgent.instructions, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.Color.surfaceOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.Color.surfaceStroke)
                    )
            }

            Text(model.summaryAgentURL.path)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
    }

    private var summaryPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Summary Prompt")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    NSWorkspace.shared.open(model.summaryPromptURL)
                } label: {
                    Label("Edit File", systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .controlSize(.small)
                Button {
                    model.reloadSummaryPrompt()
                    summaryPrompt = model.summaryPrompt
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Reload from disk")
            }
            ScrollView {
                Markdown(summaryPrompt)
                    .markdownTheme(.settingsPreview)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
                .frame(minHeight: 150, maxHeight: 220)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.Color.surfaceStroke)
                )
            Text(model.summaryPromptURL.path)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
    }

    private var agentPathsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Paths")
                .font(.system(size: 13, weight: .semibold))
            pathField(
                label: "Claude",
                placeholder: "/Users/me/.local/bin/claude",
                text: $claudePath
            )
            pathField(
                label: "Codex",
                placeholder: "/Users/me/.local/bin/codex",
                text: $codexPath
            )
        }
        .padding(12)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.surfaceStroke)
        )
    }

    private func pathField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.Color.surfaceStroke)
                )
        }
    }

    private var runtimesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Runtimes")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    Task {
                        await model.saveSettings(
                            claudePath: claudePath,
                            codexPath: codexPath,
                            basePrompt: basePrompt,
                            summaryPrompt: summaryPrompt,
                            summaryAgent: normalizedSummaryAgent
                        )
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            ForEach(RuntimeID.allCases) { runtime in
                runtimeRow(runtime)
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

    private func runtimeRow(_ runtime: RuntimeID) -> some View {
        let detected = model.detectedRuntimes[runtime]
        return HStack(spacing: 10) {
            AgentAvatar(
                initials: runtime == .claude ? "C" : "X",
                color: Theme.color(forSpeakerID: runtime.rawValue, runtime: runtime),
                size: 26
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(runtime.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
                Text(runtimeSubtitle(detected))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(detected?.available == true ? "Available" : "Missing")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(detected?.available == true ? Color.green : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(Capsule())
        }
    }

    private func runtimeSubtitle(_ detected: DetectedRuntime?) -> String {
        guard let detected else {
            return "Not detected"
        }
        if let version = detected.version, !version.isEmpty {
            return "\(detected.command) · \(version)"
        }
        return detected.command
    }

    private func settingPicker<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
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

    private var summaryRuntimeBinding: Binding<RuntimeID> {
        Binding {
            summaryAgent.runtime
        } set: { runtime in
            summaryAgent.runtime = runtime
            summaryAgent.model = "default"
            summaryAgent.reasoning = runtime == .codex ? "medium" : nil
        }
    }

    private var summaryModelOptions: [RuntimeModelOption] {
        if let detected = model.detectedRuntimes[summaryAgent.runtime]?.models, !detected.isEmpty {
            return detected
        }
        return RuntimeDefinitions.definition(for: summaryAgent.runtime).fallbackModels
    }

    private var summaryModelBinding: Binding<String> {
        Binding {
            let current = summaryAgent.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if current.isEmpty { return "default" }
            return summaryModelOptions.contains(where: { $0.id == current }) ? current : "default"
        } set: { value in
            summaryAgent.model = value
        }
    }

    private var summaryReasoningBinding: Binding<String> {
        Binding {
            let current = summaryAgent.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return current.isEmpty ? "default" : current
        } set: { value in
            summaryAgent.reasoning = value == "default" ? nil : value
        }
    }

    private var normalizedSummaryAgent: AgentProfile {
        let name = summaryAgent.name.trimmedForSettings
        let instructions = summaryAgent.instructions.trimmedForSettings
        let model = summaryAgent.model.trimmedForSettings
        let reasoning = summaryAgent.reasoning?.trimmedForSettings
        return AgentProfile(
            id: "summary",
            name: name.isEmpty ? "Summary" : name,
            role: "Summarizer",
            runtime: summaryAgent.runtime,
            model: model.isEmpty ? "default" : model,
            reasoning: reasoning?.isEmpty == true ? nil : reasoning,
            instructions: instructions,
            emoji: summaryAgent.emoji
        )
    }

    private var summaryAgentIsValid: Bool {
        !summaryAgent.name.trimmedForSettings.isEmpty
            && !summaryAgent.instructions.trimmedForSettings.isEmpty
    }
}

private extension String {
    var trimmedForSettings: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
