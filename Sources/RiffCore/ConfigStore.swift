import Foundation

public struct ConfigStore: Sendable {
    public let paths: RiffPaths

    public init(paths: RiffPaths = RiffPaths()) {
        self.paths = paths
    }

    public var promptURL: URL {
        paths.configsURL.appending(path: "prompt.md")
    }

    public var recentConversationsURL: URL {
        paths.configsURL.appending(path: "recent-conversations.json")
    }

    /// Creates the baseline Riff config files used by new debates while
    /// preserving the user-edited shared prompt.
    public func bootstrap() throws {
        try FileManager.default.createDirectory(at: paths.configsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.conversationsURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: promptURL.path) {
            try Self.defaultPrompt.write(to: promptURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: recentConversationsURL.path) {
            try RiffJSON.write([ConversationLocation](), to: recentConversationsURL)
        }
    }

    public func readBasePrompt() throws -> String {
        try String(contentsOf: promptURL, encoding: .utf8)
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
    # Multi-Agent Debate Baseline

    You are participating in a Riff multi-agent debate. The user supplies the question, and each agent receives a ROLE_NAME and ROLE_PROMPT. Your job is to surface the truth of the question, not to force consensus or protect your original stance.

    Read the debate prompt, your role prompt, prior chat turns, and any referenced markdown files before answering. Cite specifics from the prompt, prior arguments, local files, documentation, or research. Do not argue from vague industry claims.

    Turn format:
    - Start by steelmanning the strongest recent opposing point in 1-2 sentences when there is one.
    - Make one sharp push in roughly 280 words.
    - Include concrete evidence: a product, doc, file path, observed behavior, or clearly marked experience.
    - End with one specific question or pressure point for the other agents.

    Rules:
    - Be direct, concise, and concrete. Short sentences are fine.
    - No repeat angles. If a point was already made, advance it or attack it from a new vector.
    - Call out bad reasoning by name when useful: false dichotomy, cherry-picked data, scope creep, moving goalposts, equivocation.
    - Truth beats stance. If another agent changes your mind, say exactly what changed.
    - Stay on the user's question.

    If you need supporting detail beyond the chat argument, write it to the provided markdown attachment path using your file tools, then mention that relative path in your response. Do not paste long appendices into the chat bubble.
    """
}
