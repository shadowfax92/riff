import Foundation

public struct ConversationStore: Sendable {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public var conversationURL: URL {
        rootURL.appending(path: "conversation.json")
    }

    public var transcriptURL: URL {
        rootURL.appending(path: "transcript.jsonl")
    }

    public var filesURL: URL {
        rootURL.appending(path: "files", directoryHint: .isDirectory)
    }

    public var agentsURL: URL {
        rootURL.appending(path: "agents", directoryHint: .isDirectory)
    }

    public func agentDirectory(agentID: String) -> URL {
        agentsURL.appending(path: agentID, directoryHint: .isDirectory)
    }

    public func agentCWD(agentID: String) -> URL {
        agentDirectory(agentID: agentID).appending(path: "cwd", directoryHint: .isDirectory)
    }

    public func agentSessionURL(agentID: String) -> URL {
        agentDirectory(agentID: agentID).appending(path: "session.json")
    }

    /// Creates the complete on-disk layout for a conversation, including
    /// shared files and per-agent state directories.
    public func create(_ conversation: Conversation) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: agentsURL, withIntermediateDirectories: true)
        for agent in conversation.agents {
            try FileManager.default.createDirectory(at: agentCWD(agentID: agent.id), withIntermediateDirectories: true)
            try RiffJSON.write(agent, to: agentDirectory(agentID: agent.id).appending(path: "agent.json"))
        }
        if !FileManager.default.fileExists(atPath: transcriptURL.path) {
            FileManager.default.createFile(atPath: transcriptURL.path, contents: Data())
        }
        try RiffJSON.write(conversation, to: conversationURL)
    }

    public func readConversation() throws -> Conversation {
        try RiffJSON.read(Conversation.self, from: conversationURL)
    }

    public func updateConversation(_ conversation: Conversation) throws {
        try RiffJSON.write(conversation, to: conversationURL)
    }

    /// Deletes the whole conversation root. App code moves folders to Trash
    /// by default so custom conversation folders are recoverable; tests can
    /// request permanent removal for deterministic temp-directory cleanup.
    public func delete(moveToTrash: Bool = true) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: rootURL.path) else {
            return
        }
        guard fm.fileExists(atPath: conversationURL.path) else {
            throw StoreError.missingConversation(rootURL.path)
        }
        if moveToTrash {
            var trashedURL: NSURL?
            try fm.trashItem(at: rootURL, resultingItemURL: &trashedURL)
        } else {
            try fm.removeItem(at: rootURL)
        }
    }

    public func appendTranscript(_ entry: TranscriptEntry) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let data = try RiffJSON.lineData(entry)
        let handle = try FileHandle(forWritingTo: transcriptURL)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    public func readTranscript() throws -> [TranscriptEntry] {
        if !FileManager.default.fileExists(atPath: transcriptURL.path) {
            return []
        }
        let text = try String(contentsOf: transcriptURL, encoding: .utf8)
        return try text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { try RiffJSON.decoder.decode(TranscriptEntry.self, from: Data($0.utf8)) }
    }

    /// Reads transcript entries for UI presentation, keeping attachment cards
    /// only for markdown files that still exist in the shared files directory.
    public func readTranscriptWithExistingAttachments() throws -> [TranscriptEntry] {
        let existingPaths = Set((try listMarkdownFiles()).map(\.relativePath))
        return try readTranscript().map { entry in
            var filtered = entry
            filtered.attachments = entry.attachments.filter { existingPaths.contains($0.path) }
            return filtered
        }
    }

    public func readAgentSession(agentID: String) throws -> AgentSession {
        let url = agentSessionURL(agentID: agentID)
        if !FileManager.default.fileExists(atPath: url.path) {
            return AgentSession()
        }
        return try RiffJSON.read(AgentSession.self, from: url)
    }

    public func writeAgentSession(_ session: AgentSession, agentID: String) throws {
        try RiffJSON.write(session, to: agentSessionURL(agentID: agentID))
    }

    public func writeMarkdownFile(relativePath: String, contents: String) throws -> ConversationFile {
        let url = try safeRelativeURL(relativePath)
        try RiffJSON.writeText(contents.hasSuffix("\n") ? contents : contents + "\n", to: url)
        return ConversationFile(
            relativePath: relativePath,
            name: url.lastPathComponent,
            modifiedAt: try? modifiedDate(url)
        )
    }

    public func readTextFile(relativePath: String) throws -> String {
        try String(contentsOf: safeRelativeURL(relativePath), encoding: .utf8)
    }

    public func listMarkdownFiles() throws -> [ConversationFile] {
        if !FileManager.default.fileExists(atPath: filesURL.path) {
            return []
        }
        let urls = FileManager.default.enumerator(
            at: filesURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
        )?.compactMap { $0 as? URL } ?? []
        return try urls.compactMap { url in
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values.isRegularFile == true, url.pathExtension.lowercased() == "md" else {
                return nil
            }
            return ConversationFile(
                relativePath: relativePath(for: url),
                name: url.lastPathComponent,
                modifiedAt: values.contentModificationDate
            )
        }
        .sorted { lhs, rhs in
            (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        }
    }

    public func markdownExists(relativePath: String) -> Bool {
        (try? safeRelativeURL(relativePath)).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    private func safeRelativeURL(_ relativePath: String) throws -> URL {
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: true)
        guard !parts.isEmpty, !parts.contains("..") else {
            throw StoreError.invalidRelativePath(relativePath)
        }
        return parts.reduce(rootURL) { partial, part in
            partial.appending(path: String(part))
        }
    }

    private func relativePath(for url: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else {
            return url.lastPathComponent
        }
        return String(path.dropFirst(root.count + 1))
    }

    private func modifiedDate(_ url: URL) throws -> Date? {
        try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

public enum StoreError: Error, Equatable {
    case invalidRelativePath(String)
    case missingConversation(String)
}

public enum RiffJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let lineEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try writeData(data + Data([0x0A]), to: url)
    }

    public static func writeText(_ text: String, to url: URL) throws {
        try writeData(Data(text.utf8), to: url)
    }

    public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try decoder.decode(T.self, from: Data(contentsOf: url))
    }

    public static func lineData<T: Encodable>(_ value: T) throws -> Data {
        try lineEncoder.encode(value) + Data([0x0A])
    }

    private static func writeData(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tmp = directory.appending(path: ".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }
}
