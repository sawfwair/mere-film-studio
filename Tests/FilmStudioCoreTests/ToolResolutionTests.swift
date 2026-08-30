import Foundation
import Testing
@testable import FilmStudioCore

struct ToolResolutionTests {
    @Test func resolveExecutableFindsAbsolutePathsAndRejectsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-resolve-tests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let executable = root.appending(path: "tool")
        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let resolved = try FilmToolClient.resolveExecutable(executable.path)
        #expect(resolved.path == executable.path)

        #expect(throws: FilmToolError.self) {
            _ = try FilmToolClient.resolveExecutable(root.appending(path: "missing").path)
        }
        #expect(throws: FilmToolError.self) {
            _ = try FilmToolClient.resolveExecutable("~/definitely-not-a-tool-")
        }
    }

    @Test func searchDirectoriesAugmentsSparseGuiPath() throws {
        // /var is a symlink to /private/var on macOS and the directory scan
        // returns resolved URLs; create the tree first so both sides of the
        // comparison agree.
        let homeSeed = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-home-tests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: homeSeed.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: homeSeed.appending(path: ".nvm/versions/node/v24.15.0/bin"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: homeSeed.appending(path: ".nvm/versions/node/v20.0.0/bin"),
            withIntermediateDirectories: true
        )
        let home = homeSeed.resolvingSymlinksInPath()

        let directories = FilmToolClient.searchDirectories(
            environmentPath: "/usr/bin:/bin:/usr/bin",
            home: home
        )

        // Environment entries come first and duplicates are removed.
        #expect(directories.prefix(2) == ["/usr/bin", "/bin"])
        // GUI-PATH gaps are covered: local bin, nvm-managed Node (newest
        // first), and Homebrew. Compare by suffix since /var may be reported
        // as /private/var depending on how each directory was obtained.
        #expect(directories.contains { $0.hasSuffix("/.local/bin") })

        let nodeBins = directories.enumerated().filter { $0.element.contains("/.nvm/versions/node/") }
        #expect(nodeBins.count == 2)
        guard let newestIndex = nodeBins.firstIndex(where: { $0.element.hasSuffix("/v24.15.0/bin") }),
              let olderIndex = nodeBins.firstIndex(where: { $0.element.hasSuffix("/v20.0.0/bin") }) else {
            Issue.record("expected both nvm node bin directories in the search path")
            return
        }
        #expect(newestIndex < olderIndex)

        #expect(directories.contains("/opt/homebrew/bin"))
    }

    @Test func shellEscapesApostrophesAndQuotes() {
        #expect(FilmToolClient.shellEscape("/usr/local/bin/pi") == "'/usr/local/bin/pi'")
        #expect(FilmToolClient.shellEscape("/path with space/tool") == "'/path with space/tool'")
        #expect(FilmToolClient.shellEscape("it's") == "'it'\\''s'")
    }

    @Test func mereRunVersionComparisonPrefersNewerSemvers() {
        #expect(PiExecutableResolver.isNewer("v1.10.0", than: "v1.9.9"))
        #expect(PiExecutableResolver.isNewer("v1.2", than: "v1.1.5"))
        #expect(PiExecutableResolver.isNewer("v2", than: "v1.99"))
        #expect(!PiExecutableResolver.isNewer("v1.0", than: "v1.0"))
        // More components win ties so v1.0 outranks v1.
        #expect(PiExecutableResolver.isNewer("v1.0", than: "v1"))
        #expect(!PiExecutableResolver.isNewer("v1", than: "v1.0"))
        #expect(PiExecutableResolver.versionComponents("v0.8.12") == [0, 8, 12])
    }

    @Test func resolvesNewestMereRunManagedPi() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-pi-tests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for version in ["v0.9.0", "v0.10.0", "v0.8.12"] {
            let executable = root.appending(path: "\(version)/pi/pi")
            try FileManager.default.createDirectory(
                at: executable.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("#!/bin/sh\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        }

        let candidates = PiExecutableResolver.bundledCandidates(in: root)
        let selected = candidates.first?.resolvingSymlinksInPath().path
        let expected = root.appending(path: "v0.10.0/pi/pi").resolvingSymlinksInPath().path
        #expect(selected == expected)
    }

    @Test func selectsHighestTierInstalledMereRunAgentModel() throws {
        let payload = """
        {
          "models": [
            {
              "id": "small",
              "displayName": "Small",
              "installed": true,
              "recommendedUnifiedMemoryGB": 16,
              "servingEngine": "text-code",
              "startableByMereRun": true
            },
            {
              "id": "best-installed",
              "displayName": "Best Installed",
              "installed": true,
              "recommendedUnifiedMemoryGB": 64,
              "servingEngine": "text-chat",
              "startableByMereRun": true
            },
            {
              "id": "missing",
              "displayName": "Missing",
              "installed": false,
              "recommendedUnifiedMemoryGB": 128,
              "servingEngine": "text-chat",
              "startableByMereRun": true
            }
          ],
          "pi": {"installed": true, "path": "/tmp/pi", "version": "v0.79.0"}
        }
        """
        let status = try JSONDecoder().decode(MereRunAgentStatus.self, from: Data(payload.utf8))
        #expect(status.bestInstalledModel?.id == "best-installed")
    }
}
