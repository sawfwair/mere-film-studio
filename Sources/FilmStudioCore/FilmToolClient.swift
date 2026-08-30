import Foundation

/// The result of one completed CLI invocation, both streams captured.
public struct ProcessResult: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var succeeded: Bool { exitCode == 0 }
}

/// Launch specification for embedding Pi as an agent inside a film run.
public struct PiAgentLaunchSpec: Codable, Sendable, Equatable {
    public let command: [String]
    public let cwd: String
    public let environment: [String: String]
}

struct FilmPlanResponse: Decodable, Sendable, Equatable {
    struct Status: Decodable, Sendable, Equatable {
        let runManifest: String
    }

    let status: Status
}

public enum FilmToolError: LocalizedError, Equatable {
    case executableNotFound(String)
    case launchFailed(String)
    case commandFailed(ProcessResult)
    case invalidJSON(String)
    case timedOut(seconds: Int)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let name): "Required executable not found: \(name)"
        case .launchFailed(let message): "Could not launch film command: \(message)"
        case .commandFailed(let result): result.stderr.isEmpty
            ? "Film command exited \(result.exitCode)."
            : result.stderr
        case .invalidJSON(let message): "Film command returned invalid JSON: \(message)"
        case .timedOut(let seconds): "Film command exceeded its \(seconds)-second limit and was stopped."
        }
    }
}

/// Provider passed to mere-film-tools whenever the studio drives Pi itself.
public extension FilmToolClient {
    static let defaultPiProvider = "mere-run"
}

/// Typed client for the `mere-film-tools` CLI. Every method decodes stdout
/// into contract types; stderr surfaces through `FilmToolError.commandFailed`.
///
/// Cancellation: all commands are task-cancellable; cancelling terminates the
/// child process. Timeouts: auxiliary commands bound themselves; long
/// production commands (`advance`, `review`) are intentionally unbounded —
/// see DECISIONS.md entry 008.
public struct FilmToolClient: Sendable {
    public let executable: String

    public init(executable: String = "mere-film-tools") {
        self.executable = executable
    }

    /// Creates a new film project directory and returns its run manifest.
    public func plan(
        idea: String,
        title: String,
        durationSeconds: Int,
        outputDirectory: URL,
        piCommand: String? = nil
    ) async throws -> URL {
        var arguments = [
            "plan",
            "--idea", idea,
            "--title", title,
            "--duration", String(durationSeconds),
            "--output-dir", outputDirectory.path,
        ]
        if let piCommand {
            arguments.append(contentsOf: ["--pi-command", piCommand])
        }
        // Planning bootstraps a whole project directory; give it room, but
        // never hang forever.
        let result = try await run(arguments, timeout: 1_800)
        let response: FilmPlanResponse = try decode(FilmPlanResponse.self, from: result.stdout)
        return URL(fileURLWithPath: response.status.runManifest)
    }

    /// Records a human gate approval in the project ledger.
    public func approve(runManifest: URL, gate: String, note: String, approvedBy: String) async throws {
        _ = try await run([
            "approve", runManifest.path,
            "--gate", gate,
            "--note", note,
            "--approved-by", approvedBy,
        ], timeout: 600)
    }

    /// Advances production up to the next gate. Unbounded by design.
    public func advance(
        runManifest: URL,
        piCommand: String? = nil,
        piProvider: String? = nil,
        piModel: String? = nil
    ) async throws -> ProcessResult {
        var arguments = ["run", runManifest.path]
        if let piCommand {
            arguments.append(contentsOf: ["--pi-command", piCommand])
        }
        return try await run(
            arguments,
            environment: Self.piEnvironment(provider: piProvider, model: piModel)
        )
    }

    /// Resumes a run interrupted mid-command.
    public func recover(runManifest: URL) async throws -> ProcessResult {
        try await run(["recover", runManifest.path], timeout: 600)
    }

    /// Queues a targeted regeneration of one shot.
    public func reroll(runManifest: URL, shotID: String, note: String) async throws -> ProcessResult {
        try await run(["reroll", runManifest.path, "--shot", shotID, "--note", note], timeout: 600)
    }

