import Foundation
import Testing
@testable import RiffCore

@Test func runUsesAgentOrderAndAppendsTranscriptEntries() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .codex)])
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter, .codex: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    let transcript = try await orchestrator.run()

    #expect(transcript.map(\.speakerID) == ["a1", "a2"])
    #expect(try store.readTranscript().map(\.speakerID) == ["a1", "a2"])
}

@Test func configuredRunDoesNotAppendTurnsAfterConfiguredRoundsAreComplete() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)], maxRounds: 1)
    try store.appendTranscript(transcriptEntry(turn: 1, speakerID: "a1", speakerName: "Agent a1", text: "done a1"))
    try store.appendTranscript(transcriptEntry(turn: 2, speakerID: "a2", speakerName: "Agent a2", text: "done a2"))
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    _ = try await orchestrator.run()

    #expect(try store.readTranscript().map(\.speakerID) == ["a1", "a2"])
    #expect(await adapter.requests.isEmpty)
}

@Test func additionalRoundRunAppendsOneFullRoundAfterConfiguredRoundsAreComplete() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)], maxRounds: 1)
    try store.appendTranscript(transcriptEntry(turn: 1, speakerID: "a1", speakerName: "Agent a1", text: "done a1"))
    try store.appendTranscript(transcriptEntry(turn: 2, speakerID: "a2", speakerName: "Agent a2", text: "done a2"))
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    _ = try await orchestrator.run(limit: .additionalRounds(1))

    let transcript = try store.readTranscript()
    #expect(transcript.map(\.speakerID) == ["a1", "a2", "a1", "a2"])
    #expect(transcript.suffix(2).map(\.round) == [2, 2])
    #expect(await adapter.requests.count == 2)
}

@Test func unboundedRunContinuesAfterConfiguredRoundsUntilStopped() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)], maxRounds: 1)
    try store.appendTranscript(transcriptEntry(turn: 1, speakerID: "a1", speakerName: "Agent a1", text: "done a1"))
    try store.appendTranscript(transcriptEntry(turn: 2, speakerID: "a2", speakerName: "Agent a2", text: "done a2"))
    let adapter = RecordingAdapter()
    let stopController = StopController()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock(),
        onTranscriptChange: {
            if ((try? store.readTranscript().count) ?? 0) >= 5 {
                await stopController.stop()
            }
        }
    )
    await stopController.set(orchestrator)

    _ = try await orchestrator.run(limit: .unbounded)

    let transcript = try store.readTranscript()
    #expect(transcript.map(\.speakerID) == ["a1", "a2", "a1", "a2", "a1"])
    #expect(await adapter.requests.count == 3)
}

@Test func continuingAfterAgentModelUpdateUsesFreshSessionAndNewModel() async throws {
    var initialAgent = agent("a1", .claude)
    initialAgent.model = "old-model"
    let store = try makeStore(agents: [initialAgent], maxRounds: 1)
    let firstAdapter = RecordingAdapter()
    let firstRun = DebateOrchestrator(
        store: store,
        adapters: [.claude: firstAdapter],
        baselinePrompt: "base",
        now: fixedClock()
    )
    _ = try await firstRun.run()
    #expect(try store.readAgentSession(agentID: "a1").sessionID == "session-a1")

    var updatedAgents = try store.readConversation().agents
    updatedAgents[0].model = "new-model"
    try store.updateAgents(updatedAgents)

    let secondAdapter = RecordingAdapter()
    let secondRun = DebateOrchestrator(
        store: store,
        adapters: [.claude: secondAdapter],
        baselinePrompt: "base",
        now: fixedClock()
    )
    _ = try await secondRun.run(limit: .additionalRounds(1))

    let request = try #require(await secondAdapter.requests.first)
    #expect(request.agent.model == "new-model")
    #expect(request.sessionID == nil)
}

