import Foundation

public struct ConfigStore: Sendable {
    public let paths: RiffPaths

    public init(paths: RiffPaths = RiffPaths()) {
        self.paths = paths
    }

    public var basePromptURL: URL {
        paths.configURL.appending(path: "base_prompt.md")
    }

    public var recentConversationsURL: URL {
        paths.configURL.appending(path: "recent-conversations.json")
    }

    public var runtimeSettingsURL: URL {
        paths.configURL.appending(path: "runtime.json")
    }

    /// Creates the baseline Riff config files used by new debates while
    /// preserving the user-edited shared prompt. Also migrates the old
    /// `~/.riff/configs/prompt.md` layout into `~/.riff/config/base_prompt.md`
    /// so users who customized the prior file don't lose their edits.
    public func bootstrap() throws {
        let fm = FileManager.default
        try migrateLegacyLayout()
        try fm.createDirectory(at: paths.configURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: paths.conversationsURL, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: basePromptURL.path) {
            try Self.defaultPrompt.write(to: basePromptURL, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: recentConversationsURL.path) {
            try RiffJSON.write([ConversationLocation](), to: recentConversationsURL)
        }
        if !fm.fileExists(atPath: runtimeSettingsURL.path) {
            try writeRuntimeSettings(RuntimeSettings())
        }
    }

    public func readBasePrompt() throws -> String {
        try String(contentsOf: basePromptURL, encoding: .utf8)
    }

    /// Persists the shared baseline prompt used when building future agent
    /// prompts from the app's config editor.
    public func writeBasePrompt(_ prompt: String) throws {
        try RiffJSON.writeText(prompt, to: basePromptURL)
    }

    public func readRuntimeSettings() throws -> RuntimeSettings {
        if !FileManager.default.fileExists(atPath: runtimeSettingsURL.path) {
            return RuntimeSettings()
        }
        return try RiffJSON.read(RuntimeSettings.self, from: runtimeSettingsURL)
    }

    public func writeRuntimeSettings(_ settings: RuntimeSettings) throws {
        try RiffJSON.write(settings, to: runtimeSettingsURL)
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

    /// Removes a conversation from the recent list after its on-disk folder
    /// has been deleted or moved away.
    public func forgetConversation(_ location: ConversationLocation) throws {
        var locations = try readRecentConversations()
        locations.removeAll { $0.id == location.id || $0.url == location.url }
        try RiffJSON.write(locations, to: recentConversationsURL)
    }

    private func migrateLegacyLayout() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: paths.legacyConfigsURL.path),
           !fm.fileExists(atPath: paths.configURL.path) {
            try fm.moveItem(at: paths.legacyConfigsURL, to: paths.configURL)
        }
        let legacyPrompt = paths.configURL.appending(path: "prompt.md")
        if fm.fileExists(atPath: legacyPrompt.path),
           !fm.fileExists(atPath: basePromptURL.path) {
            try fm.moveItem(at: legacyPrompt, to: basePromptURL)
        }
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
