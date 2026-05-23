import Foundation

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
