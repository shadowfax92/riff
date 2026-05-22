import Foundation
import Testing
@testable import RiffCore

@Test func bootstrapCreatesPromptAndAgentsWithoutOverwriting() throws {
    let root = try temporaryDirectory()
    let paths = RiffPaths(homeURL: root)
    let store = ConfigStore(paths: paths)

    try store.bootstrap()
    try "custom prompt".write(to: store.promptURL, atomically: true, encoding: .utf8)
    try store.bootstrap()

    #expect(try store.readBasePrompt() == "custom prompt")
    #expect(try store.readAgents().map(\.runtime) == [.claude, .codex])
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

@Test func markdownFilesAreWrittenAndListed() throws {
    let store = ConversationStore(rootURL: try temporaryDirectory())
    try store.create(sampleConversation())

    let file = try store.writeMarkdownFile(relativePath: "files/turn-001.critic.codex.md", contents: "# Details")

    #expect(file.relativePath == "files/turn-001.critic.codex.md")
    #expect(try store.readTextFile(relativePath: file.relativePath) == "# Details\n")
    #expect(try store.listMarkdownFiles().map(\.relativePath) == [file.relativePath])
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
