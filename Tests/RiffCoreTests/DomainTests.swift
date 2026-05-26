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

@Test func roleDraftFromAgentPreservesIdentityForForking() {
    let agent = AgentProfile(
        id: "fox",
        name: "Fox",
        role: "Fox",
        runtime: .codex,
        model: "gpt-5.1",
        reasoning: "high",
        instructions: "Argue the contrarian case.",
        emoji: "🦊"
    )

    let draft = RoleDraft(agent: agent)

    #expect(draft.id == "fox")
    #expect(draft.roleName == "Fox")
    #expect(draft.rolePrompt == "Argue the contrarian case.")
    #expect(draft.runtime == .codex)
    #expect(draft.model == "gpt-5.1")
    #expect(draft.reasoning == "high")
    #expect(draft.emoji == "🦊")
}

@Test func roleDraftFromAgentRoundTripsBackToAgentProfile() {
    let agent = AgentProfile(
        id: "wolf",
        name: "Wolf",
        role: "Wolf",
        runtime: .claude,
        model: "default",
        reasoning: nil,
        instructions: "Pressure-test every claim.",
        emoji: "🐺"
    )

    let restored = RoleDraft(agent: agent).agentProfile(index: 1)

    #expect(restored == agent)
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

@Test func roleDraftAgentNameAliasPersistsEditedNameToAgentProfile() {
    var draft = RoleDraft(
        id: "role-1",
        roleName: "Default",
        rolePrompt: "Pressure-test the threat model.",
        runtime: .claude
    )

    draft.agentName = "Custom Analyst"
    let agent = draft.agentProfile(index: 1)

    #expect(draft.roleName == "Custom Analyst")
    #expect(agent.name == "Custom Analyst")
    #expect(agent.role == "Custom Analyst")
}
