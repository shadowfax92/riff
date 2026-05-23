import Foundation

/// Tracks live debate state by conversation id so UI selection never leaks
/// one conversation's process state into another conversation.
public struct ConversationRunRegistry: Equatable, Sendable {
    public private(set) var runningIDs: Set<String>
    public private(set) var activeTurns: [String: ActiveTurnState]

    public init(runningIDs: Set<String> = [], activeTurns: [String: ActiveTurnState] = [:]) {
        self.runningIDs = runningIDs
        self.activeTurns = activeTurns
    }

    public mutating func start(conversationID: String) {
        runningIDs.insert(conversationID)
    }

    public mutating func finish(conversationID: String) {
        runningIDs.remove(conversationID)
        activeTurns[conversationID] = nil
    }

    public mutating func setActiveTurn(_ state: ActiveTurnState, conversationID: String) {
        activeTurns[conversationID] = state
    }

    public mutating func clearActiveTurn(conversationID: String) {
        activeTurns[conversationID] = nil
    }

    public mutating func appendEvent(_ event: String, conversationID: String) {
        activeTurns[conversationID]?.events.append(event)
    }

    public func isRunning(conversationID: String?) -> Bool {
        conversationID.map { runningIDs.contains($0) } ?? false
    }

    public func activeTurn(conversationID: String?) -> ActiveTurnState? {
        conversationID.flatMap { activeTurns[$0] }
    }
}
