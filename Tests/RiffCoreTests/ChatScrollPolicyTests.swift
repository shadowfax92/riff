import Testing
@testable import RiffCore

@Test func firstAgentAppendScrollsChatToTop() {
    let target = ChatScrollPolicy.target(
        for: .transcriptAppended(previousCount: 0, currentCount: 1, latestSpeakerID: "fox")
    )

    #expect(target == .top)
}

@Test func laterAgentAppendDoesNotForceChatToBottom() {
    let target = ChatScrollPolicy.target(
        for: .transcriptAppended(previousCount: 1, currentCount: 2, latestSpeakerID: "fox")
    )

    #expect(target == nil)
}

@Test func userAppendScrollsChatToBottom() {
    let target = ChatScrollPolicy.target(
        for: .transcriptAppended(previousCount: 0, currentCount: 1, latestSpeakerID: "user")
    )

    #expect(target == .bottom)
}

@Test func agentOnlySelectionChangeScrollsChatToTop() {
    #expect(ChatScrollPolicy.target(for: .selectedConversationChanged(hasUserMessages: false)) == .top)
}

@Test func humanSelectionChangeScrollsChatToBottom() {
    #expect(ChatScrollPolicy.target(for: .selectedConversationChanged(hasUserMessages: true)) == .bottom)
}

@Test func scrollContainerIdentityChangesWithSelectedConversation() {
    let first = ChatScrollPolicy.containerIdentity(selectedConversationID: "one")
    let second = ChatScrollPolicy.containerIdentity(selectedConversationID: "two")

    #expect(first != second)
}

@Test func scrollContainerIdentityIsStableWithoutSelection() {
    let first = ChatScrollPolicy.containerIdentity(selectedConversationID: nil)
    let second = ChatScrollPolicy.containerIdentity(selectedConversationID: nil)

    #expect(first == second)
}

@Test func agentOnlyDebatesPinSizeChangesToTop() {
    #expect(ChatScrollPolicy.pinsSizeChangesToTop(hasUserMessages: false))
}

@Test func humanChatsUsePlatformSizeChangeAnchor() {
    #expect(!ChatScrollPolicy.pinsSizeChangesToTop(hasUserMessages: true))
}
