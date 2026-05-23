import Foundation
import Testing
@testable import RiffCore

@Test func runRegistryScopesRunningAndActiveTurnToConversationID() {
    var registry = ConversationRunRegistry()
    let agent = AgentProfile(id: "a1", name: "A", role: "A", runtime: .claude, instructions: "go")
    let turn = ActiveTurnState(agent: agent, turn: 1, startedAt: Date(timeIntervalSince1970: 0))

    registry.start(conversationID: "c1")
    registry.setActiveTurn(turn, conversationID: "c1")

    #expect(registry.isRunning(conversationID: "c1"))
    #expect(!registry.isRunning(conversationID: "c2"))
    #expect(registry.activeTurn(conversationID: "c1") == turn)
    #expect(registry.activeTurn(conversationID: "c2") == nil)
}

@Test func runRegistryFinishesOnlyTheRequestedConversation() {
    var registry = ConversationRunRegistry()
    registry.start(conversationID: "c1")
    registry.start(conversationID: "c2")

    registry.finish(conversationID: "c1")

    #expect(!registry.isRunning(conversationID: "c1"))
    #expect(registry.isRunning(conversationID: "c2"))
}