    /// Runs technical QC plus independent creative review of the current cut.
    /// Unbounded by design.
    public func review(
        runManifest: URL,
        piCommand: String? = nil,
        piProvider: String? = nil,
        piModel: String? = nil
    ) async throws -> ProcessResult {
        var arguments = ["review", runManifest.path]
        if let piCommand {
            arguments.append(contentsOf: ["--pi-command", piCommand])
        }
        return try await run(
            arguments,
            environment: Self.piEnvironment(provider: piProvider, model: piModel)
        )
    }

    public func agentArguments(runManifest: URL, piCommand: String? = nil) -> [String] {
        var arguments = ["agent", "--run-manifest", runManifest.path]
        if let piCommand {
            arguments.append(contentsOf: ["--pi-command", piCommand])
        }
        return arguments
    }

    /// Asks the tools for the exact launch command that embeds this run's Pi
    /// agent, so the terminal and headless paths execute identical machinery.
    public func agentLaunchSpec(runManifest: URL, piCommand: String) async throws -> PiAgentLaunchSpec {
        let result = try await run(Self.agentLaunchArguments(
            runManifest: runManifest,
            piCommand: piCommand,
            pluginCommand: try Self.resolveExecutable(executable).path
        ), timeout: 120)
        return try decode(PiAgentLaunchSpec.self, from: result.stdout)
    }

    static func agentLaunchArguments(
        runManifest: URL,
        piCommand: String,
        pluginCommand: String
    ) -> [String] {
        [
            "agent", "--run-manifest", runManifest.path,
            "--pi-command", piCommand,
            "--plugin-command", pluginCommand,
            "--print-command",
        ]
    }

    /// Runs the tool to completion. `timeout` bounds wall-clock runtime;
    /// passing `nil` leaves the command unbounded (still cancellable through
    /// task cancellation, which terminates the child process).
    public func run(
        _ arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult {
        let executableURL = try Self.resolveExecutable(executable)
        let runner = ChildProcessRunner(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment
        )
        return try await withTaskCancellationHandler {
            // A dedicated thread, not Task.detached: runAndWait blocks until
            // the child exits, and parking that on the cooperative pool can
            // starve it entirely on small machines (three concurrent runs
            // occupy every thread of a 3-core pool, and no other task — not
            // even the cancellation that would end the wait — can run).
            try await withCheckedThrowingContinuation { continuation in
                Thread.detachNewThread {
                    continuation.resume(with: Result { try runner.runAndWait(timeout: timeout) })
                }
            }
        } onCancel: {
            runner.terminate()
        }
    }

    private static func piEnvironment(provider: String?, model: String?) -> [String: String] {
        var environment: [String: String] = [:]
        if let provider { environment["MERE_FILM_TOOLS_PI_PROVIDER"] = provider }
        if let model { environment["MERE_FILM_TOOLS_PI_MODEL"] = model }
        return environment
    }

    /// Single-quotes a value for `/bin/sh -c` consumption.
    public static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Resolves a bare name or path to an executable URL. Paths (including
    /// tilde forms) are used as-is; bare names search an augmented PATH that
    /// covers GUI-app blind spots (see `searchDirectories`).
    public static func resolveExecutable(_ value: String) throws -> URL {
        let expanded = NSString(string: value).expandingTildeInPath
        if expanded.contains("/") {
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
            throw FilmToolError.executableNotFound(value)
        }

        let search = Self.searchDirectories()
        for directory in search {
            let candidate = URL(fileURLWithPath: directory).appending(path: value)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        throw FilmToolError.executableNotFound(value)
    }

    /// GUI apps inherit a skeletal PATH, so augment it with the directories
    /// where CLI tools actually live on developer Macs: Homebrew, the classic
    /// Unix paths, ~/.local/bin, ~/bin, and every Node install managed by nvm.
    static func searchDirectories(
        environmentPath: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [String] {
        var directories = environmentPath.split(separator: ":").map(String.init)
        directories += [
            home.appending(path: ".local/bin").path,
            home.appending(path: "bin").path,
        ]
        let nodeVersions = (try? FileManager.default.contentsOfDirectory(
            at: home.appending(path: ".nvm/versions/node"),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        directories += nodeVersions
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .map { $0.appending(path: "bin").path }
        directories += [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
        ]
        var seen = Set<String>()
        return directories.filter { seen.insert($0).inserted }
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: Data(text.utf8))
        } catch {
            throw FilmToolError.invalidJSON(error.localizedDescription)
        }
    }
}
