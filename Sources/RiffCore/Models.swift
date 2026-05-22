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

    public init(
        id: String,
        name: String,
        role: String,
        runtime: RuntimeID,
        model: String = "default",
        reasoning: String? = nil,
        instructions: String
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.runtime = runtime
        self.model = model
        self.reasoning = reasoning
        self.instructions = instructions
    }
}

public struct RoleDraft: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var roleName: String
    public var rolePrompt: String
    public var runtime: RuntimeID
    public var model: String
    public var reasoning: String?

    public init(
        id: String,
        roleName: String,
        rolePrompt: String,
        runtime: RuntimeID,
        model: String = "default",
        reasoning: String? = nil
    ) {
        self.id = id
        self.roleName = roleName
        self.rolePrompt = rolePrompt
        self.runtime = runtime
        self.model = model
        self.reasoning = reasoning
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
            instructions: instructions
        )
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

    public init(
        id: String,
        title: String,
        prompt: String,
        createdAt: Date = Date(),
        status: ConversationStatus = .idle,
        maxRounds: Int = 1,
        agents: [AgentProfile]
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.createdAt = createdAt
        self.status = status
        self.maxRounds = max(1, maxRounds)
        self.agents = agents
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

public struct AgentSession: Codable, Equatable, Sendable {
    public var sessionID: String?
    public var model: String
    public var lastUsedAt: Date?

    public init(sessionID: String? = nil, model: String = "default", lastUsedAt: Date? = nil) {
        self.sessionID = sessionID
        self.model = model
        self.lastUsedAt = lastUsedAt
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
