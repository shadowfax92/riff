import Foundation

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
        if let reasoning = request.options.reasoning, reasoning != "default", !reasoning.isEmpty {
            args += ["--effort", reasoning]
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
        var textParts: [String] = []
        var resultText = ""
        var sessionID: String?
        var model = ""
        for object in RuntimeOutputParsing.parseJSONLines(stdout) {
            let type = object["type"] as? String
            if type == "system", object["subtype"] as? String == "init" {
                sessionID = object["session_id"] as? String ?? sessionID
                model = object["model"] as? String ?? model
            } else if type == "assistant",
                      let message = object["message"] as? [String: Any],
                      let content = message["content"] as? [[String: Any]] {
                for block in content where block["type"] as? String == "text" {
                    if let text = block["text"] as? String {
                        textParts.append(text)
                    }
                }
            } else if type == "result" {
                resultText = object["result"] as? String ?? resultText
                sessionID = object["session_id"] as? String ?? sessionID
                model = object["model"] as? String ?? model
            }
        }
        let text = resultText.isEmpty ? textParts.joined() : resultText
        return RuntimeTurnResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionID: sessionID,
            model: model
        )
    }
}
