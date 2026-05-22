import AppKit
import RiffCore
import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var basePrompt = ""
    @State private var claudePath = ""
    @State private var codexPath = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    basePromptSection
                    agentPathsSection
                    runtimesSection
                }
                .padding(.bottom, 2)
            }
            .frame(maxHeight: 640)

            Divider().background(Theme.Color.separator)

            HStack {
                Button {
                    claudePath = RuntimeSettings.defaultExecutablePath(for: .claude)
                    codexPath = RuntimeSettings.defaultExecutablePath(for: .codex)
                } label: {
                    Label("Default Paths", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12))
                }
                .controlSize(.small)

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
                        await model.saveSettings(claudePath: claudePath, codexPath: codexPath, basePrompt: basePrompt)
                        await MainActor.run {
                            isSaving = false
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || claudePath.trimmedForSettings.isEmpty || codexPath.trimmedForSettings.isEmpty || basePrompt.trimmedForSettings.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 680)
        .onAppear {
            basePrompt = model.basePrompt
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
            TextEditor(text: $basePrompt)
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
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
                        await model.saveSettings(claudePath: claudePath, codexPath: codexPath, basePrompt: basePrompt)
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
}

private extension String {
    var trimmedForSettings: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