@Test func queuedUserMessagesAreCommittedBeforeNextAgentTurn() async throws {
    let store = try makeStore(agents: [agent("a1", .claude)])
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    await orchestrator.queueUserMessage("Please address cost.")
    _ = try await orchestrator.run()

    #expect(try store.readTranscript().map(\.speakerID) == ["user", "a1"])
    #expect(await adapter.requests.first?.context.contains("Please address cost.") == true)
}

@Test func transcriptChangeCallbackRunsAfterEachCommittedEntry() async throws {
    let store = try makeStore(agents: [agent("a1", .claude)])
    let adapter = RecordingAdapter()
    let recorder = TranscriptChangeRecorder()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock(),
        onTranscriptChange: {
            await recorder.record((try? store.readTranscript().count) ?? -1)
        }
    )

    await orchestrator.queueUserMessage("Please address cost.")
    _ = try await orchestrator.run()

    #expect(await recorder.counts == [1, 2])
}

@Test func agentsKeepIndependentSessions() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)])
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    _ = try await orchestrator.run()

    #expect(try store.readAgentSession(agentID: "a1").sessionID == "session-a1")
    #expect(try store.readAgentSession(agentID: "a2").sessionID == "session-a2")
}

@Test func agentsReceiveOnlyNewNonSelfContextAfterTheirCursor() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)], maxRounds: 3)
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    _ = try await orchestrator.run()

    let requests = await adapter.requests
    #expect(requests.count == 6)
    #expect(requests[0].context.isEmpty)
    #expect(requests[1].context.contains("turn-001.role-a1.claude.md"))
    #expect(requests[2].context.contains("turn-002.role-a2.claude.md"))
    #expect(!requests[2].context.contains("turn-001.role-a1.claude.md"))
    #expect(requests[3].context.contains("turn-003.role-a1.claude.md"))
    #expect(!requests[3].context.contains("turn-001.role-a1.claude.md"))
    #expect(!requests[3].context.contains("turn-002.role-a2.claude.md"))
    #expect(requests[4].context.contains("turn-004.role-a2.claude.md"))
    #expect(!requests[4].context.contains("turn-002.role-a2.claude.md"))
    #expect(!requests[4].context.contains("turn-003.role-a1.claude.md"))
    #expect(requests[5].context.contains("turn-005.role-a1.claude.md"))
    #expect(!requests[5].context.contains("turn-003.role-a1.claude.md"))
    #expect(!requests[5].context.contains("turn-004.role-a2.claude.md"))
    #expect(try store.readAgentSession(agentID: "a1").lastContextTurn == 4)
    #expect(try store.readAgentSession(agentID: "a2").lastContextTurn == 5)
}

@Test func queuedUserMessagesAfterCursorAreDeliveredOnce() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)], maxRounds: 2)
    try store.appendTranscript(transcriptEntry(turn: 1, speakerID: "a1", speakerName: "Agent a1", text: "old a1"))
    try store.appendTranscript(transcriptEntry(turn: 2, speakerID: "a2", speakerName: "Agent a2", text: "old a2"))
    try store.writeAgentSession(AgentSession(sessionID: "session-a1", lastContextTurn: 2), agentID: "a1")
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    await orchestrator.queueUserMessage("fresh guidance")
    _ = try await orchestrator.run()

    let requests = await adapter.requests
    #expect(requests.first?.context == "You: fresh guidance")
}

@Test func runtimeRequestsIncludeConversationSupportFolders() async throws {
    let supportFolders = [
        URL(fileURLWithPath: "/Users/me/research"),
        URL(fileURLWithPath: "/Users/me/notes"),
    ]
    let store = try makeStore(agents: [agent("a1", .claude)], supportFolders: supportFolders)
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    _ = try await orchestrator.run()

    let request = try #require(await adapter.requests.first)
    #expect(request.supportFolders == supportFolders)
    #expect(request.conversationRoot == store.rootURL)
}

@Test func createdAndMentionedMarkdownFilesAreLinkedFromTurn() async throws {
    let store = try makeStore(agents: [agent("a1", .claude)])
    let adapter = FileWritingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    let transcript = try await orchestrator.run()

    #expect(transcript[0].attachments.map(\.path) == ["files/turn-001.role-a1.claude.md"])
    #expect(try store.readTextFile(relativePath: "files/turn-001.role-a1.claude.md").contains("detail"))
}

