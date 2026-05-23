import Foundation

public struct RuntimeSettings: Codable, Equatable, Sendable {
    public var claudePath: String
    public var codexPath: String

    public init(
        claudePath: String = "",
        codexPath: String = ""
    ) {
        self.claudePath = claudePath
        self.codexPath = codexPath
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        claudePath = try values.decodeIfPresent(String.self, forKey: .claudePath)
            ?? ""
        codexPath = try values.decodeIfPresent(String.self, forKey: .codexPath)
            ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(claudePath, forKey: .claudePath)
        try values.encode(codexPath, forKey: .codexPath)
    }

    /// Returns the configured executable path for the selected runtime.
    public func command(for runtime: RuntimeID) -> String {
        switch runtime {
        case .claude:
            Self.cleanPath(claudePath)
        case .codex:
            Self.cleanPath(codexPath)
        }
    }

    public var processEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = Self.subprocessSearchPath(environment: environment)
        return environment
    }

    /// Builds the PATH inherited by runtime subprocesses. Runtime binaries
    /// themselves still come only from the explicit settings fields.
    public static func subprocessSearchPath(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        var paths = (environment["PATH"] ?? "")
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
        paths += [
            homeURL.appending(path: ".local/bin").path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        var seen = Set<String>()
        return paths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ":")
    }

    private static func cleanPath(_ path: String) -> String {
        path.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case claudePath
        case codexPath
    }
}
