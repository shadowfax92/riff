import Foundation

public enum RuntimeRequirement {
    /// Returns runtimes needed by valid roles that are not currently available
    /// according to runtime detection.
    public static func missingRuntimes(
        roleDrafts: [RoleDraft],
        detectedRuntimes: [RuntimeID: DetectedRuntime]
    ) -> [RuntimeID] {
        let required = Set(roleDrafts.filter(\.isValid).map(\.runtime))
        return missingRuntimes(required: required, detectedRuntimes: detectedRuntimes)
    }

    /// Returns persisted agent runtimes that cannot currently run.
    public static func missingRuntimes(
        agents: [AgentProfile],
        detectedRuntimes: [RuntimeID: DetectedRuntime]
    ) -> [RuntimeID] {
        missingRuntimes(required: Set(agents.map(\.runtime)), detectedRuntimes: detectedRuntimes)
    }

    /// Builds the user-facing setup message shown before creating a debate.
    public static func settingsMessage(for missingRuntimes: [RuntimeID], action: String = "creating a Riff") -> String? {
        guard !missingRuntimes.isEmpty else {
            return nil
        }
        let names = missingRuntimes.map { $0.rawValue.capitalized }.joined(separator: " and ")
        return "\(names) unavailable. Set the missing executable path in Settings before \(action)."
    }

    private static func missingRuntimes(
        required: Set<RuntimeID>,
        detectedRuntimes: [RuntimeID: DetectedRuntime]
    ) -> [RuntimeID] {
        RuntimeID.allCases.filter { runtime in
            required.contains(runtime) && detectedRuntimes[runtime]?.available != true
        }
    }
}