@Test func mentionedMarkdownPathIsIgnoredWhenFileDoesNotExist() async throws {
    let store = try makeStore(agents: [agent("a1", .claude)])
    let adapter = MissingFileMentionAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    let transcript = try await orchestrator.run()

    #expect(transcript[0].attachments.isEmpty)
    #expect(try store.listMarkdownFiles().isEmpty)
}

@Test func stopWaitsForCurrentTurnToFinish() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)])
    let adapter = BlockingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    let task = Task {
        try await orchestrator.run()
    }
    await adapter.waitUntilStarted()
    await orchestrator.stop()
    await adapter.release()
    _ = try await task.value

    #expect(try store.readTranscript().map(\.speakerID) == ["a1"])
    #expect(try store.readConversation().status == .stopped)
}

@Test func cancelledTurnDoesNotAppendErrorTranscriptEntry() async throws {
    let store = try makeStore(agents: [agent("a1", .claude)])
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: CancellingAdapter()],
        baselinePrompt: "base",
        now: fixedClock()
    )

    do {
        _ = try await orchestrator.run()
        Issue.record("Expected cancellation")
    } catch is CancellationError {
        #expect(try store.readTranscript().isEmpty)
    }
}

@Test func SummaryGenerationUsesConfiguredSummaryAgentFreshSessionAndFullTranscript() async throws {
    let store = try makeStore(agents: [agent("a1", .claude), agent("a2", .claude)])
    try store.appendTranscript(transcriptEntry(turn: 1, speakerID: "user", speakerName: "You", text: "keep it simple"))
    try store.appendTranscript(transcriptEntry(turn: 2, speakerID: "a1", speakerName: "Agent a1", text: "first argument"))
    try store.appendTranscript(transcriptEntry(turn: 3, speakerID: "a2", speakerName: "Agent a2", text: "second argument"))
    try store.writeAgentSession(AgentSession(sessionID: "existing-session"), agentID: "a1")
    let summaryAgent = AgentProfile(
        id: "summary",
        name: "Digest Writer",
        role: "Summarizer",
        runtime: .claude,
        model: "sonnet",
        instructions: "Summarize neutrally."
    )
    let adapter = RecordingAdapter()
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    let summary = try await orchestrator.summarize(summaryPrompt: "summary prompt", summaryAgent: summaryAgent)

    let requests = await adapter.requests
    #expect(requests.count == 1)
    #expect(requests[0].purpose == .summary)
    #expect(requests[0].agent == summaryAgent)
    #expect(requests[0].sessionID == nil)
    #expect(requests[0].baselinePrompt == "summary prompt")
    #expect(requests[0].context.contains("You: keep it simple"))
    #expect(requests[0].context.contains("Agent a1: first argument"))
    #expect(requests[0].context.contains("Agent a2: second argument"))
    #expect(summary?.speakerID == "summary")
    #expect(summary?.speakerName == "Digest Writer")
    #expect(summary?.text.hasPrefix("### Summary") == true)
    #expect(try store.readTranscript().count == 3)
}

@Test func SummaryGenerationRetriesHeadingOnlyRuntimeOutput() async throws {
    let store = try makeStore(agents: [agent("a1", .claude)])
    try store.appendTranscript(transcriptEntry(turn: 1, speakerID: "user", speakerName: "You", text: "keep it simple"))
    try store.appendTranscript(transcriptEntry(turn: 2, speakerID: "a1", speakerName: "Agent a1", text: "first argument"))
    let adapter = RecordingAdapter(responses: [
        RuntimeTurnResult(text: "### Summary", sessionID: "empty-summary"),
        RuntimeTurnResult(text: "The debate ended with one clear argument.", sessionID: "filled-summary"),
    ])
    let orchestrator = DebateOrchestrator(
        store: store,
        adapters: [.claude: adapter],
        baselinePrompt: "base",
        now: fixedClock()
    )

    let summary = try await orchestrator.summarize(
        summaryPrompt: "summary prompt",
        summaryAgent: agent("summary", .claude)
    )

    let requests = await adapter.requests
    #expect(requests.count == 2)
    let retryRequest = try #require(requests.dropFirst().first)
    #expect(retryRequest.baselinePrompt.contains("previous summary response contained only the heading"))
    #expect(summary?.text == "### Summary\n\nThe debate ended with one clear argument.")
    #expect(summary?.sessionID == "filled-summary")
    #expect(try store.readTranscript().count == 2)
}

