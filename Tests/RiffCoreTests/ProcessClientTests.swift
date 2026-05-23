import Foundation
import Testing
@testable import RiffCore

@Test func processClientUsesConfiguredPathForBareCommands() async throws {
    let home = try processClientTemporaryDirectory()
    let bin = home.appending(path: ".local/bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    let command = bin.appending(path: "riff-path-probe")
    try """
    #!/bin/sh
    echo ok
    """.write(to: command, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: command.path)

    let client = FoundationProcessClient(environment: [
        "HOME": home.path,
        "PATH": "\(bin.path):/usr/bin:/bin:/usr/sbin:/sbin",
    ])

    let result = try await client.run(ProcessInvocation(command: "riff-path-probe", arguments: []))

    #expect(result.exitCode == 0)
    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "ok")
}

@Test func processClientTerminatesTimedOutProcesses() async throws {
    let client = FoundationProcessClient()
    let start = Date()

    let result = try await client.run(ProcessInvocation(
        command: "/bin/sleep",
        arguments: ["5"],
        timeout: 0.2
    ))

    #expect(Date().timeIntervalSince(start) < 2)
    #expect(result.exitCode != 0)
}

@Test func processClientTerminatesCancelledProcesses() async throws {
    let client = FoundationProcessClient()
    let start = Date()
    let task = Task {
        try await client.run(ProcessInvocation(command: "/bin/sleep", arguments: ["2"]))
    }

    try await Task.sleep(for: .milliseconds(100))
    task.cancel()

    do {
        _ = try await task.value
        Issue.record("Expected cancellation to throw")
    } catch is CancellationError {
        #expect(Date().timeIntervalSince(start) < 1)
    }
}

@Test func processClientWritesCommandLifecycleLogsAndPrunesOldFiles() async throws {
    let directory = try processClientTemporaryDirectory()
    let oldLog = directory.appending(path: "runtime-2001-01-01.log")
    try #"{"event":"old"}"#.write(to: oldLog, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.modificationDate: Date().addingTimeInterval(-2 * 24 * 60 * 60)],
        ofItemAtPath: oldLog.path
    )
    let logger = FileProcessLogger(directoryURL: directory)
    let client = FoundationProcessClient(logger: logger)

    let result = try await client.run(ProcessInvocation(
        command: "/bin/echo",
        arguments: ["ok"],
        stdin: "do not log prompt"
    ))

    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "ok")
    #expect(!FileManager.default.fileExists(atPath: oldLog.path))
    let entries = try processLogEntries(in: directory)
    #expect(entries.count == 2)
    if entries.count == 2 {
        #expect(entries.map { $0["event"] as? String } == ["start", "finish"])
        #expect(entries[0]["command"] as? String == "/bin/echo")
        #expect(entries[0]["arguments"] as? [String] == ["ok"])
        #expect(entries[0]["stdinBytes"] as? Int == "do not log prompt".utf8.count)
        #expect(entries[0]["stdin"] == nil)
        #expect(entries[1]["exitCode"] as? Int == 0)
        #expect(entries[1]["stdoutBytes"] as? Int == 3)
    }
}

private func processClientTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "riff-process-client-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func processLogEntries(in directory: URL) throws -> [[String: Any]] {
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("runtime-") }
    let lines = try files.flatMap { file in
        try String(contentsOf: file, encoding: .utf8).split(separator: "\n").map(String.init)
    }
    return try lines.map { line in
        let data = try #require(line.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
