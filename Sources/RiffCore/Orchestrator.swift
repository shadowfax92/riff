import Foundation

public enum DebateOrchestratorError: Error, Equatable {
    case noAgents
    case missingAdapter(RuntimeID)
}

public actor DebateOrchestrator {
    private let store: ConversationStore
    private let adapters: [RuntimeID: any RuntimeAdapter]
    private let baselinePrompt: String
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> String
    private let onTurnStart: @Sendable (AgentProfile, Int) -> Void
    private let onTurnEvent: @Sendable (RuntimeEvent) -> Void
    private let onTurnEnd: @Sendable () -> Void
    private let onTranscriptChange: @Sendable () async -> Void
    private var queuedUserMessages: [String] = []
    private var shouldStop = false

    public init(
        store: ConversationStore,
        adapters: [RuntimeID: any RuntimeAdapter],
        baselinePrompt: String,
        now: @escaping @Sendable () -> Date = Date.init,
        makeID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
        onTurnStart: @escaping @Sendable (AgentProfile, Int) -> Void = { _, _ in },
        onTurnEvent: @escaping @Sendable (RuntimeEvent) -> Void = { _ in },
        onTurnEnd: @escaping @Sendable () -> Void = { },
        onTranscriptChange: @escaping @Sendable () async -> Void = { }
    ) {
        self.store = store
        self.adapters = adapters
        self.baselinePrompt = baselinePrompt
        self.now = now
        self.makeID = makeID
        self.onTurnStart = onTurnStart
        self.onTurnEvent = onTurnEvent
        self.onTurnEnd = onTurnEnd
        self.onTranscriptChange = onTranscriptChange
    }

    public func queueUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        queuedUserMessages.append(trimmed)
    }

    public func stop() {
        shouldStop = true
    }

    /// Runs the conversation turn loop until all configured rounds complete
    /// or a stop request lands; stop never interrupts an in-flight CLI turn.
    @discardableResult
    public func run() async throws -> [TranscriptEntry] {
        shouldStop = false

        var conversation = try store.readConversation()
        guard !conversation.agents.isEmpty else {
            throw DebateOrchestratorError.noAgents
        }
        conversation.status = .running
        try store.updateConversation(conversation)
        defer {
            if var finalConversation = try? store.readConversation() {
                finalConversation.status = .stopped
                try? store.updateConversation(finalConversation)
            }
        }

        var transcript = try store.readTranscript()
        var agentTurns = transcript.filter { $0.speakerID != "user" }.count
        let maxAgentTurns = conversation.maxRounds * conversation.agents.count
        while agentTurns < maxAgentTurns {
            for text in drainQueuedUserMessages() {
                let entry = userEntry(text: text, turn: transcript.count + 1)
                try store.appendTranscript(entry)
                transcript.append(entry)
                await onTranscriptChange()
            }
            if stopRequested() {
                break
            }

            let agent = conversation.agents[agentTurns % conversation.agents.count]
            guard let adapter = adapters[agent.runtime] else {
                throw DebateOrchestratorError.missingAdapter(agent.runtime)
            }

            let turn = transcript.count + 1
            let attachmentPath = RiffPathFormat.relativeDetailPath(turn: turn, role: agent.role, runtime: agent.runtime)
            let filesBefore = Set((try store.listMarkdownFiles()).map(\.relativePath))
            let started = now()
            let session = try store.readAgentSession(agentID: agent.id)
            let contextCursor = max(session.lastContextTurn, transcript.map(\.turn).max() ?? 0)
            onTurnStart(agent, turn)
            let turnEvent = onTurnEvent
            do {
                let result = try await adapter.runTurn(
                    RuntimeTurnRequest(
                        agent: agent,
                        conversationRoot: store.rootURL,
                        sessionID: session.sessionID,
                        baselinePrompt: baselinePrompt,
                        conversationPrompt: conversation.prompt,
                        context: composeContext(transcript, for: agent, after: session.lastContextTurn),
                        attachmentPath: attachmentPath
                    ),
                    emit: { event in turnEvent(event) }
                )
                let parsed = TurnResponseParser.parse(result.text)
                let attachments = try mergedAttachments(parsed: parsed.attachments, filesBefore: filesBefore)
                let finished = now()
                let entry = TranscriptEntry(
                    id: makeID(),
                    turn: turn,
                    round: agentTurns / conversation.agents.count + 1,
                    speakerID: agent.id,
                    speakerName: agent.name,
                    runtime: agent.runtime,
                    text: parsed.text,
                    startedAt: started,
                    finishedAt: finished,
                    sessionID: result.sessionID,
                    attachments: attachments,
                    warning: parsed.warning
                )
                try store.appendTranscript(entry)
                transcript.append(entry)
                try store.writeAgentSession(
                    AgentSession(
                        sessionID: result.sessionID ?? session.sessionID,
                        model: result.model,
                        lastUsedAt: finished,
                        lastContextTurn: contextCursor
                    ),
                    agentID: agent.id
                )
                onTurnEnd()
                await onTranscriptChange()
            } catch {
                let finished = now()
                let entry = TranscriptEntry(
                    id: makeID(),
                    turn: turn,
                    round: agentTurns / conversation.agents.count + 1,
                    speakerID: agent.id,
                    speakerName: agent.name,
                    runtime: agent.runtime,
                    text: "",
                    startedAt: started,
                    finishedAt: finished,
                    error: String(describing: error)
                )
                try store.appendTranscript(entry)
                transcript.append(entry)
                onTurnEnd()
                await onTranscriptChange()
                throw error
            }
            agentTurns += 1
        }
        return transcript
    }

    private func drainQueuedUserMessages() -> [String] {
        let messages = queuedUserMessages
        queuedUserMessages.removeAll()
        return messages
    }

    private func stopRequested() -> Bool {
        shouldStop
    }

    private func userEntry(text: String, turn: Int) -> TranscriptEntry {
        let date = now()
        return TranscriptEntry(
            id: makeID(),
            turn: turn,
            round: 0,
            speakerID: "user",
            speakerName: "You",
            text: text,
            startedAt: date,
            finishedAt: date
        )
    }

    /// Builds the transcript slice for one agent turn. The CLI session already
    /// carries that agent's own history, so prompts only include newer non-self entries.
    private func composeContext(_ transcript: [TranscriptEntry], for agent: AgentProfile, after cursor: Int) -> String {
        transcript.filter { entry in
            entry.turn > cursor && entry.speakerID != agent.id
        }
        .map { entry in
            var line = "\(entry.speakerName): \(entry.text)"
            if !entry.attachments.isEmpty {
                line += "\nAttachments: " + entry.attachments.map(\.path).joined(separator: ", ")
            }
            return line
        }
        .joined(separator: "\n\n")
    }

    private func mergedAttachments(parsed: [TranscriptAttachment], filesBefore: Set<String>) throws -> [TranscriptAttachment] {
        let filesAfter = Set((try store.listMarkdownFiles()).map(\.relativePath))
        let created = filesAfter.subtracting(filesBefore).sorted().map(TranscriptAttachment.init(path:))
        let existing = parsed.filter { filesAfter.contains($0.path) }
        var seen = Set<String>()
        return (existing + created).filter { seen.insert($0.path).inserted }
    }
}
