import Foundation

/// Owns one child `Process` so that task cancellation and timeouts can reach
/// it with SIGTERM even while the caller is suspended awaiting exit.
///
/// Termination escalates: SIGTERM first, then SIGKILL after a grace period,
/// so a child that ignores polite requests cannot wedge Cancel — Cancel is
/// the only bound long production commands have (DECISIONS.md 008).
///
/// JUSTIFIED: @unchecked Sendable — all mutable state below is lock-guarded;
/// `terminate()` is called from arbitrary threads (the cancellation handler,
/// a timeout timer) while `runAndWait` blocks elsewhere.
final class ChildProcessRunner: @unchecked Sendable {
    private let executableURL: URL
    private let arguments: [String]
    private let environment: [String: String]
    private let killGracePeriod: TimeInterval

    private let lock = NSLock()
    private var process: Process?
    private var terminatedBeforeStart = false
    private var terminatedByCancel = false
    private var terminatedByTimeout = false

    init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        killGracePeriod: TimeInterval = 5
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.killGracePeriod = killGracePeriod
    }

    /// Requests termination. Safe to call before, during, or after `runAndWait`.
    func terminate() {
        lock.withLock {
            if let process {
                terminatedByCancel = true
                Self.terminate(process, escalatingAfter: killGracePeriod)
            } else {
                terminatedBeforeStart = true
            }
        }
    }

    /// SIGTERM now; SIGKILL if the child is still alive after the grace
    /// period, because Cancel must always win.
    private static func terminate(_ process: Process, escalatingAfter grace: TimeInterval) {
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + grace) {
            if process.isRunning { kill(pid, SIGKILL) }
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
        let (output, errors, drained) = drainPipes(stdout: stdoutPipe, stderr: stderrPipe)

        process.waitUntilExit()
        let (timedOut, cancelled) = lock.withLock {
            self.process = nil
            return (terminatedByTimeout, terminatedByCancel)
        }

        if timedOut || cancelled || Task.isCancelled {
            // Surviving grandchildren can hold the pipes open indefinitely;
            // nobody reads cancelled output, so give the drains a moment and
            // then abandon them rather than wedging the cancel.
            _ = drained.wait(timeout: .now() + 3)
            if timedOut { throw FilmToolError.timedOut(seconds: Int(timeout ?? 0)) }
            throw CancellationError()
        }

        drained.wait()
        return try finishedResult(process: process, output: output.value, errors: errors.value)
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
            guard let self else { return }
            self.lock.withLock {
                self.terminatedByTimeout = true
                if let process = self.process {
                    Self.terminate(process, escalatingAfter: self.killGracePeriod)
                }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: item)
        return item
    }

    /// Reads both pipes toward EOF on parallel threads, appending as chunks
    /// arrive so partial output survives an abandoned drain.
    private func drainPipes(stdout: Pipe, stderr: Pipe) -> (output: LockedData, errors: LockedData, drained: DispatchGroup) {
        // JUSTIFIED: chunked appends per box, lock-guarded.
        let output = LockedData()
        let errors = LockedData()
        let group = DispatchGroup()
        for (pipe, box) in [(stdout, output), (stderr, errors)] {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let handle = pipe.fileHandleForReading
                while let chunk = try? handle.read(upToCount: 65_536), !chunk.isEmpty {
                    box.append(chunk)
                }
                group.leave()
            }
        }
        return (output, errors, group)
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

/// Chunk-append boxes for the concurrent pipe drains above. The lock makes
/// each append and the final read well-defined; each box has one writer.
///
/// JUSTIFIED: @unchecked Sendable — NSLock-guarded storage, one writer thread.
private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var value: Data {
        lock.withLock { storage }
    }

    func append(_ data: Data) {
        lock.withLock { storage.append(data) }
    }
}
