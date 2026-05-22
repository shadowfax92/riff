import Combine
import Foundation
import RiffCore

struct ConversationRow: Identifiable, Equatable {
    var id: String { location.id }
    var location: ConversationLocation
    var conversation: Conversation
    var preview: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var rows: [ConversationRow] = []
    @Published var selectedID: String?
    @Published var selectedConversation: Conversation?
    @Published var transcript: [TranscriptEntry] = []
    @Published var files: [ConversationFile] = []
    @Published var selectedFile: ConversationFile?
    @Published var selectedMarkdown = ""
    @Published var basePrompt = ""
    @Published var isRunning = false
    @Published var activeTurn: ActiveTurnState?
    @Published var errorMessage: String?
    @Published var detectedRuntimes: [RuntimeID: DetectedRuntime] = [:]
    @Published var runtimeSettings = RuntimeSettings()

    private let paths = RiffPaths()
    private lazy var configStore = ConfigStore(paths: paths)

    var basePromptURL: URL { configStore.basePromptURL }
    var runtimeSettingsURL: URL { configStore.runtimeSettingsURL }

    /// Re-reads the base prompt from disk so the UI shows fresh content
    /// after the user opens and edits the markdown file externally.
    func reloadBasePrompt() {
        do {
            basePrompt = try configStore.readBasePrompt()
        } catch {
            errorMessage = String(describing: error)
        }
    }
    private var selectedLocation: ConversationLocation?
    private var runningOrchestrator: DebateOrchestrator?
    private var runTask: Task<Void, Never>?

