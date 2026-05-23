/// Runtime-specific CLI behavior behind the shared `RuntimeDefinition`
/// facade. Add new CLI runtimes by implementing this protocol instead of
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
