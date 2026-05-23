public enum ChatScrollTarget: Equatable, Sendable {
    case bottom
}

public enum ChatScrollEvent: Equatable, Sendable {
    case selectedConversationChanged
    case transcriptAppended(previousCount: Int, currentCount: Int, latestSpeakerID: String?)
}

public enum ChatScrollPolicy {
    /// Decides when the chat should jump to the latest row. Agent turns do not
    /// force-scroll because that hides early debate context during fresh runs.
    public static func target(for event: ChatScrollEvent) -> ChatScrollTarget? {
        switch event {
        case .selectedConversationChanged:
            return .bottom
        case .transcriptAppended(let previousCount, let currentCount, let latestSpeakerID):
            guard currentCount > previousCount, latestSpeakerID == "user" else {
                return nil
            }
            return .bottom
        }
    }
}
