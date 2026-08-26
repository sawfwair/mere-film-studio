import Foundation

/// Watches the project directory and reports changes after a short debounce,
/// so bursty tool writes trigger one reload instead of dozens.
final class FilmWorkspaceWatcher {
    enum WatcherError: LocalizedError {
        case startFailed

        var errorDescription: String? {
            "File watching could not start for this project. Use Refresh (⌘R) to see updates."
        }
    }

    private static let debounceInterval: TimeInterval = 0.4

    private let descriptor: CInt
    private let source: DispatchSourceFileSystemObject
    private let queue = DispatchQueue(label: "run.mere.filmstudio.project-watcher", qos: .utility)
    private var pendingChange: DispatchWorkItem?

    init(root: URL, onChange: @escaping @Sendable () -> Void) throws {
        descriptor = open(root.path, O_EVTONLY)
        guard descriptor >= 0 else { throw WatcherError.startFailed }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.schedule(onChange)
        }
        source.setCancelHandler { [descriptor] in close(descriptor) }
        source.resume()
    }

    deinit { source.cancel() }

    private func schedule(_ change: @escaping @Sendable () -> Void) {
        pendingChange?.cancel()
        let item = DispatchWorkItem(block: change)
        pendingChange = item
        queue.asyncAfter(deadline: .now() + Self.debounceInterval, execute: item)
    }
}
