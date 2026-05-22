import Foundation
import Testing
@testable import RiffCore

@Test func bootstrapCreatesPromptWithoutCreatingFixedAgents() throws {
    let root = try temporaryDirectory()
    let paths = RiffPaths(homeURL: root)
    let store = ConfigStore(paths: paths)

    try store.bootstrap()
    try "custom prompt".write(to: store.basePromptURL, atomically: true, encoding: .utf8)
    try store.writeRuntimeSettings(RuntimeSettings(
        claudePath: "/custom/bin/claude",
        codexPath: "/custom/bin/codex"
    ))
    try store.bootstrap()

    #expect(try store.readBasePrompt() == "custom prompt")
    #expect(try store.readRuntimeSettings().claudePath == "/custom/bin/claude")
    #expect(try store.readRuntimeSettings().codexPath == "/custom/bin/codex")
    #expect(!FileManager.default.fileExists(atPath: paths.configURL.appending(path: "agents.json").path))
}

@Test func bootstrapMigratesLegacyConfigsDirectory() throws {
    let root = try temporaryDirectory()
    let paths = RiffPaths(homeURL: root)
    let fm = FileManager.default
    try fm.createDirectory(at: paths.legacyConfigsURL, withIntermediateDirectories: true)
    let legacyPrompt = paths.legacyConfigsURL.appending(path: "prompt.md")
    try "legacy prompt".write(to: legacyPrompt, atomically: true, encoding: .utf8)

    try ConfigStore(paths: paths).bootstrap()

    #expect(!fm.fileExists(atPath: paths.legacyConfigsURL.path))
    #expect(fm.fileExists(atPath: paths.configURL.appending(path: "base_prompt.md").path))
    #expect(try ConfigStore(paths: paths).readBasePrompt() == "legacy prompt")
}

@Test func writeBasePromptPersistsPrompt() throws {
    let root = try temporaryDirectory()
    let paths = RiffPaths(homeURL: root)
    let store = ConfigStore(paths: paths)

    try store.bootstrap()
    try store.writeBasePrompt("updated prompt")

    #expect(try store.readBasePrompt() == "updated prompt")
}

@Test func creatingConversationWritesExpectedLayout() throws {
    let root = try temporaryDirectory().appending(path: "conversation", directoryHint: .isDirectory)
    let store = ConversationStore(rootURL: root)
    let conversation = sampleConversation()

    try store.create(conversation)

    #expect(FileManager.default.fileExists(atPath: store.conversationURL.path))
    #expect(FileManager.default.fileExists(atPath: store.transcriptURL.path))
    #expect(FileManager.default.fileExists(atPath: store.filesURL.path))
    #expect(FileManager.default.fileExists(atPath: store.agentCWD(agentID: "a1").path))
}

@Test func transcriptAppendsPreserveOrderAcrossReads() throws {
    let store = ConversationStore(rootURL: try temporaryDirectory())
    try store.create(sampleConversation())

    try store.appendTranscript(sampleEntry(turn: 1, text: "first"))
    try store.appendTranscript(sampleEntry(turn: 2, text: "second"))

    #expect(try store.readTranscript().map(\.text) == ["first", "second"])
}

@Test func transcriptReadForDisplayDropsMissingAttachments() throws {
    let store = ConversationStore(rootURL: try temporaryDirectory())
    try store.create(sampleConversation())
    var entry = sampleEntry(turn: 1, text: "detail")
    entry.attachments = [
        TranscriptAttachment(path: "files/missing.md"),
        TranscriptAttachment(path: "files/present.md"),
    ]
    try store.appendTranscript(entry)
    _ = try store.writeMarkdownFile(relativePath: "files/present.md", contents: "# Present")

    let transcript = try store.readTranscriptWithExistingAttachments()

    #expect(transcript.map(\.attachments) == [[TranscriptAttachment(path: "files/present.md")]])
}

@Test func markdownFilesAreWrittenAndListed() throws {
    let store = ConversationStore(rootURL: try temporaryDirectory())
    try store.create(sampleConversation())

    let file = try store.writeMarkdownFile(relativePath: "files/turn-001.critic.codex.md", contents: "# Details")

    #expect(file.relativePath == "files/turn-001.critic.codex.md")
    #expect(try store.readTextFile(relativePath: file.relativePath) == "# Details\n")
    #expect(try store.listMarkdownFiles().map(\.relativePath) == [file.relativePath])
}

@Test func forgettingConversationRemovesMatchingRecentLocation() throws {
    let root = try temporaryDirectory()
    let paths = RiffPaths(homeURL: root)
    let store = ConfigStore(paths: paths)
    try store.bootstrap()
    let first = ConversationLocation(id: "c1", url: paths.defaultConversationURL(id: "c1"))
    let second = ConversationLocation(id: "c2", url: paths.defaultConversationURL(id: "c2"))
    try store.rememberConversation(first)
    try store.rememberConversation(second)

    try store.forgetConversation(first)

    #expect(try store.readRecentConversations() == [second])
}

@Test func deletingConversationRemovesConversationDirectory() throws {
    let root = try temporaryDirectory()
    let store = ConversationStore(rootURL: root)
    try store.create(sampleConversation())

    try store.delete(moveToTrash: false)

    #expect(!FileManager.default.fileExists(atPath: root.path))
}

private func sampleConversation() -> Conversation {
    Conversation(
        id: "c1",
        title: "Test",
        prompt: "Debate this",
        createdAt: Date(timeIntervalSince1970: 0),
        agents: [
            AgentProfile(id: "a1", name: "A", role: "Advocate", runtime: .claude, instructions: "go")
        ]
    )
}

private func sampleEntry(turn: Int, text: String) -> TranscriptEntry {
    TranscriptEntry(
        id: "t\(turn)",
        turn: turn,
        round: 1,
        speakerID: "a1",
        speakerName: "A",
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
