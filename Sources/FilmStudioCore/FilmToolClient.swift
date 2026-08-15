import Foundation

public struct ProcessResult: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var succeeded: Bool { exitCode == 0 }
}

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

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let name): "Required executable not found: \(name)"
        case .launchFailed(let message): "Could not launch film command: \(message)"
        case .commandFailed(let result): result.stderr.isEmpty
            ? "Film command exited \(result.exitCode)."
            : result.stderr
        case .invalidJSON(let message): "Film command returned invalid JSON: \(message)"
        }
    }
}

public struct FilmToolClient: Sendable {
    public let executable: String

    public init(executable: String = "mere-film-tools") {
        self.executable = executable
    }

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
        let result = try await run(arguments)
        let response: FilmPlanResponse = try decode(FilmPlanResponse.self, from: result.stdout)
        return URL(fileURLWithPath: response.status.runManifest)
    }

    public func status(runManifest: URL) async throws -> FilmStatusResponse {
        let result = try await run(["status", runManifest.path])
        return try decode(FilmStatusResponse.self, from: result.stdout)
    }

    public func approve(runManifest: URL, gate: String, note: String, approvedBy: String) async throws {
        _ = try await run([
            "approve", runManifest.path,
            "--gate", gate,
            "--note", note,
            "--approved-by", approvedBy,
        ])
    }

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
        return try await run(arguments, environment: Self.piEnvironment(provider: piProvider, model: piModel))
    }

    public func recover(runManifest: URL) async throws -> ProcessResult {
        try await run(["recover", runManifest.path])
    }

    public func reroll(runManifest: URL, shotID: String, note: String) async throws -> ProcessResult {
        try await run(["reroll", runManifest.path, "--shot", shotID, "--note", note])
    }

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
        return try await run(arguments, environment: Self.piEnvironment(provider: piProvider, model: piModel))
    }

    public func exportAnimatic(runManifest: URL, output: URL? = nil) async throws -> FilmAnimaticExportReceipt {
        var arguments = ["export-animatic", runManifest.path]
        if let output {
            arguments.append(contentsOf: ["--output", output.path])
        }
        let result = try await run(arguments)
        return try decode(FilmAnimaticExportReceipt.self, from: result.stdout)
    }

    public func agentArguments(runManifest: URL, piCommand: String? = nil) -> [String] {
        var arguments = ["agent", "--run-manifest", runManifest.path]
        if let piCommand {
            arguments.append(contentsOf: ["--pi-command", piCommand])
        }
        return arguments
    }

    public func agentLaunchSpec(runManifest: URL, piCommand: String) async throws -> PiAgentLaunchSpec {
        let executableURL = try Self.resolveExecutable(executable)
        let result = try await Task.detached(priority: .userInitiated) {
            try Self.runSynchronously(
                executableURL: executableURL,
                arguments: Self.agentLaunchArguments(
                    runManifest: runManifest,
                    piCommand: piCommand,
                    pluginCommand: executableURL.path
                ),
                environment: [:]
            )
        }.value
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

    public func run(
        _ arguments: [String],
        environment: [String: String] = [:]
    ) async throws -> ProcessResult {
        let executableURL = try Self.resolveExecutable(executable)
        return try await Task.detached(priority: .userInitiated) {
            try Self.runSynchronously(
                executableURL: executableURL,
                arguments: arguments,
                environment: environment
            )
        }.value
    }

    private static func runSynchronously(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]
    ) throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, override in override }
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw FilmToolError.launchFailed(error.localizedDescription)
        }

        let output = LockedData()
        let errors = LockedData()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            output.set(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errors.set(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }

        process.waitUntilExit()
        group.wait()
        let result = ProcessResult(
            executable: executableURL.path,
            arguments: arguments,
            exitCode: process.terminationStatus,
            stdout: String(decoding: output.value, as: UTF8.self),
            stderr: String(decoding: errors.value, as: UTF8.self)
        )
        guard result.succeeded else { throw FilmToolError.commandFailed(result) }
        return result
    }

    private static func piEnvironment(provider: String?, model: String?) -> [String: String] {
        var environment: [String: String] = [:]
        if let provider { environment["MERE_FILM_TOOLS_PI_PROVIDER"] = provider }
        if let model { environment["MERE_FILM_TOOLS_PI_MODEL"] = model }
        return environment
    }

    public static func resolveExecutable(_ value: String) throws -> URL {
        let expanded = NSString(string: value).expandingTildeInPath
        if expanded.contains("/") {
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
            throw FilmToolError.executableNotFound(value)
        }

        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let search = environmentPath.split(separator: ":").map(String.init) + [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
        ]
        for directory in search {
            let candidate = URL(fileURLWithPath: directory).appending(path: value)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        throw FilmToolError.executableNotFound(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: Data(text.utf8))
        } catch {
            throw FilmToolError.invalidJSON(error.localizedDescription)
        }
    }
}

public enum PiExecutableResolver {
    public static func resolve(_ value: String = "pi") throws -> URL {
        if let executable = try? FilmToolClient.resolveExecutable(value) {
            return executable
        }
        guard value == "pi", let bundled = bundledCandidates().first else {
            throw FilmToolError.executableNotFound(value)
        }
        return bundled
    }

    static func bundledCandidates(
        in agentsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/MereRun/agents/pi")
    ) -> [URL] {
        let versions = (try? FileManager.default.contentsOfDirectory(
            at: agentsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return versions
            .sorted { isNewer($0.lastPathComponent, than: $1.lastPathComponent) }
            .map { $0.appending(path: "pi/pi") }
            .filter { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func versionComponents(_ value: String) -> [Int] {
        value
            .trimmingPrefix("v")
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }

    private static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let lhsComponents = versionComponents(lhs)
        let rhsComponents = versionComponents(rhs)
        for (left, right) in zip(lhsComponents, rhsComponents) where left != right {
            return left > right
        }
        return lhsComponents.count > rhsComponents.count
    }
}

public struct FilmAnimaticExportReceipt: Codable, Sendable, Equatable {
    public let ok: Bool
    public let contractVersion: String
    public let manifest: String
    public let manifestSha256: String
    public let projectId: String
    public let shots: Int
    public let assets: Int
    public let bytes: Int64
    public let runId: String?
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var value: Data {
        lock.withLock { storage }
    }

    func set(_ data: Data) {
        lock.withLock { storage = data }
    }
}

public struct FilmStatusResponse: Codable, Sendable, Equatable {
    public let contractVersion: String
    public let runId: String
    public let projectId: String
    public let title: String
    public let status: String
    public let phase: String
    public let nextGate: String?
    public let openQuestions: [String]
    public let approvals: [String: FilmApproval]
    public let taskCounts: [String: Int]
    public let shots: Int
    public let reviewRequests: [FilmReviewRequest]
    public let jobs: Int
    public let artifacts: Int
    public let issues: [FilmIssue]
    public let proof: FilmProof
    public let productionMode: String
    public let takesPerShot: Int
    public let projectDirectory: String
    public let runManifest: String
    public let reviewPackage: String?
}
