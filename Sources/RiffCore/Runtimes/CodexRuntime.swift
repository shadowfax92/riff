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
            RuntimeModelOption(id: "gpt-5.4-mini", label: "gpt-5.4-mini"),
            RuntimeModelOption(id: "gpt-5.3-codex", label: "gpt-5.3-codex"),
            RuntimeModelOption(id: "gpt-5.3-codex-spark", label: "gpt-5.3-codex-spark"),
            RuntimeModelOption(id: "gpt-5.1", label: "gpt-5.1"),
            RuntimeModelOption(id: "gpt-5.1-codex-mini", label: "gpt-5.1-codex-mini"),
            RuntimeModelOption(id: "gpt-5-codex", label: "gpt-5-codex"),
            RuntimeModelOption(id: "gpt-5", label: "gpt-5"),
            RuntimeModelOption(id: "gpt-5-mini", label: "gpt-5-mini"),
            RuntimeModelOption(id: "gpt-5-nano", label: "gpt-5-nano"),
            RuntimeModelOption(id: "o3", label: "o3"),
            RuntimeModelOption(id: "o4-mini", label: "o4-mini"),
            RuntimeModelOption(id: "o3-mini", label: "o3-mini"),
            RuntimeModelOption(id: "codex-mini-latest", label: "Codex Mini"),
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
        var text = ""
        var sessionID: String?
        var model = ""
        for rawObject in RuntimeOutputParsing.parseJSONLines(stdout) {
            let object = rawObject["msg"] as? [String: Any] ?? rawObject
            let type = object["type"] as? String ?? ""
            sessionID = RuntimeOutputParsing.firstString(
                object,
                keys: ["session_id", "sessionId", "conversation_id", "thread_id"]
            ) ?? sessionID
            model = object["model"] as? String ?? model
            if type == "agent_message_delta", let delta = object["delta"] as? String {
                text += delta
            } else if type == "agent_message", let message = object["message"] as? String {
                text = message
            } else if type == "agent_message", let message = object["text"] as? String {
                text = message
            } else if type == "item.completed",
                      let item = object["item"] as? [String: Any],
                      item["type"] as? String == "agent_message",
                      let message = item["text"] as? String {
                text = message
            } else if type.contains("session") {
                sessionID = RuntimeOutputParsing.firstString(
                    object,
                    keys: ["session_id", "sessionId", "conversation_id", "thread_id", "id"]
                ) ?? sessionID
            }
        }
        return RuntimeTurnResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionID: sessionID,
            model: model
        )
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
