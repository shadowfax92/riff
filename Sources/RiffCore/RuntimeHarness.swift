import Foundation

/// Runtime-specific CLI behavior behind the shared `RuntimeDefinition`
/// facade. Add new CLI agents by implementing this protocol instead of
/// expanding switches in adapters.
public protocol RuntimeHarness: Sendable {
    var id: RuntimeID { get }
    var displayName: String { get }
    var binaryCandidates: [String] { get }
    var versionArguments: [String] { get }
    var fallbackModels: [RuntimeModelOption] { get }
    var listModelsArguments: [String]? { get }

    /// Builds the process invocation for one runtime turn, including
    /// fresh/resume differences and runtime-specific option syntax.
    func buildInvocation(_ request: RuntimeInvocationRequest) -> ProcessInvocation

    /// Converts raw CLI stdout into the normalized turn result consumed by
    /// the orchestrator.
    func parseResult(stdout: String) -> RuntimeTurnResult
}

public extension RuntimeHarness {
    var listModelsArguments: [String]? { nil }
}

public struct ClaudeRuntimeHarness: RuntimeHarness {
    public let id: RuntimeID = .claude
    public let displayName = "Claude Code"
    public let binaryCandidates = ["claude", "openclaude"]
    public let versionArguments = ["--version"]
    public var fallbackModels: [RuntimeModelOption] {
        [
            RuntimeDefinitions.defaultModel,
            RuntimeModelOption(id: "sonnet", label: "Sonnet (alias)"),
            RuntimeModelOption(id: "opus", label: "Opus (alias)"),
            RuntimeModelOption(id: "haiku", label: "Haiku (alias)"),
            RuntimeModelOption(id: "claude-sonnet-4-5", label: "claude-sonnet-4-5"),
            RuntimeModelOption(id: "claude-opus-4-5", label: "claude-opus-4-5"),
        ]
    }

    public init() {}

    public func buildInvocation(_ request: RuntimeInvocationRequest) -> ProcessInvocation {
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

    public func parseResult(stdout: String) -> RuntimeTurnResult {
        RuntimeStreamParser.parseClaude(stdout)
    }
}

public struct CodexRuntimeHarness: RuntimeHarness {
    public let id: RuntimeID = .codex
    public let displayName = "Codex CLI"
    public let binaryCandidates = ["codex"]
    public let versionArguments = ["--version"]
    public let listModelsArguments: [String]? = ["debug", "models"]
    public var fallbackModels: [RuntimeModelOption] {
        [
            RuntimeDefinitions.defaultModel,
            RuntimeModelOption(id: "gpt-5.5", label: "gpt-5.5"),
            RuntimeModelOption(id: "gpt-5.4", label: "gpt-5.4"),
            RuntimeModelOption(id: "gpt-5.3-codex", label: "gpt-5.3-codex"),
            RuntimeModelOption(id: "gpt-5", label: "gpt-5"),
            RuntimeModelOption(id: "o3", label: "o3"),
            RuntimeModelOption(id: "o4-mini", label: "o4-mini"),
        ]
    }

    public init() {}

    public func buildInvocation(_ request: RuntimeInvocationRequest) -> ProcessInvocation {
        var args: [String]
        if let sessionID = request.sessionID, !sessionID.isEmpty {
            args = [
                "exec",
                "resume",
                "--json",
                "--skip-git-repo-check",
                "--dangerously-bypass-approvals-and-sandbox",
            ]
            appendOptions(to: &args, options: request.options)
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
            appendOptions(to: &args, options: request.options)
        }
        return ProcessInvocation(
            command: "codex",
            arguments: args,
            stdin: request.stdin,
            workingDirectory: request.cwd
        )
    }

    public func parseResult(stdout: String) -> RuntimeTurnResult {
        RuntimeStreamParser.parseCodex(stdout)
    }

    private func appendOptions(to args: inout [String], options: RuntimeBuildOptions) {
        if options.model != "default", !options.model.isEmpty {
            args += ["--model", options.model]
        }
        if let reasoning = options.reasoning, reasoning != "default", !reasoning.isEmpty {
            args += ["-c", "model_reasoning_effort=\"\(reasoning)\""]
        }
    }
}
