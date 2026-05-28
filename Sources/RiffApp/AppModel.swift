import Combine
import Foundation
import RiffCore

struct ConversationRow: Identifiable, Equatable {
    var id: String { location.id }
    var location: ConversationLocation
    var conversation: Conversation
    var preview: String
}

struct PendingSteer: Equatable {
    var conversationID: String
    var messages: [String]

    var count: Int { messages.count }
    var latestText: String { messages.last ?? "" }
}

private struct ConversationRunConfiguration {
    var limit: DebateRunLimit
    var automaticallySummarizeOnCompletion: Bool
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
    @Published var summaryPrompt = ""
    @Published var summaryAgent = ConfigStore.defaultSummaryAgent
    @Published var runRegistry = ConversationRunRegistry()
    @Published var errorMessage: String?
    @Published var detectedRuntimes: [RuntimeID: DetectedRuntime] = [:]
    @Published var runtimeSettings = RuntimeSettings()
    @Published var pendingSteers: [String: [String]] = [:]
    @Published var applyingSteerIDs: Set<String> = []
    @Published var summarizingIDs: Set<String> = []

    private let paths = RiffPaths()
    private lazy var configStore = ConfigStore(paths: paths)
    private lazy var processLogger = FileProcessLogger(directoryURL: paths.logsURL)

    var basePromptURL: URL { configStore.basePromptURL }
    var summaryPromptURL: URL { configStore.summaryPromptURL }
    var summaryAgentURL: URL { configStore.summaryAgentURL }
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

