import Testing
@testable import RiffCore

@Test func runtimeRequirementBlocksUnavailableSelectedRuntime() {
    let drafts = [
        RoleDraft(id: "claude", roleName: "Claude", rolePrompt: "Argue", runtime: .claude),
        RoleDraft(id: "codex", roleName: "Codex", rolePrompt: "Critique", runtime: .codex),
    ]
    let detected: [RuntimeID: DetectedRuntime] = [
        .claude: DetectedRuntime(id: .claude, available: true, command: "claude", models: []),
        .codex: DetectedRuntime(id: .codex, available: false, command: "codex", models: []),
    ]

    let missing = RuntimeRequirement.missingRuntimes(roleDrafts: drafts, detectedRuntimes: detected)

    #expect(missing == [.codex])
}

@Test func runtimeRequirementIgnoresInvalidDrafts() {
    let drafts = [
        RoleDraft(id: "codex", roleName: "", rolePrompt: "", runtime: .codex),
    ]

    let missing = RuntimeRequirement.missingRuntimes(roleDrafts: drafts, detectedRuntimes: [:])

    #expect(missing.isEmpty)
}

@Test func runtimeRequirementMessageNamesMissingRuntimes() {
    #expect(RuntimeRequirement.settingsMessage(for: [.claude, .codex]) == "Claude and Codex unavailable. Set the missing executable path in Settings before creating a Riff.")
    #expect(RuntimeRequirement.settingsMessage(for: []) == nil)
}
