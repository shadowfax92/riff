import Foundation

public enum RuntimeEvent: Equatable, Sendable {
    case textDelta(String)
    case toolUse(String)
}

public struct RuntimeTurnRequest: Equatable, Sendable {
    public var purpose: RuntimeTurnPurpose
    public var agent: AgentProfile
    public var conversationRoot: URL
    public var sessionID: String?
    public var baselinePrompt: String
    public var conversationPrompt: String
    public var context: String
    public var attachmentPath: String

    public init(
        purpose: RuntimeTurnPurpose = .debate,
        agent: AgentProfile,
        conversationRoot: URL,
        sessionID: String? = nil,
        baselinePrompt: String,
        conversationPrompt: String,
        context: String,
        attachmentPath: String
    ) {
        self.purpose = purpose
        self.agent = agent
        self.conversationRoot = conversationRoot
        self.sessionID = sessionID
        self.baselinePrompt = baselinePrompt
        self.conversationPrompt = conversationPrompt
        self.context = context
        self.attachmentPath = attachmentPath
    }
}

public enum RuntimeTurnPurpose: Equatable, Sendable {
    case debate
    case summary
}

public struct RuntimeTurnResult: Equatable, Sendable {
    public var text: String
    public var sessionID: String?
    public var model: String

    public init(text: String, sessionID: String? = nil, model: String = "") {
        self.text = text
        self.sessionID = sessionID
        self.model = model
    }
}

public protocol RuntimeAdapter: Sendable {
    func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void) async throws -> RuntimeTurnResult
}

public enum RuntimeAdapterError: Error, Equatable {
    case processFailed(command: String, exitCode: Int32, stderr: String)
}

public final class CLIRuntimeAdapter: RuntimeAdapter, @unchecked Sendable {
    private let definition: RuntimeDefinition
    private let command: String
    private let processClient: ProcessClient

    public init(
        definition: RuntimeDefinition,
        command: String? = nil,
        processClient: ProcessClient = FoundationProcessClient()
    ) {
        self.definition = definition
        self.command = command ?? definition.binaryCandidates.first ?? definition.id.rawValue
        self.processClient = processClient
    }

    public func runTurn(_ request: RuntimeTurnRequest, emit: @escaping @Sendable (RuntimeEvent) -> Void = { _ in }) async throws -> RuntimeTurnResult {
        let stdin = RuntimePromptBuilder.prompt(for: request, includeInstructions: request.sessionID == nil)
        var invocation = definition.buildInvocation(RuntimeInvocationRequest(
            sessionID: request.sessionID,
            cwd: request.conversationRoot,
            options: RuntimeBuildOptions(model: request.agent.model, reasoning: request.agent.reasoning),
            stdin: stdin
        ))
        invocation.command = command
        let result = try await processClient.run(invocation)
        if result.exitCode != 0 {
            throw RuntimeAdapterError.processFailed(
                command: invocation.command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        let parsed: RuntimeTurnResult
        switch definition.id {
        case .claude:
            parsed = RuntimeStreamParser.parseClaude(result.stdout)
        case .codex:
            parsed = RuntimeStreamParser.parseCodex(result.stdout)
        }
        if !parsed.text.isEmpty {
            emit(.textDelta(parsed.text))
        }
        if parsed.sessionID == nil, let sessionID = request.sessionID {
            return RuntimeTurnResult(text: parsed.text, sessionID: sessionID, model: parsed.model)
        }
        return parsed
    }
}

public enum RuntimePromptBuilder {
    /// Builds the stdin prompt for one agent turn. First turns include role
    /// instructions; resumed turns rely on the CLI session and send only debate context.
    public static func prompt(for request: RuntimeTurnRequest, includeInstructions: Bool) -> String {
        if request.purpose == .summary {
            return summaryPrompt(for: request)
        }

        var parts: [String] = []
        if includeInstructions {
            parts.append(request.baselinePrompt.trimmingCharacters(in: .whitespacesAndNewlines))
            parts.append("ROLE_NAME:\n\(request.agent.name)")
            if !request.agent.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("ROLE_PROMPT:\n\(request.agent.instructions)")
            }
            parts.append("""
            Response contract:
            - Write a clear chat argument of roughly 280 words.
            - If you need more detail, write it to `\(request.attachmentPath)` using your file tools.
            - If you write that file, mention `\(request.attachmentPath)` in your chat argument.
            """)
        } else {
            parts.append("Continue as \(request.agent.name) (\(request.agent.role)).")
            parts.append("Optional detail file for this turn: `\(request.attachmentPath)`.")
        }
        parts.append("Debate prompt:\n\(request.conversationPrompt)")
        if request.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("No prior messages yet.")
        } else {
            parts.append("Conversation context:\n\(request.context)")
        }
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func summaryPrompt(for request: RuntimeTurnRequest) -> String {
        var parts: [String] = []
        parts.append(request.baselinePrompt.trimmingCharacters(in: .whitespacesAndNewlines))
        parts.append("You are \(request.agent.name), summarizing this completed Riff debate from a fresh session.")
        let instructions = request.agent.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !instructions.isEmpty {
            parts.append("SUMMARY_AGENT_PROMPT:\n\(instructions)")
        }
        parts.append("Debate prompt:\n\(request.conversationPrompt)")
        if request.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("No conversation transcript.")
        } else {
            parts.append("Full conversation:\n\(request.context)")
        }
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

public enum RuntimeStreamParser {
    public static func parseClaude(_ stdout: String) -> RuntimeTurnResult {
        var textParts: [String] = []
        var resultText = ""
        var sessionID: String?
        var model = ""
        for object in parseJSONLines(stdout) {
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
        return RuntimeTurnResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines), sessionID: sessionID, model: model)
    }

    public static func parseCodex(_ stdout: String) -> RuntimeTurnResult {
        var text = ""
        var sessionID: String?
        var model = ""
        for rawObject in parseJSONLines(stdout) {
            let object = rawObject["msg"] as? [String: Any] ?? rawObject
            let type = object["type"] as? String ?? ""
            sessionID = firstString(object, keys: ["session_id", "sessionId", "conversation_id", "thread_id"]) ?? sessionID
            model = object["model"] as? String ?? model
            if type == "agent_message_delta", let delta = object["delta"] as? String {
                text += delta
            } else if type == "agent_message", let message = object["message"] as? String {
                text = message
            } else if type.contains("session") {
                sessionID = firstString(object, keys: ["session_id", "sessionId", "conversation_id", "thread_id", "id"]) ?? sessionID
            }
        }
        return RuntimeTurnResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines), sessionID: sessionID, model: model)
    }

    private static func parseJSONLines(_ stdout: String) -> [[String: Any]] {
        stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                guard let data = String(line).data(using: .utf8) else {
                    return nil
                }
                return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
    }

    private static func firstString(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