    /// Re-reads the summary prompt from disk so settings can pick up edits
    /// made in an external markdown editor.
    func reloadSummaryPrompt() {
        do {
            summaryPrompt = try configStore.readSummaryPrompt()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Re-reads the summary agent profile used by manual and automatic
    /// summaries without changing any debate agents.
    func reloadSummaryAgent() {
        do {
            summaryAgent = try configStore.readSummaryAgent()
        } catch {
            errorMessage = String(describing: error)
        }
    }
    private var selectedLocation: ConversationLocation?
    private var uiOnlySummaries = UIOnlySummaryStore()
    private var runningOrchestrators: [String: DebateOrchestrator] = [:]
    private var runTasks: [String: Task<Void, Never>] = [:]

    var isRunning: Bool { !runRegistry.runningIDs.isEmpty }
    var isSelectedConversationRunning: Bool { runRegistry.isRunning(conversationID: selectedID) }
    var isSelectedConversationSummarizing: Bool { selectedID.map { summarizingIDs.contains($0) } ?? false }
    var selectedActiveTurn: ActiveTurnState? { runRegistry.activeTurn(conversationID: selectedID) }
    var isSelectedApplyingSteer: Bool { selectedID.map { applyingSteerIDs.contains($0) } ?? false }
    var selectedPendingSteer: PendingSteer? {
        guard let selectedID, let messages = pendingSteers[selectedID], !messages.isEmpty else {
            return nil
        }
        return PendingSteer(conversationID: selectedID, messages: messages)
    }

    /// On-disk folder backing the selected conversation (~/.riff/conversations/<id>),
    /// surfaced so the Details sheet can show and copy its full path.
    var selectedConversationURL: URL? { selectedLocation?.url }

    /// Initializes local config files and loads recent/default conversations
    /// into the sidebar without overwriting user-edited configs.
    func bootstrap() async {
        do {
            try configStore.bootstrap()
            basePrompt = try configStore.readBasePrompt()
            summaryPrompt = try configStore.readSummaryPrompt()
            summaryAgent = try configStore.readSummaryAgent()
            runtimeSettings = try configStore.readRuntimeSettings()
            detectedRuntimes = await detectRuntimes()
            try reloadRows()
            await selectRowAfterReload(preferredID: selectedID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Re-scans conversation folders so riffs created by the Go CLI appear
    /// when the app launches or returns to the foreground.
    func refreshRowsFromDisk() async {
        do {
            let preferredID = selectedID
            try configStore.bootstrap()
            try reloadRows()
            await selectRowAfterReload(preferredID: preferredID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func select(_ row: ConversationRow) async {
        selectedID = row.id
        selectedLocation = row.location
        await reloadSelected()
    }

    @discardableResult
    func selectConversation(id: String) async -> Bool {
        if let row = rows.first(where: { $0.id == id }) {
            await select(row)
            return true
        }
        do {
            try reloadRows()
        } catch {
            errorMessage = String(describing: error)
            return false
        }
        guard let row = rows.first(where: { $0.id == id }) else {
            return false
        }
        await select(row)
        return true
    }

    /// Creates a file-backed conversation under Riff's conversation root and
    /// records user-selected support folders that agents may read during turns.
    func createConversation(title: String, prompt: String, maxRounds: Int, supportFolders: [URL], roleDrafts: [RoleDraft]) async -> Bool {
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
            let root = paths.defaultConversationURL(id: id)
            let conversation = Conversation(
                id: id,
                title: title,
                prompt: prompt,
                maxRounds: maxRounds,
                agents: agents,
                supportFolders: supportFolders
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

    /// Commits a human-authored message and, when the debate is idle,
    /// kicks off the agents immediately so the user never has to find a
    /// separate Start button after sending. During an active run, the
    /// text becomes a visible steer request so the user can decide
    /// whether to interrupt the in-flight agent turn.
    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let location = selectedLocation else {
            return
        }
        do {
            if runRegistry.isRunning(conversationID: location.id) {
                queueSteerMessage(trimmed)
                return
            }
            let runConfiguration = runConfiguration(
                for: location,
                completedLimit: .additionalRounds(1)
            )
            try appendUserMessages([trimmed], to: location)
            startConversation(
                at: location,
                limit: runConfiguration.limit,
                automaticallySummarizeOnCompletion: runConfiguration.automaticallySummarizeOnCompletion
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Applies queued steer text by cancelling the active agent process,
    /// writing the human message, and restarting the debate loop from disk.
    func applyPendingSteer() {
        guard let selectedID, let location = selectedLocation, let pendingSteer = selectedPendingSteer else {
            return
        }
        let messages = pendingSteer.messages
        removePendingSteer(conversationID: selectedID)

        if runRegistry.isRunning(conversationID: selectedID), let task = runTasks[selectedID] {
            setApplyingSteer(true, conversationID: selectedID)
            task.cancel()
            Task { @MainActor [weak self] in
                await task.value
                guard let self else {
                    return
                }
                do {
                    let runConfiguration = self.runConfiguration(
                        for: location,
                        completedLimit: .additionalRounds(1)
                    )
                    try self.appendUserMessages(messages, to: location)
                    self.setApplyingSteer(false, conversationID: selectedID)
                    self.startConversation(
                        at: location,
                        limit: runConfiguration.limit,
                        automaticallySummarizeOnCompletion: runConfiguration.automaticallySummarizeOnCompletion
                    )
                } catch {
                    self.setApplyingSteer(false, conversationID: selectedID)
                    self.errorMessage = String(describing: error)
                }
            }
        } else {
            do {
                let runConfiguration = runConfiguration(
                    for: location,
                    completedLimit: .additionalRounds(1)
                )
                try appendUserMessages(messages, to: location)
                startConversation(
                    at: location,
                    limit: runConfiguration.limit,
                    automaticallySummarizeOnCompletion: runConfiguration.automaticallySummarizeOnCompletion
                )
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    func clearPendingSteer() {
        guard let selectedID else {
            return
        }
        removePendingSteer(conversationID: selectedID)
    }

    /// Starts real Claude/Codex turns for the selected conversation using
    /// the configured baseline prompt and local CLI adapters.
    func startSelectedConversation() {
        guard let location = selectedLocation else {
            return
        }
        let runConfiguration = runConfiguration(
            for: location,
            completedLimit: .unbounded
        )
        startConversation(
            at: location,
            limit: runConfiguration.limit,
            automaticallySummarizeOnCompletion: runConfiguration.automaticallySummarizeOnCompletion
        )
    }

    func removeSelectedSummary() {
        guard let selectedID, let location = selectedLocation else {
            return
        }
        uiOnlySummaries.remove(for: selectedID)
        reloadConversationFromDiskIfSelected(location)
    }

    private func startConversation(
        at location: ConversationLocation,
        limit: DebateRunLimit = .configuredRounds,
        automaticallySummarizeOnCompletion: Bool = true
    ) {
        guard !runRegistry.isRunning(conversationID: location.id) else {
            return
        }
        uiOnlySummaries.remove(for: location.id)
        reloadConversationFromDiskIfSelected(location)
        updateRunRegistry { $0.start(conversationID: location.id) }
        let store = ConversationStore(rootURL: location.url)
        let summaryPrompt = summaryPrompt
        let summaryAgent = summaryAgent
        let conversationID = location.id
        let processClient = makeProcessClient()
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
                    self?.updateRunRegistry {
                        $0.setActiveTurn(
                            ActiveTurnState(agent: agent, turn: turn, startedAt: Date()),
                            conversationID: conversationID
                        )
                    }
                }
            },
            onTurnEvent: { [weak self] event in
                guard case .toolUse(let label) = event else { return }
                Task { @MainActor [weak self] in
                    self?.updateRunRegistry {
                        $0.appendEvent(label, conversationID: conversationID)
                    }
                }
            },
            onTurnEnd: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.updateRunRegistry {
                        $0.clearActiveTurn(conversationID: conversationID)
                    }
                }
            },
            onTranscriptChange: { [weak self] in
                await MainActor.run { [weak self] in
                    self?.reloadConversationFromDiskIfSelected(location)
                    try? self?.reloadRows()
                }
            }
        )
        runningOrchestrators[conversationID] = orchestrator
        runTasks[conversationID] = Task {
            var completedNaturally = false
            var summaryEntry: TranscriptEntry?
            do {
                let transcript = try await orchestrator.run(limit: limit)
                if let conversation = try? store.readConversation() {
                    completedNaturally = self.didComplete(transcript: transcript, conversation: conversation)
                }
                if completedNaturally && automaticallySummarizeOnCompletion {
                    summaryEntry = try await orchestrator.summarize(
                        summaryPrompt: summaryPrompt,
                        summaryAgent: summaryAgent
                    )
                }
            } catch {
                await MainActor.run {
                    guard !(error is CancellationError) else {
                        return
                    }
                    self.errorMessage = String(describing: error)
                }
            }
            await MainActor.run {
                self.updateRunRegistry { $0.finish(conversationID: conversationID) }
                self.runningOrchestrators[conversationID] = nil
                self.runTasks[conversationID] = nil
                if let summaryEntry {
                    self.uiOnlySummaries.set(summaryEntry, for: conversationID)
                }
                self.reloadConversationFromDiskIfSelected(location)
                try? self.reloadRows()
            }
        }
    }

    private func runConfiguration(
        for location: ConversationLocation,
        completedLimit: DebateRunLimit
    ) -> ConversationRunConfiguration {
        let hasCompletedConfiguredRounds = (try? hasReachedConfiguredRounds(at: location)) ?? false
        if hasCompletedConfiguredRounds {
            return ConversationRunConfiguration(
                limit: completedLimit,
                automaticallySummarizeOnCompletion: false
            )
        }
        return ConversationRunConfiguration(
            limit: .configuredRounds,
            automaticallySummarizeOnCompletion: true
        )
    }

    /// Runs the configured summary agent in a fresh CLI session for the
    /// selected conversation and appends the result as UI-only transcript state.
    func summarizeSelectedConversation() {
        guard let location = selectedLocation, !summarizingIDs.contains(location.id) else {
            return
        }
        guard !transcript.isEmpty else {
            errorMessage = "No messages to summarize yet."
            return
        }
        let missingRuntimes = RuntimeRequirement.missingRuntimes(
            agents: [summaryAgent],
            detectedRuntimes: detectedRuntimes
        )
        guard missingRuntimes.isEmpty else {
            let names = missingRuntimes.map { $0.rawValue.capitalized }.joined(separator: " and ")
            errorMessage = "\(names) unavailable. Set the missing executable path in Settings before summarizing."
            return
        }

        setSummarizing(true, conversationID: location.id)
        let store = ConversationStore(rootURL: location.url)
        let summaryPrompt = summaryPrompt
        let summaryAgent = summaryAgent
        let conversationID = location.id
        let processClient = makeProcessClient()
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
            baselinePrompt: basePrompt
        )

        Task { @MainActor [weak self] in
            var summaryEntry: TranscriptEntry?
            do {
                summaryEntry = try await orchestrator.summarize(
                    summaryPrompt: summaryPrompt,
                    summaryAgent: summaryAgent
                )
            } catch {
                self?.errorMessage = String(describing: error)
            }
            guard let self else {
                return
            }
            self.setSummarizing(false, conversationID: conversationID)
            if let summaryEntry {
                self.uiOnlySummaries.set(summaryEntry, for: conversationID)
            }
            self.reloadConversationFromDiskIfSelected(location)
            try? self.reloadRows()
        }
    }

    func stopSelectedConversation() async {
        guard let selectedID else {
            return
        }
        await runningOrchestrators[selectedID]?.stop()
    }

    /// Deletes a conversation from disk and the sidebar. The selected running
    /// conversation is protected because a live CLI may still be writing into
    /// its folder.
    func deleteConversation(_ row: ConversationRow) async {
        guard !runRegistry.isRunning(conversationID: row.id) else {
            errorMessage = "Stop the running conversation before deleting it."
            return
        }

        do {
            let wasSelected = selectedID == row.id
            try ConversationStore(rootURL: row.location.url).delete()
            try configStore.forgetConversation(row.location)
            uiOnlySummaries.remove(for: row.id)
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
        await saveSettings(
            claudePath: claudePath,
            codexPath: codexPath,
            basePrompt: basePrompt,
            summaryPrompt: summaryPrompt,
            summaryAgent: summaryAgent
        )
    }

    /// Persists app-wide runtime and prompt settings used by future debates.
    func saveSettings(
        claudePath: String,
        codexPath: String,
        basePrompt: String,
        summaryPrompt: String,
        summaryAgent: AgentProfile
    ) async {
        do {
            let settings = RuntimeSettings(claudePath: claudePath, codexPath: codexPath)
            try configStore.writeBasePrompt(basePrompt)
            try configStore.writeSummaryPrompt(summaryPrompt)
            try configStore.writeSummaryAgent(summaryAgent)
            try configStore.writeRuntimeSettings(settings)
            self.basePrompt = basePrompt
            self.summaryPrompt = summaryPrompt
            self.summaryAgent = summaryAgent
            runtimeSettings = settings
            detectedRuntimes = await detectRuntimes()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func refreshRuntimes() async {
        detectedRuntimes = await detectRuntimes()
    }

    func isConversationRunning(_ conversationID: String) -> Bool {
        runRegistry.isRunning(conversationID: conversationID)
    }

    func reloadSelected() async {
        reloadSelectedFromDisk()
    }

    private func reloadSelectedFromDisk() {
        guard let location = selectedLocation else {
            return
        }
        reloadConversationFromDisk(location)
    }

    private func reloadConversationFromDiskIfSelected(_ location: ConversationLocation) {
        guard selectedID == location.id else {
            return
        }
        reloadConversationFromDisk(location)
    }

    private func reloadConversationFromDisk(_ location: ConversationLocation) {
        do {
            let store = ConversationStore(rootURL: location.url)
            selectedConversation = try store.readConversation()
            let diskTranscript = try store.readTranscriptWithExistingAttachments()
            transcript = uiOnlySummaries.merged(with: diskTranscript, conversationID: location.id)
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
        if let selectedID {
            removePendingSteer(conversationID: selectedID)
        }
        selectedID = nil
        selectedLocation = nil
        selectedConversation = nil
        transcript = []
        files = []
        selectedFile = nil
        selectedMarkdown = ""
    }

    private func queueSteerMessage(_ text: String) {
        guard let selectedID else {
            return
        }
        var steers = pendingSteers
        steers[selectedID, default: []].append(text)
        pendingSteers = steers
    }

    private func appendUserMessages(_ messages: [String], to location: ConversationLocation) throws {
        let store = ConversationStore(rootURL: location.url)
        var nextTurn = try store.readTranscript().count + 1
        for message in messages {
            let date = Date()
            try store.appendTranscript(TranscriptEntry(
                id: UUID().uuidString.lowercased(),
                turn: nextTurn,
                round: 0,
                speakerID: "user",
                speakerName: "You",
                text: message,
                startedAt: date,
                finishedAt: date
            ))
            nextTurn += 1
        }
        reloadConversationFromDiskIfSelected(location)
        try reloadRows()
    }

    private func updateRunRegistry(_ update: (inout ConversationRunRegistry) -> Void) {
        var registry = runRegistry
        update(&registry)
        runRegistry = registry
    }

    private func setApplyingSteer(_ applying: Bool, conversationID: String) {
        var ids = applyingSteerIDs
        if applying {
            ids.insert(conversationID)
        } else {
            ids.remove(conversationID)
        }
        applyingSteerIDs = ids
    }

    private func setSummarizing(_ summarizing: Bool, conversationID: String) {
        var ids = summarizingIDs
        if summarizing {
            ids.insert(conversationID)
        } else {
            ids.remove(conversationID)
        }
        summarizingIDs = ids
    }

    private func removePendingSteer(conversationID: String) {
        var steers = pendingSteers
        steers[conversationID] = nil
        pendingSteers = steers
    }

    private func didComplete(transcript: [TranscriptEntry], conversation: Conversation) -> Bool {
        let agentTurns = transcript.filter { $0.speakerID != "user" }.count
        return agentTurns >= conversation.maxRounds * conversation.agents.count
    }

    private func hasReachedConfiguredRounds(at location: ConversationLocation) throws -> Bool {
        let store = ConversationStore(rootURL: location.url)
        let conversation = try store.readConversation()
        let transcript = try store.readTranscript()
        return didComplete(transcript: transcript, conversation: conversation)
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

    private func selectRowAfterReload(preferredID: String?) async {
        if let preferredID, let row = rows.first(where: { $0.id == preferredID }) {
            await select(row)
            return
        }
        if let first = rows.first {
            await select(first)
        } else {
            clearSelection()
        }
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
        let detector = RuntimeDetector(processClient: makeProcessClient())
        let results = await [
            detector.detect(RuntimeDefinitions.claude, preferredCommand: runtimeSettings.command(for: .claude)),
            detector.detect(RuntimeDefinitions.codex, preferredCommand: runtimeSettings.command(for: .codex)),
        ]
        return Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
    }

    /// Creates CLI process clients with the configured subprocess PATH and
    /// shared command logging so runtime probes and agent turns are debuggable.
    private func makeProcessClient() -> FoundationProcessClient {
        FoundationProcessClient(environment: runtimeSettings.processEnvironment, logger: processLogger)
    }
}
