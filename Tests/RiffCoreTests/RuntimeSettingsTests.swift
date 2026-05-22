import Foundation
import Testing
@testable import RiffCore

@Test func runtimeSettingsDecodeExplicitBinaryPaths() throws {
    let data = """
    {
      "claudePath": "/Users/me/.local/bin/claude",
      "codexPath": "/Users/me/.local/bin/codex"
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(RuntimeSettings.self, from: data)

    #expect(settings.claudePath == "/Users/me/.local/bin/claude")
    #expect(settings.codexPath == "/Users/me/.local/bin/codex")
    #expect(settings.command(for: .claude) == "/Users/me/.local/bin/claude")
    #expect(settings.command(for: .codex) == "/Users/me/.local/bin/codex")
}

@Test func runtimeSettingsMigratesLegacyCLIPath() throws {
    let root = try temporaryDirectory()
    let bin = root.appending(path: "bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    let claude = bin.appending(path: "claude")
    let codex = bin.appending(path: "codex")
    try "".write(to: claude, atomically: true, encoding: .utf8)
    try "".write(to: codex, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: claude.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: codex.path)
    let data = #"{"cliPath":"\#(bin.path):/usr/bin:/bin"}"#.data(using: .utf8)!

    let settings = try JSONDecoder().decode(RuntimeSettings.self, from: data)

    #expect(settings.claudePath == claude.path)
    #expect(settings.codexPath == codex.path)
}

@Test func runtimeSettingsEncodeDoesNotWriteLegacyCLIPath() throws {
    let settings = RuntimeSettings(
        claudePath: "/Users/me/.local/bin/claude",
        codexPath: "/Users/me/.local/bin/codex"
    )

    let data = try JSONEncoder().encode(settings)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

    #expect(object["claudePath"] == "/Users/me/.local/bin/claude")
    #expect(object["codexPath"] == "/Users/me/.local/bin/codex")
    #expect(object["cliPath"] == nil)
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "riff-runtime-settings-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
