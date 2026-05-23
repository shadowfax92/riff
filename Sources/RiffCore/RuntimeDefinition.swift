import Foundation

public struct RuntimeModelOption: Equatable, Codable, Sendable {
    public var id: String
    public var label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct RuntimeReasoningOption: Equatable, Codable, Sendable {
    public var id: String
    public var label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct RuntimeBuildOptions: Equatable, Sendable {
    public var model: String
    public var reasoning: String?

    public init(model: String = "default", reasoning: String? = nil) {
        self.model = model
        self.reasoning = reasoning
    }
}

public struct RuntimeInvocationRequest: Equatable, Sendable {
    public var sessionID: String?
    public var cwd: URL
    public var allowedDirectories: [URL]
    public var options: RuntimeBuildOptions
    public var stdin: String

    public init(
        sessionID: String? = nil,
        cwd: URL,
        allowedDirectories: [URL] = [],
        options: RuntimeBuildOptions = RuntimeBuildOptions(),
        stdin: String
    ) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.allowedDirectories = allowedDirectories
        self.options = options
        self.stdin = stdin
    }
}

/// Stable app-facing description of a CLI runtime backed by a concrete
/// harness for runtime-specific command construction and output parsing.
public struct RuntimeDefinition: Sendable {
    private let harness: any RuntimeHarness

    public var id: RuntimeID { harness.id }
    public var displayName: String { harness.displayName }
    public var binaryCandidates: [String] { harness.binaryCandidates }
    public var versionArguments: [String] { harness.versionArguments }
    public var fallbackModels: [RuntimeModelOption] { harness.fallbackModels }
    public var listModelsArguments: [String]? { harness.listModelsArguments }

    public init(harness: any RuntimeHarness) {
        self.harness = harness
    }

    /// Builds the concrete process invocation by delegating to this
    /// definition's runtime harness.
    public func buildInvocation(_ request: RuntimeInvocationRequest) -> ProcessInvocation {
        harness.buildInvocation(request)
    }

    /// Parses runtime stdout by delegating to the harness that understands
    /// that CLI's stream format.
    public func parseResult(stdout: String) -> RuntimeTurnResult {
        harness.parseResult(stdout: stdout)
    }
}

public enum RuntimeDefinitions {
    public static let defaultModel = RuntimeModelOption(id: "default", label: "Default (CLI config)")
    public static let defaultReasoning = RuntimeReasoningOption(id: "default", label: "Default (CLI config)")

    public static let claude = RuntimeDefinition(harness: ClaudeRuntimeHarness())

    public static let codex = RuntimeDefinition(harness: CodexRuntimeHarness())

    public static func definition(for id: RuntimeID) -> RuntimeDefinition {
        switch id {
        case .claude:
            claude
        case .codex:
            codex
        }
    }

    public static func reasoningOptions(for id: RuntimeID) -> [RuntimeReasoningOption] {
        switch id {
        case .claude:
            [
                defaultReasoning,
                RuntimeReasoningOption(id: "low", label: "Low"),
                RuntimeReasoningOption(id: "medium", label: "Medium"),
                RuntimeReasoningOption(id: "high", label: "High"),
                RuntimeReasoningOption(id: "xhigh", label: "XHigh"),
                RuntimeReasoningOption(id: "max", label: "Max"),
            ]
        case .codex:
            [
                defaultReasoning,
                RuntimeReasoningOption(id: "low", label: "Low"),
                RuntimeReasoningOption(id: "medium", label: "Medium"),
                RuntimeReasoningOption(id: "high", label: "High"),
            ]
        }
    }

}

public struct DetectedRuntime: Equatable, Sendable {
    public var id: RuntimeID
    public var available: Bool
    public var command: String
    public var version: String?
    public var models: [RuntimeModelOption]

    public init(
        id: RuntimeID,
        available: Bool,
        command: String,
        version: String? = nil,
        models: [RuntimeModelOption]
    ) {
        self.id = id
        self.available = available
        self.command = command
        self.version = version
        self.models = models
    }
}

public struct RuntimeDetector: Sendable {
    private let processClient: ProcessClient

    public init(processClient: ProcessClient = FoundationProcessClient()) {
        self.processClient = processClient
    }

    /// Probes the configured executable path when present; otherwise falls
    /// back to known binary names and still returns offline model metadata.
    public func detect(_ definition: RuntimeDefinition, preferredCommand: String? = nil) async -> DetectedRuntime {
        let preferred = preferredCommand?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferred, preferred.isEmpty {
            return DetectedRuntime(
                id: definition.id,
                available: false,
                command: definition.binaryCandidates.first ?? definition.id.rawValue,
                models: definition.fallbackModels
            )
        }
        let candidates = preferred.map { [$0] } ?? definition.binaryCandidates
        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            let probe = ProcessInvocation(
                command: candidate,
                arguments: definition.versionArguments,
                timeout: 3
            )
            guard let versionResult = try? await processClient.run(probe), versionResult.exitCode == 0 else {
                continue
            }
            let models = await detectModels(definition: definition, command: candidate)
            return DetectedRuntime(
                id: definition.id,
                available: true,
                command: candidate,
                version: versionResult.stdout.split(separator: "\n").first.map(String.init),
                models: models
            )
        }
        return DetectedRuntime(
            id: definition.id,
            available: false,
            command: preferred ?? definition.binaryCandidates.first ?? definition.id.rawValue,
            models: definition.fallbackModels
        )
    }

    private func detectModels(definition: RuntimeDefinition, command: String) async -> [RuntimeModelOption] {
        guard let args = definition.listModelsArguments else {
            return definition.fallbackModels
        }
        let result = try? await processClient.run(ProcessInvocation(command: command, arguments: args, timeout: 5))
        guard let result, result.exitCode == 0 else {
            return definition.fallbackModels
        }
        return parseCodexDebugModels(result.stdout) ?? definition.fallbackModels
    }
}

public func parseCodexDebugModels(_ stdout: String) -> [RuntimeModelOption]? {
    guard
        let data = stdout.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let models = object["models"] as? [[String: Any]]
    else {
        return nil
    }
    var seen = Set([RuntimeDefinitions.defaultModel.id])
    var output = [RuntimeDefinitions.defaultModel]
    for model in models {
        if model["visibility"] as? String == "hidden" {
            continue
        }
        let id = (model["slug"] as? String ?? model["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !seen.contains(id) else {
            continue
        }
        seen.insert(id)
        let label = (model["display_name"] as? String ?? model["name"] as? String ?? id).trimmingCharacters(in: .whitespacesAndNewlines)
        output.append(RuntimeModelOption(id: id, label: label.isEmpty ? id : label))
    }
    return output.count > 1 ? output : nil
}
