import Foundation

public struct RiffPaths: Equatable, Sendable {
    public var homeURL: URL

    public init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeURL = homeURL
    }

    public var rootURL: URL {
        homeURL.appending(path: ".riff", directoryHint: .isDirectory)
    }

    public var configURL: URL {
        rootURL.appending(path: "config", directoryHint: .isDirectory)
    }

    /// Pre-rename directory location, kept so bootstrap can migrate users
    /// who already have a populated `~/.riff/configs` tree.
    public var legacyConfigsURL: URL {
        rootURL.appending(path: "configs", directoryHint: .isDirectory)
    }

    public var conversationsURL: URL {
        rootURL.appending(path: "conversations", directoryHint: .isDirectory)
    }

    public var logsURL: URL {
        rootURL.appending(path: "logs", directoryHint: .isDirectory)
    }

    public func defaultConversationURL(id: String) -> URL {
        conversationsURL.appending(path: id, directoryHint: .isDirectory)
    }
}

public enum RiffPathFormat {
    public static func newConversationID() -> String {
        UUID().uuidString.lowercased()
    }

    public static func slug(_ text: String, fallback: String = "agent") -> String {
        let lowered = text.lowercased()
        let mapped = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(mapped)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? fallback : collapsed
    }

    public static func detailFilename(turn: Int, role: String, runtime: RuntimeID) -> String {
        let turnPart = String(format: "turn-%03d", max(0, turn))
        return "\(turnPart).\(slug(role)).\(runtime.rawValue).md"
    }

    public static func relativeDetailPath(turn: Int, role: String, runtime: RuntimeID) -> String {
        "files/\(detailFilename(turn: turn, role: role, runtime: runtime))"
    }
}
