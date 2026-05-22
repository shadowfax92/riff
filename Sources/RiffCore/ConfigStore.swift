import Foundation

public struct ConfigStore: Sendable {
    public let paths: RiffPaths

    public init(paths: RiffPaths = RiffPaths()) {
        self.paths = paths
    }

    public var promptURL: URL {
        paths.configsURL.appending(path: "prompt.md")
    }

    public var agentsURL: URL {
        paths.configsURL.appending(path: "agents.json")
    }

    public var recentConversationsURL: URL {
        paths.configsURL.appending(path: "recent-conversations.json")
    }

    /// Creates the baseline Riff config files used by new debates while
    /// preserving any user-edited prompt or agent profiles.
    public func bootstrap() throws {
        try FileManager.default.createDirectory(at: paths.configsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.conversationsURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: promptURL.path) {
            try Self.defaultPrompt.write(to: promptURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: agentsURL.path) {
            try RiffJSON.write(Self.defaultAgents, to: agentsURL)
        }
        if !FileManager.default.fileExists(atPath: recentConversationsURL.path) {
            try RiffJSON.write([ConversationLocation](), to: recentConversationsURL)
        }
    }

    public func readBasePrompt() throws -> String {
        try String(contentsOf: promptURL, encoding: .utf8)
    }

    public func readAgents() throws -> [AgentProfile] {
        try RiffJSON.read([AgentProfile].self, from: agentsURL)
    }

    public func readRecentConversations() throws -> [ConversationLocation] {
        if !FileManager.default.fileExists(atPath: recentConversationsURL.path) {
            return []
        }
        return try RiffJSON.read([ConversationLocation].self, from: recentConversationsURL)
    }

    public func rememberConversation(_ location: ConversationLocation) throws {
        var locations = try readRecentConversations()
        locations.removeAll { $0.id == location.id || $0.url == location.url }
        locations.insert(location, at: 0)
        try RiffJSON.write(locations, to: recentConversationsURL)
    }

    public static let defaultPrompt = """
    # Riff Debate Baseline

    You are participating in a multi-agent debate in Riff. Make a clear argument of roughly 280 words. Be direct, specific, and responsive to the other participants.

    If you need supporting detail beyond the chat argument, write it to the provided markdown attachment path using your file tools, then mention that relative path in your response. Do not paste long appendices into the chat bubble.
    """

    public static let defaultAgents: [AgentProfile] = [
        AgentProfile(
            id: "claude-advocate",
            name: "Claude Advocate",
            role: "Advocate",
            runtime: .claude,
            model: "sonnet",
            instructions: "Argue for the strongest version of the proposal while acknowledging tradeoffs."
        ),
        AgentProfile(
            id: "codex-critic",
            name: "Codex Critic",
            role: "Critic",
            runtime: .codex,
            model: "default",
            reasoning: "medium",
            instructions: "Probe assumptions, implementation risk, and missing evidence. Be precise rather than contrarian."
        ),
    ]
}
