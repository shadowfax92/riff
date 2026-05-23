import Foundation
import RiffCore
import Testing
@testable import RiffApp

@Test func messageGroupingUsesUniqueRenderIDsWhenTranscriptEntryIDsRepeat() {
    let first = entry(id: "duplicate", turn: 1, speakerID: "a", startedAt: 0)
    let repeated = entry(id: "duplicate", turn: 2, speakerID: "a", startedAt: 1)

    let groups = MessageGrouping.group(entries: [first, repeated])
    let ids = groups.map(\.id)

    #expect(Set(ids).count == ids.count)
    #expect(ids.allSatisfy { id in
        id.range(of: #"^(divider|message)-[a-f0-9]{10}$"#, options: .regularExpression) != nil
    })
}

private func entry(id: String, turn: Int, speakerID: String, startedAt: TimeInterval) -> TranscriptEntry {
    TranscriptEntry(
        id: id,
        turn: turn,
        round: 0,
        speakerID: speakerID,
        speakerName: speakerID,
        text: "message \(turn)",
        startedAt: Date(timeIntervalSince1970: startedAt),
        finishedAt: Date(timeIntervalSince1970: startedAt)
    )
}
