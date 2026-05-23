public enum ChatScrollTarget: Equatable, Sendable {
    case top
    case bottom
}

public enum ChatScrollEvent: Equatable, Sendable {
    case selectedConversationChanged(hasUserMessages: Bool)
    case transcriptAppended(previousCount: Int, currentCount: Int, latestSpeakerID: String?)
}

public enum ChatScrollPolicy {
    /// Provides a stable SwiftUI identity for the chat scroll container.
    /// Changing it when conversations change prevents a reused ScrollView
    /// from carrying the previous conversation's viewport offset forward.
    public static func containerIdentity(selectedConversationID: String?) -> String {
        guard let selectedConversationID else {
            return "conversation:none"
        }
        return "conversation:\(selectedConversationID)"
    }

    /// Agent-only debates start with CLI output rather than a human message.
    /// While those runs are in flight, new committed rows and the live thinking
    /// row should keep the top context visible instead of inheriting a lower
    /// viewport offset.
    public static func pinsSizeChangesToTop(hasUserMessages: Bool) -> Bool {
        !hasUserMessages
    }

    /// Decides when the chat should jump to the latest row. Agent turns do not
    /// force-scroll because that hides early debate context during fresh runs.
    public static func target(for event: ChatScrollEvent) -> ChatScrollTarget? {
        switch event {
        case .selectedConversationChanged(let hasUserMessages):
            return hasUserMessages ? .bottom : .top
        case .transcriptAppended(let previousCount, let currentCount, let latestSpeakerID):
            guard currentCount > previousCount else {
                return nil
            }
            if previousCount == 0, latestSpeakerID != "user" {
                return .top
            }
            guard latestSpeakerID == "user" else {
                return nil
            }
            return .bottom
        }
    }
}
