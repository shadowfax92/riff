import Foundation
import RiffCore
import Testing
@testable import RiffApp

@Test func summaryStoreAppendsSummaryAfterLatestDiskTranscript() {
    var store = UIOnlySummaryStore()
    let summary = entry(turn: 3, speakerID: "summary", text: "### Summary\n\nShort version.")

    store.set(summary, for: "c1")
    let display = store.merged(
        with: [
            entry(turn: 1, speakerID: "user", text: "first"),
            entry(turn: 2, speakerID: "agent", text: "reply"),
            entry(turn: 3, speakerID: "user", text: "follow-up"),
        ],
        conversationID: "c1"
    )

    #expect(display.map(\.speakerID) == ["user", "agent", "user", "summary"])
    #expect(display.last?.text == summary.text)
}

@Test func summaryStoreKeepsOnlyOneSummaryPerConversation() {
    var store = UIOnlySummaryStore()

    store.set(entry(turn: 2, speakerID: "summary", text: "old"), for: "c1")
    store.set(entry(turn: 3, speakerID: "summary", text: "new"), for: "c1")

    let display = store.merged(
        with: [entry(turn: 1, speakerID: "user", text: "question")],
        conversationID: "c1"
    )

    #expect(display.map(\.text) == ["question", "new"])
}

private func entry(turn: Int, speakerID: String, text: String) -> TranscriptEntry {
    TranscriptEntry(
        id: "t\(turn)-\(speakerID)",
        turn: turn,
        round: 0,
        speakerID: speakerID,
        speakerName: speakerID,
        text: text,
        startedAt: Date(timeIntervalSince1970: TimeInterval(turn)),
        finishedAt: Date(timeIntervalSince1970: TimeInterval(turn))
    )
}