    /// Initializes local config files and loads recent/default conversations
    /// into the sidebar without overwriting user-edited configs.
    func bootstrap() async {
        do {
            try configStore.bootstrap()
            basePrompt = try configStore.readBasePrompt()
            runtimeSettings = try configStore.readRuntimeSettings()
            detectedRuntimes = await detectRuntimes()
            try reloadRows()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func select(_ row: ConversationRow) async {
        selectedID = row.id
        selectedLocation = row.location
        await reloadSelected()
    }

    /// Creates a file-backed conversation either in the default Riff root or
    /// in a folder the user selected from the macOS file picker.
    func createConversation(title: String, prompt: String, maxRounds: Int, customFolder: URL?, roleDrafts: [RoleDraft]) async -> Bool {
        do {
            let agents = roleDrafts
                .filter(\.isValid)
                .enumerated()
                .map { offset, draft in draft.agentProfile(index: offset + 1) }
            guard !agents.isEmpty else {
                errorMessage = "Add at least one role with ROLE_NAME and ROLE_PROMPT."
                return false
            }
            let missingRuntimes = RuntimeRequirement.missingRuntimes(
                agents: agents,
                detectedRuntimes: detectedRuntimes
            )
            guard missingRuntimes.isEmpty else {
                errorMessage = RuntimeRequirement.settingsMessage(for: missingRuntimes)
                return false
            }
            let id = RiffPathFormat.newConversationID()
            let root = customFolder ?? paths.defaultConversationURL(id: id)
            let conversation = Conversation(
                id: id,
                title: title,
                prompt: prompt,
                maxRounds: maxRounds,
                agents: agents
            )
            let store = ConversationStore(rootURL: root)
            try store.create(conversation)
            let location = ConversationLocation(id: id, url: root)
            try configStore.rememberConversation(location)
            try reloadRows()
            if let row = rows.first(where: { $0.id == id }) {
                await select(row)
            }
            return true
        } catch {
            errorMessage = String(describing: error)
            return false
        }
    }

    /// Builds the inline setup prompt for the New Riff sheet from the same
    /// runtime readiness rule used by conversation creation.
    func runtimeSettingsPrompt(for roleDrafts: [RoleDraft]) -> String? {
        RuntimeRequirement.settingsMessage(
            for: RuntimeRequirement.missingRuntimes(
                roleDrafts: roleDrafts,
                detectedRuntimes: detectedRuntimes
            )
        )
    }

    func sendUserMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let location = selectedLocation else {
            return
        }
        do {
            if isRunning, let runningOrchestrator {
                await runningOrchestrator.queueUserMessage(trimmed)
                return
            }
            let store = ConversationStore(rootURL: location.url)
            let nextTurn = try store.readTranscript().count + 1
            let date = Date()
            try store.appendTranscript(TranscriptEntry(
                id: UUID().uuidString.lowercased(),
                turn: nextTurn,
                round: 0,
                speakerID: "user",
                speakerName: "You",
                text: trimmed,
                startedAt: date,
                finishedAt: date
            ))
            await reloadSelected()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Starts real Claude/Codex turns for the selected conversation using
    /// the configured baseline prompt and local CLI adapters.
    func startSelectedConversation() {
        guard let location = selectedLocation, !isRunning else {
            return
        }
        isRunning = true
        let store = ConversationStore(rootURL: location.url)
        let processClient = FoundationProcessClient(environment: runtimeSettings.processEnvironment)
        let orchestrator = DebateOrchestrator(
            store: store,
            adapters: [
                .claude: CLIRuntimeAdapter(
                    definition: RuntimeDefinitions.claude,
                    command: detectedRuntimes[.claude]?.command,
                    processClient: processClient
                ),
                .codex: CLIRuntimeAdapter(
                    definition: RuntimeDefinitions.codex,
                    command: detectedRuntimes[.codex]?.command,
                    processClient: processClient
                ),
            ],
            baselinePrompt: basePrompt,
            onTurnStart: { [weak self] agent, turn in
                Task { @MainActor [weak self] in
                    self?.activeTurn = ActiveTurnState(agent: agent, turn: turn, startedAt: Date())
                }
            },
            onTurnEvent: { [weak self] event in
                guard case .toolUse(let label) = event else { return }
                Task { @MainActor [weak self] in
                    self?.activeTurn?.events.append(label)
                }
            },
            onTurnEnd: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.activeTurn = nil
                }
            }
        )
        runningOrchestrator = orchestrator
        runTask = Task {
            do {
                _ = try await orchestrator.run()
            } catch {
                await MainActor.run {
                    self.errorMessage = String(describing: error)
                }
            }
            await MainActor.run {
                self.isRunning = false
                self.runningOrchestrator = nil
                self.activeTurn = nil
            }
            await self.reloadSelected()
            try? self.reloadRows()
        }
    }

    func stopSelectedConversation() async {
        await runningOrchestrator?.stop()
    }

    /// Deletes a conversation from disk and the sidebar. The selected running
    /// conversation is protected because a live CLI may still be writing into
    /// its folder.
    func deleteConversation(_ row: ConversationRow) async {
        guard !(isRunning && selectedID == row.id) else {
            errorMessage = "Stop the running conversation before deleting it."
            return
        }

        do {
            let wasSelected = selectedID == row.id
            try ConversationStore(rootURL: row.location.url).delete()
            try configStore.forgetConversation(row.location)
            try reloadRows()
            if wasSelected {
                clearSelection()
                if let nextRow = rows.first {
                    await select(nextRow)
                }
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Persists explicit runtime executable paths and immediately re-runs
    /// detection so settings changes are reflected before the next debate.
    func saveRuntimeSettings(claudePath: String, codexPath: String) async {
        await saveSettings(claudePath: claudePath, codexPath: codexPath, basePrompt: basePrompt)
    }

    /// Persists app-wide runtime and prompt settings used by future debates.
    func saveSettings(claudePath: String, codexPath: String, basePrompt: String) async {
        do {
            let settings = RuntimeSettings(claudePath: claudePath, codexPath: codexPath)
            try configStore.writeBasePrompt(basePrompt)
            try configStore.writeRuntimeSettings(settings)
            self.basePrompt = basePrompt
            runtimeSettings = settings
            detectedRuntimes = await detectRuntimes()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func resetRuntimeSettings() async {
        await saveRuntimeSettings(
            claudePath: RuntimeSettings.defaultExecutablePath(for: .claude),
            codexPath: RuntimeSettings.defaultExecutablePath(for: .codex)
        )
    }

    func refreshRuntimes() async {
        detectedRuntimes = await detectRuntimes()
    }

    func reloadSelected() async {
        guard let location = selectedLocation else {
            return
        }
        do {
            let store = ConversationStore(rootURL: location.url)
            selectedConversation = try store.readConversation()
            transcript = try store.readTranscript()
            files = try store.listMarkdownFiles()
            if let selectedFile, files.contains(selectedFile) {
                self.selectedFile = selectedFile
                selectedMarkdown = try store.readTextFile(relativePath: selectedFile.relativePath)
            } else {
                selectedFile = files.first
                selectedMarkdown = try files.first.map { try store.readTextFile(relativePath: $0.relativePath) } ?? ""
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func selectFile(_ file: ConversationFile) async {
        guard let location = selectedLocation else {
            return
        }
        do {
            selectedFile = file
            selectedMarkdown = try ConversationStore(rootURL: location.url).readTextFile(relativePath: file.relativePath)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func clearSelection() {
        selectedID = nil
        selectedLocation = nil
        selectedConversation = nil
        transcript = []
        files = []
        selectedFile = nil
        selectedMarkdown = ""
        activeTurn = nil
    }

    private func reloadRows() throws {
        var locations = try configStore.readRecentConversations()
        let defaultLocations = try defaultConversationLocations()
        for location in defaultLocations where !locations.contains(where: { $0.id == location.id }) {
            locations.append(location)
        }
        rows = locations.compactMap { location in
            let store = ConversationStore(rootURL: location.url)
            guard let conversation = try? store.readConversation() else {
                return nil
            }
            let preview = (try? store.readTranscript().last?.text) ?? conversation.prompt
            return ConversationRow(location: location, conversation: conversation, preview: preview)
        }
        .sorted { $0.conversation.createdAt > $1.conversation.createdAt }
    }

    private func defaultConversationLocations() throws -> [ConversationLocation] {
        guard FileManager.default.fileExists(atPath: paths.conversationsURL.path) else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: paths.conversationsURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        return urls.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }
            let store = ConversationStore(rootURL: url)
            return (try? store.readConversation()).map { ConversationLocation(id: $0.id, url: url) }
        }
    }

    private func detectRuntimes() async -> [RuntimeID: DetectedRuntime] {
        let detector = RuntimeDetector(processClient: FoundationProcessClient(environment: runtimeSettings.processEnvironment))
        let results = await [
            detector.detect(RuntimeDefinitions.claude, preferredCommand: runtimeSettings.command(for: .claude)),
            detector.detect(RuntimeDefinitions.codex, preferredCommand: runtimeSettings.command(for: .codex)),
        ]
        return Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
    }
}
