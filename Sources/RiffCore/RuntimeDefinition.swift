import Foundation

public struct RuntimeModelOption: Equatable, Codable, Sendable {
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

public struct RuntimeDefinition: Sendable {
    public var id: RuntimeID
    public var displayName: String
    public var binaryCandidates: [String]
    public var versionArguments: [String]
    public var fallbackModels: [RuntimeModelOption]
    public var listModelsArguments: [String]?
    public var buildInvocation: @Sendable (RuntimeInvocationRequest) -> ProcessInvocation

    public init(
        id: RuntimeID,
        displayName: String,
        binaryCandidates: [String],
        versionArguments: [String],
        fallbackModels: [RuntimeModelOption],
        listModelsArguments: [String]? = nil,
        buildInvocation: @escaping @Sendable (RuntimeInvocationRequest) -> ProcessInvocation
    ) {
        self.id = id
        self.displayName = displayName
        self.binaryCandidates = binaryCandidates
        self.versionArguments = versionArguments
        self.fallbackModels = fallbackModels
        self.listModelsArguments = listModelsArguments
        self.buildInvocation = buildInvocation
    }
}

public enum RuntimeDefinitions {
    public static let defaultModel = RuntimeModelOption(id: "default", label: "Default (CLI config)")

    public static let claude = RuntimeDefinition(
        id: .claude,
        displayName: "Claude Code",
        binaryCandidates: ["claude", "openclaude"],
        versionArguments: ["--version"],
        fallbackModels: [
            defaultModel,
            RuntimeModelOption(id: "sonnet", label: "Sonnet (alias)"),
            RuntimeModelOption(id: "opus", label: "Opus (alias)"),
            RuntimeModelOption(id: "haiku", label: "Haiku (alias)"),
            RuntimeModelOption(id: "claude-sonnet-4-5", label: "claude-sonnet-4-5"),
            RuntimeModelOption(id: "claude-opus-4-5", label: "claude-opus-4-5"),
        ]
    ) { request in
        var args = [
            "-p",
            "--input-format", "text",
            "--output-format", "stream-json",
            "--verbose",
            "--permission-mode", "bypassPermissions",
        ]
        if let sessionID = request.sessionID, !sessionID.isEmpty {
            args += ["--resume", sessionID]
        }
        if request.options.model != "default", !request.options.model.isEmpty {
            args += ["--model", request.options.model]
        }
        let allowed = ([request.cwd] + request.allowedDirectories)
            .map(\.path)
            .filter { !$0.isEmpty }
        if !allowed.isEmpty {
            args += ["--add-dir"] + allowed
        }
        return ProcessInvocation(
            command: "claude",
            arguments: args,
            stdin: request.stdin,
            workingDirectory: request.cwd
        )
    }

    public static let codex = RuntimeDefinition(
        id: .codex,
        displayName: "Codex CLI",
        binaryCandidates: ["codex"],
        versionArguments: ["--version"],
        fallbackModels: [
            defaultModel,
            RuntimeModelOption(id: "gpt-5.5", label: "gpt-5.5"),
            RuntimeModelOption(id: "gpt-5.4", label: "gpt-5.4"),
            RuntimeModelOption(id: "gpt-5.3-codex", label: "gpt-5.3-codex"),
            RuntimeModelOption(id: "gpt-5", label: "gpt-5"),
            RuntimeModelOption(id: "o3", label: "o3"),
            RuntimeModelOption(id: "o4-mini", label: "o4-mini"),
        ],
        listModelsArguments: ["debug", "models"]
    ) { request in
        var args: [String]
        if let sessionID = request.sessionID, !sessionID.isEmpty {
            args = [
                "exec",
                "resume",
                "--json",
                "--skip-git-repo-check",
                "--dangerously-bypass-approvals-and-sandbox",
            ]
            appendCodexOptions(to: &args, options: request.options)
            args += [sessionID, "-"]
        } else {
            args = [
                "exec",
                "--json",
                "--skip-git-repo-check",
                "--dangerously-bypass-approvals-and-sandbox",
                "-C", request.cwd.path,
            ]
            for directory in request.allowedDirectories where !directory.path.isEmpty {
                args += ["--add-dir", directory.path]
            }
            appendCodexOptions(to: &args, options: request.options)
        }
        return ProcessInvocation(
            command: "codex",
            arguments: args,
            stdin: request.stdin,
            workingDirectory: request.cwd
        )
    }

    public static func definition(for id: RuntimeID) -> RuntimeDefinition {
        switch id {
        case .claude:
            claude
        case .codex:
            codex
        }
    }

    private static func appendCodexOptions(to args: inout [String], options: RuntimeBuildOptions) {
        if options.model != "default", !options.model.isEmpty {
            args += ["--model", options.model]
        }
        if let reasoning = options.reasoning, reasoning != "default", !reasoning.isEmpty {
            args += ["-c", "model_reasoning_effort=\"\(reasoning)\""]
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