private actor RecordingAdapter: RuntimeAdapter {
    var requests: [RuntimeTurnRequest] = []
    var responses: [RuntimeTurnResult]

    init(responses: [RuntimeTurnResult] = []) {
        self.responses = responses
    }

    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult {
        requests.append(request)
        if !responses.isEmpty {
            return responses.removeFirst()
        }
        return RuntimeTurnResult(
            text: "response from \(request.agent.id) at \(request.attachmentPath)",
            sessionID: "session-\(request.agent.id)",
            model: request.agent.model
        )
    }
}

private actor TranscriptChangeRecorder {
    var counts: [Int] = []

    func record(_ count: Int) {
        counts.append(count)
    }
}

private actor StopController {
    private var orchestrator: DebateOrchestrator?

    func set(_ orchestrator: DebateOrchestrator) {
        self.orchestrator = orchestrator
    }

    func stop() async {
        await orchestrator?.stop()
    }
}

private actor FileWritingAdapter: RuntimeAdapter {
    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult {
        let url = request.conversationRoot.appending(path: request.attachmentPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# detail".write(to: url, atomically: true, encoding: .utf8)
        return RuntimeTurnResult(
            text: "I wrote supporting detail at \(request.attachmentPath)",
            sessionID: "session-\(request.agent.id)"
        )
    }
}

private actor MissingFileMentionAdapter: RuntimeAdapter {
    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult {
        RuntimeTurnResult(
            text: "I would use \(request.attachmentPath) if supporting detail were needed.",
            sessionID: "session-\(request.agent.id)"
        )
    }
}

private actor CancellingAdapter: RuntimeAdapter {
    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult {
        throw CancellationError()
    }
}

private actor BlockingAdapter: RuntimeAdapter {
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var didStart = false
    private var didRelease = false

    func waitUntilStarted() async {
        if didStart {
            return
        }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func release() {
        didRelease = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult {
        didStart = true
        startedContinuation?.resume()
        startedContinuation = nil
        if !didRelease {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
        return RuntimeTurnResult(text: "done", sessionID: "session-\(request.agent.id)")
    }
}

private func makeStore(
    agents: [AgentProfile],
    maxRounds: Int = 1,
    supportFolders: [URL] = []
) throws -> ConversationStore {
    let store = ConversationStore(rootURL: try temporaryDirectory())
    try store.create(Conversation(
        id: "c1",
        title: "Debate",
        prompt: "Should we build this?",
        maxRounds: maxRounds,
        agents: agents,
        supportFolders: supportFolders
    ))
    return store
}

private func transcriptEntry(turn: Int, speakerID: String, speakerName: String, text: String) -> TranscriptEntry {
    TranscriptEntry(
        id: "t\(turn)",
        turn: turn,
        round: 1,
        speakerID: speakerID,
        speakerName: speakerName,
        runtime: .claude,
        text: text,
        startedAt: Date(timeIntervalSince1970: TimeInterval(turn)),
        finishedAt: Date(timeIntervalSince1970: TimeInterval(turn + 1))
    )
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "riff-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func agent(_ id: String, _ runtime: RuntimeID) -> AgentProfile {
    AgentProfile(
        id: id,
        name: "Agent \(id)",
        role: "Role \(id)",
        runtime: runtime,
        instructions: "argue"
    )
}

private func fixedClock() -> @Sendable () -> Date {
    { Date(timeIntervalSince1970: 100) }
}
