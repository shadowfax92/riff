import Foundation
import Testing
@testable import RiffCore

@Test func defaultPathsResolveUnderRiffRoot() {
    let paths = RiffPaths(homeURL: URL(fileURLWithPath: "/tmp/home", isDirectory: true))

    #expect(paths.configURL.path == "/tmp/home/.riff/config")
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

@Test func roleDraftCreatesAgentProfileFromRoleNameAndPrompt() {
    let draft = RoleDraft(
        id: "role-1",
        roleName: "Security",
        rolePrompt: "Pressure-test the threat model.",
        runtime: .codex,
        model: "gpt-5",
        reasoning: "high"
    )

    let agent = draft.agentProfile(index: 1)

    #expect(agent.id == "role-1")
    #expect(agent.name == "Security")
    #expect(agent.role == "Security")
    #expect(agent.runtime == .codex)
    #expect(agent.model == "gpt-5")
    #expect(agent.reasoning == "high")
    #expect(agent.instructions == "Pressure-test the threat model.")
}

@Test func roleDraftWithoutNameOrPromptIsInvalid() {
    let draft = RoleDraft(
        id: "role-1",
        roleName: " ",
        rolePrompt: " ",
        runtime: .claude
    )

    #expect(!draft.isValid)
}
