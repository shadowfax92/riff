import Foundation

public struct RuntimeSettings: Codable, Equatable, Sendable {
    public var cliPath: String

    public init(cliPath: String = RuntimeSettings.defaultCLIPath()) {
        self.cliPath = cliPath
    }

    public var processEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let path = cliPath.trimmingCharacters(in: .whitespacesAndNewlines)
        environment["PATH"] = path.isEmpty ? Self.defaultCLIPath() : path
        return environment
    }

    public static func defaultCLIPath(
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
}
