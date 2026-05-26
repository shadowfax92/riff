import RiffCore
import Testing
@testable import RiffApp

@Test func additionalRoleDraftCopiesPreviousRuntimeModelAndReasoning() {
    let previous = RoleDraft(
        id: "previous",
        roleName: "Reviewer",
        rolePrompt: "Review sharply.",
        runtime: .codex,
        model: "gpt-5.1",
        reasoning: "high",
        emoji: "R"
    )

    let draft = RoleDraftFactory.additional(after: previous)

    #expect(draft.id != previous.id)
    #expect(draft.runtime == .codex)
    #expect(draft.model == "gpt-5.1")
    #expect(draft.reasoning == "high")
    #expect(draft.rolePrompt == "")
    #expect(!draft.roleName.isEmpty)
    #expect(draft.agentName == draft.roleName)
}

@Test func initialRoleDraftDefaultsToClaudeDefaultModel() {
    let draft = RoleDraftFactory.initial()

    #expect(draft.runtime == .claude)
    #expect(draft.model == "default")
    #expect(draft.reasoning == nil)
    #expect(draft.rolePrompt == "")
    #expect(!draft.roleName.isEmpty)
    #expect(!draft.agentName.isEmpty)
}
