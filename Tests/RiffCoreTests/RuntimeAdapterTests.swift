import Foundation
import Testing
@testable import RiffCore

@Test func claudeFreshTurnsUseStreamJSONAndBypassPermissions() {
    let request = RuntimeInvocationRequest(
        cwd: URL(fileURLWithPath: "/tmp/riff"),
        options: RuntimeBuildOptions(model: "sonnet"),
        stdin: "prompt"
    )

    let invocation = RuntimeDefinitions.claude.buildInvocation(request)

    #expect(invocation.arguments.contains("-p"))
    #expect(invocation.arguments.contains("--output-format"))
    #expect(invocation.arguments.contains("stream-json"))
    #expect(invocation.arguments.contains("--permission-mode"))
    #expect(invocation.arguments.contains("bypassPermissions"))
    #expect(invocation.arguments.contains("--add-dir"))
    #expect(invocation.arguments.contains("/tmp/riff"))
    #expect(!invocation.arguments.contains("--resume"))
    #expect(invocation.stdin == "prompt")
}

@Test func claudeResumeIncludesSessionAndKeepsPromptOnStdin() {
    let request = RuntimeInvocationRequest(
        sessionID: "claude-session",
        cwd: URL(fileURLWithPath: "/tmp/riff"),
        stdin: "delta"
    )

    let invocation = RuntimeDefinitions.claude.buildInvocation(request)

    #expect(hasPair(invocation.arguments, "--resume", "claude-session"))
    #expect(invocation.stdin == "delta")
}

@Test func codexFreshTurnsUsePermissiveExecInConversationRoot() {
    let request = RuntimeInvocationRequest(
        cwd: URL(fileURLWithPath: "/tmp/riff"),
        allowedDirectories: [URL(fileURLWithPath: "/tmp/extra")],
        options: RuntimeBuildOptions(model: "gpt-5.4", reasoning: "high"),
        stdin: "prompt"
    )

    let invocation = RuntimeDefinitions.codex.buildInvocation(request)

    #expect(invocation.arguments.starts(with: ["exec", "--json", "--skip-git-repo-check", "--dangerously-bypass-approvals-and-sandbox"]))
    #expect(hasPair(invocation.arguments, "-C", "/tmp/riff"))
    #expect(hasPair(invocation.arguments, "--add-dir", "/tmp/extra"))
    #expect(hasPair(invocation.arguments, "--model", "gpt-5.4"))
    #expect(hasPair(invocation.arguments, "-c", "model_reasoning_effort=\"high\""))
    #expect(!invocation.arguments.contains("-"))
}

@Test func codexResumeUsesResumeSubcommandAndStdinSentinel() {
    let request = RuntimeInvocationRequest(
        sessionID: "codex-session",
        cwd: URL(fileURLWithPath: "/tmp/riff"),
        stdin: "delta"
    )

    let invocation = RuntimeDefinitions.codex.buildInvocation(request)

    #expect(invocation.arguments.starts(with: ["exec", "resume", "--json", "--skip-git-repo-check", "--dangerously-bypass-approvals-and-sandbox"]))
    #expect(invocation.arguments.suffix(2) == ["codex-session", "-"])
}

@Test func runtimeDetectionTriesFallbackBinaryAndKeepsFallbackModels() async {
    let client = FakeProcessClient(results: [
        "claude --version": ProcessResult(stdout: "", exitCode: 127),
        "openclaude --version": ProcessResult(stdout: "2.0.0\n"),
    ])
    let detector = RuntimeDetector(processClient: client)

    let detected = await detector.detect(RuntimeDefinitions.claude)

    #expect(detected.available)
    #expect(detected.command == "openclaude")
    #expect(detected.models.contains { $0.id == "sonnet" })
}

@Test func runtimeDetectionPrefersConfiguredCommandPath() async {
    let client = FakeProcessClient(results: [
        "/Users/me/.local/bin/claude --version": ProcessResult(stdout: "2.1.0\n"),
    ])
    let detector = RuntimeDetector(processClient: client)

    let detected = await detector.detect(
        RuntimeDefinitions.claude,
        preferredCommand: "/Users/me/.local/bin/claude"
    )

    #expect(detected.available)
    #expect(detected.command == "/Users/me/.local/bin/claude")
    #expect(await client.commands() == ["/Users/me/.local/bin/claude"])
}

@Test func runtimeDetectionDoesNotFallbackWhenConfiguredPathIsMissing() async {
    let client = FakeProcessClient(results: [
        "/missing/claude --version": ProcessResult(stdout: "", exitCode: 127),
        "claude --version": ProcessResult(stdout: "should not be used\n"),
    ])
    let detector = RuntimeDetector(processClient: client)

    let detected = await detector.detect(
        RuntimeDefinitions.claude,
        preferredCommand: "/missing/claude"
    )

    #expect(!detected.available)
    #expect(detected.command == "/missing/claude")
    #expect(await client.commands() == ["/missing/claude"])
}

@Test func codexDebugModelsParserSkipsHiddenModels() {
    let models = parseCodexDebugModels("""
    {"models":[{"slug":"gpt-5.4","display_name":"GPT 5.4"},{"slug":"secret","visibility":"hidden"}]}
    """)

    #expect(models?.map(\.id) == ["default", "gpt-5.4"])
}

