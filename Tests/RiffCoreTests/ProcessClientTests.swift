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

private func processClientTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "riff-process-client-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
