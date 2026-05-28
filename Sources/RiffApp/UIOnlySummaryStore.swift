import RiffCore

/// Holds transient conversation summaries that should be shown in chat but
/// never written into the file-backed transcript.
struct UIOnlySummaryStore {
    private var summaries: [String: TranscriptEntry] = [:]

    mutating func set(_ summary: TranscriptEntry, for conversationID: String) {
        summaries[conversationID] = summary
    }

    mutating func remove(for conversationID: String) {
        summaries[conversationID] = nil
    }

    func contains(conversationID: String) -> Bool {
        summaries[conversationID] != nil
    }

    /// Returns the disk transcript with the latest UI-only summary appended
    /// as the final visible entry for that conversation.
    func merged(with diskTranscript: [TranscriptEntry], conversationID: String) -> [TranscriptEntry] {
        guard let summary = summaries[conversationID] else {
            return diskTranscript
        }
        return diskTranscript + [summary]
    }
}
