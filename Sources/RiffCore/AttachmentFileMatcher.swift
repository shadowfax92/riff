import Foundation

public enum AttachmentFileMatcher {
    /// Finds the in-conversation markdown file represented by an attachment
    /// path. Agents may mention either the stored relative path or just the
    /// basename, so the UI accepts both forms.
    public static func match(attachment: TranscriptAttachment, files: [ConversationFile]) -> ConversationFile? {
        let filename = (attachment.path as NSString).lastPathComponent
        return files.first { file in
            file.relativePath == attachment.path || file.name == filename
        }
    }
}
