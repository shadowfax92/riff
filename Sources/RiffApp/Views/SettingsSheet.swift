import AppKit
import RiffCore
import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var cliPath = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("CLI PATH")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("/Users/me/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin", text: $cliPath, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(3...6)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.Color.surfaceOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.Color.surfaceStroke)
                    )
            }
            .padding(12)
            .background(Theme.Color.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.Color.surfaceStroke)
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Runtimes")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button {
                        Task { await model.refreshRuntimes() }
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

            HStack {
                Button {
                    cliPath = RuntimeSettings.defaultCLIPath()
                } label: {
                    Label("Default", systemImage: "arrow.counterclockwise")
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
                        await model.saveRuntimeSettings(cliPath: cliPath)
                        await MainActor.run {
                            isSaving = false
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || cliPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 560)
        .onAppear {
            cliPath = model.runtimeSettings.cliPath
        }
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
