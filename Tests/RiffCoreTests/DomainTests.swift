import Foundation
import Testing
@testable import RiffCore

@Test func defaultPathsResolveUnderRiffRoot() {
    let paths = RiffPaths(homeURL: URL(fileURLWithPath: "/tmp/home", isDirectory: true))

    #expect(paths.configsURL.path == "/tmp/home/.riff/configs")
    #expect(paths.conversationsURL.path == "/tmp/home/.riff/conversations")
}

@Test func defaultConversationURLUsesConversationID() {
    let paths = RiffPaths(homeURL: URL(fileURLWithPath: "/tmp/home", isDirectory: true))

    #expect(paths.defaultConversationURL(id: "abc-123").path == "/tmp/home/.riff/conversations/abc-123")
}

@Test func detailFilenamesAreTurnNumberedAndRuntimeScoped() {
    let filename = RiffPathFormat.detailFilename(turn: 3, role: "Lead Critic", runtime: .claude)

    #expect(filename == "turn-003.lead-critic.claude.md")
}
