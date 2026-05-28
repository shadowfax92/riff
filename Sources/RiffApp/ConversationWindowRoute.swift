struct ConversationWindowRoute: Codable, Equatable, Hashable, Identifiable {
    var conversationID: String

    var id: String { conversationID }
}
