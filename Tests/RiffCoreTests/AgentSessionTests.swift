import Foundation
import Testing
@testable import RiffCore

@Test func agentSessionDefaultsContextCursorToZero() {
    #expect(AgentSession().lastContextTurn == 0)
}

@Test func agentSessionDecodesLegacyFilesWithoutContextCursor() throws {
    let data = Data("""
    {
      "lastUsedAt" : "2026-05-22T12:00:00Z",
      "model" : "sonnet",
      "sessionID" : "claude-session"
    }
    """.utf8)

    let session = try RiffJSON.decoder.decode(AgentSession.self, from: data)

    #expect(session.sessionID == "claude-session")
    #expect(session.model == "sonnet")
    #expect(session.lastContextTurn == 0)
}

@Test func agentSessionEncodesContextCursor() throws {
    let session = AgentSession(
        sessionID: "codex-session",
        model: "gpt-5",
        lastUsedAt: nil,
        lastContextTurn: 9
    )

    let data = try RiffJSON.encoder.encode(session)
    let decoded = try RiffJSON.decoder.decode(AgentSession.self, from: data)

    #expect(decoded.lastContextTurn == 9)
}
