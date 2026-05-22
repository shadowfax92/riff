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

private actor RecordingAdapter: RuntimeAdapter {
    var requests: [RuntimeTurnRequest] = []

    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult {
        requests.append(request)
        return RuntimeTurnResult(text: "response from \(request.agent.id)", sessionID: "session-\(request.agent.id)", model: request.agent.model)
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

private func makeStore(agents: [AgentProfile]) throws -> ConversationStore {
    let store = ConversationStore(rootURL: try temporaryDirectory())
    try store.create(Conversation(
        id: "c1",
        title: "Debate",
        prompt: "Should we build this?",
        maxRounds: 1,
        agents: agents
    ))
    return store
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
