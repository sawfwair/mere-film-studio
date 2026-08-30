import Foundation

/// Owns one child `Process` so that task cancellation and timeouts can reach
/// it with SIGTERM even while the caller is suspended awaiting exit.
///
/// JUSTIFIED: @unchecked Sendable — all mutable state below is lock-guarded;
/// `terminate()` is called from arbitrary threads (the cancellation handler,
/// a timeout timer) while `runAndWait` blocks elsewhere.
final class ChildProcessRunner: @unchecked Sendable {
    private let executableURL: URL
    private let arguments: [String]
    private let environment: [String: String]

    private let lock = NSLock()
    private var process: Process?
    private var terminatedBeforeStart = false
    private var terminatedByCancel = false
    private var terminatedByTimeout = false

    init(executableURL: URL, arguments: [String], environment: [String: String]) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
    }

    /// Requests termination. Safe to call before, during, or after `runAndWait`.
    func terminate() {
        lock.withLock {
            if let process {
                terminatedByCancel = true
                process.terminate()
            } else {
                terminatedBeforeStart = true
            }
        }
    }

    /// Blocking. Must run off the main thread (callers detach a task).
    func runAndWait(timeout: TimeInterval?) throws -> ProcessResult {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let process = try launch(stdoutPipe: stdoutPipe, stderrPipe: stderrPipe)

        let timeoutItem = armTimeout(timeout)
        defer { timeoutItem?.cancel() }

        // Drain both pipes concurrently: waiting for exit first would deadlock
        // once a pipe buffer fills. Each read runs to EOF on its own thread.
        let (output, errors) = drainPipes(stdout: stdoutPipe, stderr: stderrPipe)

        process.waitUntilExit()
        lock.withLock { self.process = nil }

        if terminatedByTimeout {
            throw FilmToolError.timedOut(seconds: Int(timeout ?? 0))
        }
        if terminatedByCancel || Task.isCancelled {
            throw CancellationError()
        }

        return try finishedResult(process: process, output: output, errors: errors)
    }

    private func launch(stdoutPipe: Pipe, stderrPipe: Pipe) throws -> Process {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, override in override }
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        lock.lock()
        if terminatedBeforeStart {
            lock.unlock()
            throw CancellationError()
        }
        terminatedByCancel = false
        self.process = process
        lock.unlock()

        do {
            try process.run()
        } catch {
            lock.withLock { self.process = nil }
            throw FilmToolError.launchFailed(error.localizedDescription)
        }
        return process
    }

    private func armTimeout(_ timeout: TimeInterval?) -> DispatchWorkItem? {
        guard let timeout else { return nil }
        let item = DispatchWorkItem { [weak self] in
            self?.lock.withLock {
                self?.terminatedByTimeout = true
                self?.process?.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: item)
        return item
    }

    /// Reads both pipes to EOF on parallel threads. Waiting for exit first
    /// would deadlock once a pipe buffer fills.
    private func drainPipes(stdout: Pipe, stderr: Pipe) -> (output: Data, errors: Data) {
        // JUSTIFIED: single handoff per box, no shared mutation beyond set().
        let output = LockedData()
        let errors = LockedData()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            output.set(stdout.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errors.set(stderr.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.wait()
        return (output.value, errors.value)
    }

    private func finishedResult(process: Process, output: Data, errors: Data) throws -> ProcessResult {
        let result = ProcessResult(
            executable: executableURL.path,
            arguments: arguments,
            exitCode: process.terminationStatus,
            stdout: String(decoding: output, as: UTF8.self),
            stderr: String(decoding: errors, as: UTF8.self)
        )
        guard result.succeeded else { throw FilmToolError.commandFailed(result) }
        return result
    }
}

/// Single-writer boxes for the concurrent pipe drains above. The lock exists
/// only to make the handoff of each finished `Data` well-defined; the reads
/// themselves are independent.
///
/// JUSTIFIED: @unchecked Sendable — NSLock-guarded storage, one writer thread.
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
