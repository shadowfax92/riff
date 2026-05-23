import Foundation
import RiffCore

enum RoleDraftFactory {
    /// Creates the first role shown in the New Riff sheet.
    static func initial() -> RoleDraft {
        make(runtime: .claude, model: "default", reasoning: nil)
    }

    /// Creates another role while carrying forward the runtime settings the
    /// user just chose, so repeated roles do not bounce between runtimes.
    static func additional(after previous: RoleDraft?) -> RoleDraft {
        make(
            runtime: previous?.runtime ?? .claude,
            model: previous?.model ?? "default",
            reasoning: previous?.reasoning
        )
    }

    private static func make(runtime: RuntimeID, model: String, reasoning: String?) -> RoleDraft {
        let identity = RoleNameGenerator.generate()
        return RoleDraft(
            id: UUID().uuidString.lowercased(),
            roleName: identity.name,
            rolePrompt: "",
            runtime: runtime,
            model: model,
            reasoning: reasoning,
            emoji: identity.emoji
        )
    }
}
