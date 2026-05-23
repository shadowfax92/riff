import Testing
@testable import RiffCore

@Test func agentAppendDoesNotForceChatToBottom() {
    let target = ChatScrollPolicy.target(
        for: .transcriptAppended(previousCount: 0, currentCount: 1, latestSpeakerID: "fox")
    )

    #expect(target == nil)
}

@Test func userAppendScrollsChatToBottom() {
    let target = ChatScrollPolicy.target(
        for: .transcriptAppended(previousCount: 0, currentCount: 1, latestSpeakerID: "user")
    )

    #expect(target == .bottom)
}

@Test func selectionChangeScrollsChatToBottom() {
    #expect(ChatScrollPolicy.target(for: .selectedConversationChanged) == .bottom)
}
