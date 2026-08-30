import Foundation
import Testing
@testable import FilmStudioCore

/// Exercises the real child-process machinery with /bin/sh stub scripts, so
/// timeouts and cancellation are verified against actual process semantics.
struct ProcessExecutionTests {
    /// Writes an executable shell script that outlives any reasonable test
    /// duration but reacts to SIGTERM within ~100ms by touching a sentinel.
    private func longRunningScript(sentinel: String) throws -> URL {
        let script = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-runner-\(UUID().uuidString).sh")
        // Short sleep slices let a trapped TERM run promptly; `sleep 30` would
        // defer the trap until the whole sleep finishes on some shells.
        let body = """
        #!/bin/sh
        trap 'touch "\(sentinel)"; exit 143' TERM
        i=0
        while [ "$i" -lt 600 ]; do sleep 0.1; i=$((i+1)); done
        """
        try Data(body.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }

    private func waitForSentinel(_ path: String, timeout: TimeInterval = 5) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path) { return true }
            try await Task.sleep(for: .milliseconds(25))
        }
        return false
    }

    @Test func timeoutStopsTheChildAndReportsTimedOut() async throws {
        let sentinel = FileManager.default.temporaryDirectory
            .appending(path: "timeout-\(UUID().uuidString).sentinel").path
        let script = try longRunningScript(sentinel: sentinel)
        defer {
            try? FileManager.default.removeItem(at: script)
            try? FileManager.default.removeItem(atPath: sentinel)
        }

        let client = FilmToolClient(executable: "/bin/sh")
        await #expect(throws: FilmToolError.timedOut(seconds: 1)) {
            _ = try await client.run([script.path], timeout: 1)
        }
        // The SIGTERM must actually reach the child, not just abandon it.
        let terminated = try await waitForSentinel(sentinel)
        #expect(terminated)
    }

    @Test func taskCancellationTerminatesTheChild() async throws {
        let sentinel = FileManager.default.temporaryDirectory
            .appending(path: "cancel-\(UUID().uuidString).sentinel").path
        let script = try longRunningScript(sentinel: sentinel)
        defer {
            try? FileManager.default.removeItem(at: script)
            try? FileManager.default.removeItem(atPath: sentinel)
        }

        let client = FilmToolClient(executable: "/bin/sh")
        let task = Task {
            try await client.run([script.path])
        }
        // Give the child time to install its trap before pulling the plug.
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()

        await #expect(throws: CancellationError.self) { _ = try await task.value }
        let terminated = try await waitForSentinel(sentinel)
        #expect(terminated)
    }

    @Test func nonzeroExitSurfacesStderrAsCommandFailure() async throws {
        let script = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-fail-\(UUID().uuidString).sh")
        try Data("#!/bin/sh\necho 'boom detail' >&2\nexit 3\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        defer { try? FileManager.default.removeItem(at: script) }

        let client = FilmToolClient(executable: "/bin/sh")
        do {
            _ = try await client.run([script.path])
            Issue.record("expected commandFailed")
        } catch let error as FilmToolError {
            guard case .commandFailed(let result) = error else {
                Issue.record("expected commandFailed, got \(error)")
                return
            }
            #expect(result.exitCode == 3)
            #expect(result.stderr.contains("boom detail"))
        }
    }

    @Test func planDecodesCurrentFilmToolEnvelope() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-plan-tests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let expected = root.appending(path: "paper-beacon/run.json")
        let executable = root.appending(path: "mere-film-tools")
        let payload = "{\"status\":{\"runManifest\":\"\(expected.path)\"}}"
        let script = "#!/bin/sh\nprintf '%s\\n' '\(payload)'\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let actual = try await FilmToolClient(executable: executable.path).plan(
            idea: "A paper boat becomes a lighthouse.",
            title: "Paper Beacon",
            durationSeconds: 15,
            outputDirectory: root,
            piCommand: "/managed/pi"
        )

        #expect(actual == expected)
    }

    @Test func agentLaunchSeparatesPiRuntimeFromFilmToolCallback() {
        let arguments = FilmToolClient.agentLaunchArguments(
            runManifest: URL(fileURLWithPath: "/tmp/film/run.json"),
            piCommand: "/managed/pi",
            pluginCommand: "/tools/mere-film-tools"
        )

        #expect(arguments == [
            "agent", "--run-manifest", "/tmp/film/run.json",
            "--pi-command", "/managed/pi",
            "--plugin-command", "/tools/mere-film-tools",
            "--print-command",
        ])
    }
}
