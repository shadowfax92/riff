import Foundation
import Testing
@testable import RiffApp

@Test func conversationWindowRouteRoundTripsConversationID() throws {
    let route = ConversationWindowRoute(conversationID: "conversation-123")

    let data = try JSONEncoder().encode(route)
    let decoded = try JSONDecoder().decode(ConversationWindowRoute.self, from: data)

    #expect(decoded == route)
    #expect(decoded.id == "conversation-123")
}
