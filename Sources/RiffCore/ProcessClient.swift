import Foundation

public struct ProcessInvocation: Equatable, Sendable {
    public var command: String
    public var arguments: [String]
    public var stdin: String?
    public var workingDirectory: URL?
    public var timeout: TimeInterval?

    public init(
        command: String,
        arguments: [String],
        stdin: String? = nil,
        workingDirectory: URL? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.command = command
        self.arguments = arguments
        self.stdin = stdin
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }
}

public struct ProcessResult: Equatable, Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32

    public init(stdout: String, stderr: String = "", exitCode: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public protocol ProcessClient {
    func run(_ invocation: ProcessInvocation) async throws -> ProcessResult
}

public enum ProcessClientError: Error, Equatable {
    case failedToDecodeOutput
}

public final class FoundationProcessClient: ProcessClient {
    public init() {}

    public func run(_ invocation: ProcessInvocation) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            if invocation.command.contains("/") {
                process.executableURL = URL(fileURLWithPath: invocation.command)
                process.arguments = invocation.arguments
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [invocation.command] + invocation.arguments
            }
            process.currentDirectoryURL = invocation.workingDirectory

            let stdout = Pipe()
            let stderr = Pipe()
            let stdin = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.standardInput = stdin

            process.terminationHandler = { process in
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                guard
                    let output = String(data: outputData, encoding: .utf8),
                    let error = String(data: errorData, encoding: .utf8)
                else {
                    continuation.resume(throwing: ProcessClientError.failedToDecodeOutput)
                    return
                }
                continuation.resume(returning: ProcessResult(stdout: output, stderr: error, exitCode: process.terminationStatus))
            }

            do {
                try process.run()
                if let input = invocation.stdin {
                    stdin.fileHandleForWriting.write(Data(input.utf8))
                }
                try stdin.fileHandleForWriting.close()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
