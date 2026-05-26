import Foundation

public enum RuntimeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude
    case codex

    public var id: String { rawValue }
}

public enum ConversationStatus: String, Codable, Sendable {
    case idle
    case running
    case stopped
}

public struct AgentProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var role: String
    public var runtime: RuntimeID
    public var model: String
    public var reasoning: String?
    public var instructions: String
    public var emoji: String?

    public init(
        id: String,
        name: String,
        role: String,
        runtime: RuntimeID,
        model: String = "default",
        reasoning: String? = nil,
        instructions: String,
        emoji: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.runtime = runtime
        self.model = model
        self.reasoning = reasoning
        self.instructions = instructions
        self.emoji = emoji
    }
}

public struct RoleDraft: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var roleName: String
    public var rolePrompt: String
    public var runtime: RuntimeID
    public var model: String
    public var reasoning: String?
    public var emoji: String?

    public init(
        id: String,
        roleName: String,
        rolePrompt: String,
        runtime: RuntimeID,
        model: String = "default",
        reasoning: String? = nil,
        emoji: String? = nil
    ) {
        self.id = id
        self.roleName = roleName
        self.rolePrompt = rolePrompt
        self.runtime = runtime
        self.model = model
        self.reasoning = reasoning
        self.emoji = emoji
    }

    /// Rehydrates an editable role draft from a persisted agent profile —
    /// the inverse of `agentProfile(index:)`. Used when forking a
    /// conversation so the New Riff sheet opens pre-filled with its roles.
    /// The agent's id is preserved so the fork keeps the same avatar colors.
    public init(agent: AgentProfile) {
        self.init(
            id: agent.id,
            roleName: agent.name,
            rolePrompt: agent.instructions,
            runtime: agent.runtime,
            model: agent.model,
            reasoning: agent.reasoning,
            emoji: agent.emoji
        )
    }

    public var isValid: Bool {
        !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !rolePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Converts an on-the-fly role into the persisted agent profile used by
    /// conversations and runtime adapters.
    public func agentProfile(index: Int) -> AgentProfile {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructions = rolePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanReasoning = reasoning?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AgentProfile(
            id: id.isEmpty ? "role-\(index)" : id,
            name: name.isEmpty ? "Role \(index)" : name,
            role: name.isEmpty ? "Role \(index)" : name,
            runtime: runtime,
            model: cleanModel.isEmpty ? "default" : cleanModel,
            reasoning: cleanReasoning?.isEmpty == true ? nil : cleanReasoning,
            instructions: instructions,
            emoji: emoji
        )
    }
}

/// Live snapshot of the currently executing agent turn. Drives the
/// "thinking…" indicator in the chat pane while a CLI is mid-flight; nil
/// when no turn is in progress.
public struct ActiveTurnState: Equatable, Sendable {
    public var agent: AgentProfile
    public var turn: Int
    public var startedAt: Date
    public var events: [String]

    public init(agent: AgentProfile, turn: Int, startedAt: Date, events: [String] = []) {
        self.agent = agent
        self.turn = turn
        self.startedAt = startedAt
        self.events = events
    }
}

public struct Conversation: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var prompt: String
    public var createdAt: Date
    public var status: ConversationStatus
    public var maxRounds: Int
    public var agents: [AgentProfile]
    public var supportFolders: [URL]

    public init(
        id: String,
        title: String,
        prompt: String,
        createdAt: Date = Date(),
        status: ConversationStatus = .idle,
        maxRounds: Int = 1,
        agents: [AgentProfile],
        supportFolders: [URL] = []
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.createdAt = createdAt
        self.status = status
        self.maxRounds = max(1, maxRounds)
        self.agents = agents
        self.supportFolders = supportFolders
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case prompt
        case createdAt
        case status
        case maxRounds
        case agents
        case supportFolders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        prompt = try container.decode(String.self, forKey: .prompt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(ConversationStatus.self, forKey: .status)
        maxRounds = max(1, try container.decode(Int.self, forKey: .maxRounds))
        agents = try container.decode([AgentProfile].self, forKey: .agents)
        supportFolders = try container.decodeIfPresent([URL].self, forKey: .supportFolders) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(status, forKey: .status)
        try container.encode(maxRounds, forKey: .maxRounds)
        try container.encode(agents, forKey: .agents)
        try container.encode(supportFolders, forKey: .supportFolders)
    }
}

public struct TranscriptAttachment: Codable, Equatable, Identifiable, Sendable {
    public var id: String { path }
    public var path: String

    public init(path: String) {
        self.path = path
    }
}

public struct TranscriptEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var turn: Int
    public var round: Int
    public var speakerID: String
    public var speakerName: String
    public var runtime: RuntimeID?
    public var text: String
    public var startedAt: Date
    public var finishedAt: Date
    public var sessionID: String?
    public var attachments: [TranscriptAttachment]
    public var warning: String?
    public var error: String?

    public init(
        id: String,
        turn: Int,
        round: Int,
        speakerID: String,
        speakerName: String,
        runtime: RuntimeID? = nil,
        text: String,
        startedAt: Date,
        finishedAt: Date,
        sessionID: String? = nil,
        attachments: [TranscriptAttachment] = [],
        warning: String? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.turn = turn
        self.round = round
        self.speakerID = speakerID
        self.speakerName = speakerName
        self.runtime = runtime
        self.text = text
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.sessionID = sessionID
        self.attachments = attachments
        self.warning = warning
        self.error = error
    }
}

/// Per-agent runtime state used to resume CLI sessions and avoid replaying
/// transcript context that the agent has already seen.
public struct AgentSession: Codable, Equatable, Sendable {
    public var sessionID: String?
    public var model: String
    public var lastUsedAt: Date?
    public var lastContextTurn: Int

    public init(sessionID: String? = nil, model: String = "default", lastUsedAt: Date? = nil, lastContextTurn: Int = 0) {
        self.sessionID = sessionID
        self.model = model
        self.lastUsedAt = lastUsedAt
        self.lastContextTurn = max(0, lastContextTurn)
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID
        case model
        case lastUsedAt
        case lastContextTurn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? "default"
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        lastContextTurn = max(0, try container.decodeIfPresent(Int.self, forKey: .lastContextTurn) ?? 0)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encode(model, forKey: .model)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(lastContextTurn, forKey: .lastContextTurn)
    }
}

public struct ConversationLocation: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var url: URL

    public init(id: String, url: URL) {
        self.id = id
        self.url = url
    }
}

public struct ConversationFile: Codable, Equatable, Identifiable, Sendable {
    public var id: String { relativePath }
    public var relativePath: String
    public var name: String
    public var modifiedAt: Date?

    public init(relativePath: String, name: String, modifiedAt: Date? = nil) {
        self.relativePath = relativePath
        self.name = name
        self.modifiedAt = modifiedAt
    }
}
