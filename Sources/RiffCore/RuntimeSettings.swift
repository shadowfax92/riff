import Foundation

public struct RuntimeSettings: Codable, Equatable, Sendable {
    public var claudePath: String
    public var codexPath: String

    public init(
        claudePath: String = RuntimeSettings.defaultExecutablePath(for: .claude),
        codexPath: String = RuntimeSettings.defaultExecutablePath(for: .codex)
    ) {
        self.claudePath = claudePath
        self.codexPath = codexPath
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacyPath = try values.decodeIfPresent(String.self, forKey: .cliPath) ?? ""
        claudePath = try values.decodeIfPresent(String.self, forKey: .claudePath)
            ?? Self.findExecutable("claude", inPath: legacyPath)
            ?? Self.defaultExecutablePath(for: .claude)
        codexPath = try values.decodeIfPresent(String.self, forKey: .codexPath)
            ?? Self.findExecutable("codex", inPath: legacyPath)
            ?? Self.defaultExecutablePath(for: .codex)
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
        environment["PATH"] = Self.pathWithRuntimeDirectories(settings: self, environment: environment)
        return environment
    }

    /// Picks a default executable path with `~/.local/bin` first because app
    /// launches do not inherit the user's interactive shell PATH.
    public static func defaultExecutablePath(
        for runtime: RuntimeID,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let binary = runtime.rawValue
        let localPath = homeURL.appending(path: ".local/bin/\(binary)").path
        if FileManager.default.isExecutableFile(atPath: localPath) {
            return localPath
        }
        return findExecutable(binary, inPath: environment["PATH"] ?? "") ?? localPath
    }

    /// Finds an executable in a colon-delimited PATH string.
    public static func findExecutable(_ name: String, inPath path: String) -> String? {
        for directory in path.split(separator: ":", omittingEmptySubsequences: true) {
            let candidate = URL(fileURLWithPath: String(directory)).appending(path: name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func defaultProcessPath(
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

    private static func pathWithRuntimeDirectories(
        settings: RuntimeSettings,
        environment: [String: String]
    ) -> String {
        var paths = [
            cleanPath(settings.claudePath),
            cleanPath(settings.codexPath),
        ]
        .filter { !$0.isEmpty }
        .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
        paths += defaultProcessPath(environment: environment)
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
        var seen = Set<String>()
        return paths
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ":")
    }

    private static func cleanPath(_ path: String) -> String {
        path.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case claudePath
        case codexPath
        case cliPath
    }
}