@Test func cliAdapterUsesDetectedCommandOverride() async throws {
    let client = FakeProcessClient(results: [
        "openclaude -p --input-format text --output-format stream-json --verbose --permission-mode bypassPermissions --add-dir /tmp/riff": ProcessResult(stdout: """
        {"type":"system","subtype":"init","session_id":"sid","model":"sonnet"}
        {"type":"result","result":"hello","session_id":"sid","model":"sonnet"}
        """)
    ])
    let adapter = CLIRuntimeAdapter(
        definition: RuntimeDefinitions.claude,
        command: "openclaude",
        processClient: client
    )

    let result = try await adapter.runTurn(RuntimeTurnRequest(
        agent: AgentProfile(id: "a", name: "A", role: "Role", runtime: .claude, model: "default", instructions: ""),
        conversationRoot: URL(fileURLWithPath: "/tmp/riff"),
        baselinePrompt: "base",
        conversationPrompt: "prompt",
        context: "",
        attachmentPath: "files/turn-001.role.claude.md"
    ))

    #expect(result.sessionID == "sid")
    #expect(await client.commands() == ["openclaude"])
}

@Test func cliAdapterPassesSupportFoldersAsAllowedDirectories() async throws {
    let client = FakeProcessClient(results: [
        "openclaude -p --input-format text --output-format stream-json --verbose --permission-mode bypassPermissions --add-dir /tmp/riff /Users/me/research": ProcessResult(stdout: """
        {"type":"system","subtype":"init","session_id":"sid","model":"sonnet"}
        {"type":"result","result":"hello","session_id":"sid","model":"sonnet"}
        """)
    ])
    let adapter = CLIRuntimeAdapter(
        definition: RuntimeDefinitions.claude,
        command: "openclaude",
        processClient: client
    )

    _ = try await adapter.runTurn(RuntimeTurnRequest(
        agent: AgentProfile(id: "a", name: "A", role: "Role", runtime: .claude, model: "default", instructions: ""),
        conversationRoot: URL(fileURLWithPath: "/tmp/riff"),
        baselinePrompt: "base",
        conversationPrompt: "prompt",
        context: "",
        attachmentPath: "files/turn-001.role.claude.md",
        supportFolders: [URL(fileURLWithPath: "/Users/me/research")]
    ))

    #expect(await client.commands() == ["openclaude"])
}

@Test func freshRuntimePromptUsesRoleNameAndRolePromptLabels() {
    let prompt = RuntimePromptBuilder.prompt(
        for: RuntimeTurnRequest(
            agent: AgentProfile(
                id: "security",
                name: "Security",
                role: "Security",
                runtime: .codex,
                instructions: "Pressure-test trust boundaries."
            ),
            conversationRoot: URL(fileURLWithPath: "/tmp/riff"),
            baselinePrompt: "base prompt",
            conversationPrompt: "debate this",
            context: "",
            attachmentPath: "files/turn-001.security.codex.md"
        ),
        includeInstructions: true
    )

    #expect(prompt.contains("base prompt"))
    #expect(prompt.contains("ROLE_NAME:\nSecurity"))
    #expect(prompt.contains("ROLE_PROMPT:\nPressure-test trust boundaries."))
}

@Test func freshRuntimePromptListsSupportFolderPaths() {
    let prompt = RuntimePromptBuilder.prompt(
        for: RuntimeTurnRequest(
            agent: AgentProfile(
                id: "security",
                name: "Security",
                role: "Security",
                runtime: .codex,
                instructions: "Pressure-test trust boundaries."
            ),
            conversationRoot: URL(fileURLWithPath: "/tmp/riff"),
            baselinePrompt: "base prompt",
            conversationPrompt: "debate this",
            context: "",
            attachmentPath: "files/turn-001.security.codex.md",
            supportFolders: [URL(fileURLWithPath: "/Users/me/research")]
        ),
        includeInstructions: true
    )

    #expect(prompt.contains("Support folders:"))
    #expect(prompt.contains("/Users/me/research"))
}

@Test func SummaryRuntimePromptUsesSummaryPromptAndFullContext() {
    let prompt = RuntimePromptBuilder.prompt(
        for: RuntimeTurnRequest(
            purpose: .summary,
            agent: AgentProfile(
                id: "a1",
                name: "First Agent",
                role: "For",
                runtime: .claude,
                instructions: "Summarize neutrally."
            ),
            conversationRoot: URL(fileURLWithPath: "/tmp/riff"),
            baselinePrompt: "summary instructions",
            conversationPrompt: "Will we get AGI?",
            context: "You: keep it simple\n\nFirst Agent: yes\n\nSecond Agent: no",
            attachmentPath: "files/summary.md"
        ),
        includeInstructions: true
    )

    #expect(prompt.contains("summary instructions"))
    #expect(prompt.contains("SUMMARY_AGENT_PROMPT:\nSummarize neutrally."))
    #expect(prompt.contains("Debate prompt:\nWill we get AGI?"))
    #expect(prompt.contains("Full conversation:\nYou: keep it simple"))
    #expect(!prompt.contains("ROLE_PROMPT"))
    #expect(!prompt.contains("Response contract"))
    #expect(!prompt.contains("files/summary.md"))
}

private func hasPair(_ args: [String], _ key: String, _ value: String) -> Bool {
    zip(args, args.dropFirst()).contains { $0 == key && $1 == value }
}

private actor FakeProcessClient: ProcessClient {
    var results: [String: ProcessResult]
    var invocations: [ProcessInvocation] = []

    init(results: [String: ProcessResult]) {
        self.results = results
    }

    func run(_ invocation: ProcessInvocation) async throws -> ProcessResult {
        invocations.append(invocation)
        let key = ([invocation.command] + invocation.arguments).joined(separator: " ")
        return results[key] ?? ProcessResult(stdout: "", exitCode: 1)
    }

    func commands() -> [String] {
        invocations.map(\.command)
    }
}
