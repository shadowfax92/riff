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

@Test func selectionChangeScrollsChatToBottom() {
    #expect(ChatScrollPolicy.target(for: .selectedConversationChanged) == .bottom)
}
