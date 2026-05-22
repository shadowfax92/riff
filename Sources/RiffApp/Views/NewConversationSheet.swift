import SwiftUI

struct NewConversationSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var prompt = ""
    @State private var maxRounds = 1
    @State private var customFolder: URL?
    @State private var choosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Riff")
                .font(.system(size: 22, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Architecture debate", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("What should the agents debate?", text: $prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
            }

            Stepper("Rounds: \(maxRounds)", value: $maxRounds, in: 1...12)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        choosingFolder = true
                    } label: {
                        Label("Choose Folder", systemImage: "folder")
                    }
                    if let customFolder {
                        Text(customFolder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Default: ~/.riff/conversations/<id>")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Agents from ~/.riff/configs/agents.json")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(model.agents) { agent in
                    HStack {
                        Text(agent.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(agent.runtime.rawValue)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                        Spacer()
                        Text(agent.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    Task {
                        await model.createConversation(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Riff" : title,
                            prompt: prompt,
                            maxRounds: maxRounds,
                            customFolder: customFolder
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.agents.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 560)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.directory]) { result in
            if case .success(let url) = result {
                customFolder = url
            }
        }
    }
}
