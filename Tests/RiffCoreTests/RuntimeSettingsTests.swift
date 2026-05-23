import Foundation
import Testing
@testable import RiffCore

@Test func runtimeSettingsDefaultPathsAreEmpty() {
    let settings = RuntimeSettings()

    #expect(settings.claudePath == "")
    #expect(settings.codexPath == "")
    #expect(settings.command(for: .claude) == "")
    #expect(settings.command(for: .codex) == "")
}

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

@Test func runtimeSettingsIgnoreLegacyCLIPath() throws {
    let data = #"{"cliPath":"/custom/bin:/usr/bin:/bin"}"#.data(using: .utf8)!

    let settings = try JSONDecoder().decode(RuntimeSettings.self, from: data)

    #expect(settings.claudePath == "")
    #expect(settings.codexPath == "")
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
