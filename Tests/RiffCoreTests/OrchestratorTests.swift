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

private actor RecordingAdapter: RuntimeAdapter {
    var requests: [RuntimeTurnRequest] = []

    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult {
        requests.append(request)
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

private func makeStore(agents: [AgentProfile], maxRounds: Int = 1) throws -> ConversationStore {
    let store = ConversationStore(rootURL: try temporaryDirectory())
    try store.create(Conversation(
        id: "c1",
        title: "Debate",
        prompt: "Should we build this?",
        maxRounds: maxRounds,
        agents: agents
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
