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
    @Published var agents: [AgentProfile] = []
    @Published var basePrompt = ""
    @Published var isRunning = false
    @Published var errorMessage: String?

    private let paths = RiffPaths()
    private lazy var configStore = ConfigStore(paths: paths)
    private var selectedLocation: ConversationLocation?
    private var runningOrchestrator: DebateOrchestrator?
    private var runTask: Task<Void, Never>?

    /// Initializes local config files and loads recent/default conversations
    /// into the sidebar without overwriting user-edited configs.
    func bootstrap() async {
        do {
            try configStore.bootstrap()
            basePrompt = try configStore.readBasePrompt()
            agents = try configStore.readAgents()
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
    func createConversation(title: String, prompt: String, maxRounds: Int, customFolder: URL?) async {
        do {
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
        } catch {
            errorMessage = String(describing: error)
        }
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
        let orchestrator = DebateOrchestrator(
            store: store,
            adapters: [
                .claude: CLIRuntimeAdapter(definition: RuntimeDefinitions.claude),
                .codex: CLIRuntimeAdapter(definition: RuntimeDefinitions.codex),
            ],
            baselinePrompt: basePrompt
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
            }
            await self.reloadSelected()
            try? self.reloadRows()
        }
    }

    func stopSelectedConversation() async {
        await runningOrchestrator?.stop()
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
}
