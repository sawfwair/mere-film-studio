import AppKit
import Combine
import FilmStudioCore
import Foundation

enum StudioSection: String, CaseIterable, Identifiable {
    case overview
    case story
    case shots
    case sound
    case review
    case delivery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Studio"
        case .story: "Development"
        case .shots: "Shots"
        case .sound: "Sound"
        case .review: "Review"
        case .delivery: "Delivery"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .story: "text.book.closed"
        case .shots: "rectangle.stack.badge.play"
        case .sound: "waveform"
        case .review: "checkmark.seal"
        case .delivery: "shippingbox"
        }
    }
}

/// An approval the human has been asked to confirm. Presented as a sheet so
/// gates are never approved sight-unseen and always carry a real note.
struct PendingApproval: Identifiable {
    let gate: FilmGate
    let summary: String?

    var id: String { gate.rawValue }
}

@MainActor
final class StudioModel: ObservableObject {
    @Published var snapshot: FilmWorkspaceSnapshot?
    @Published var section: StudioSection = .overview
    @Published var terminalVisible = true
    @Published var inspectorVisible = true
    @Published var showCreateFilm = false
    @Published var isBusy = false
    @Published var activity = ""
    @Published var errorMessage: String?
    @Published var fullErrorDetails: String?
    @Published var startupNotice: String?
    @Published var handoffReceipt: AnimaticImportReceipt?
    @Published var handoffValidation: AnimaticImportReceipt?
    @Published var selectedShotID: String?
    @Published var terminalSessionID = UUID()
    @Published var piRoomConfiguration: PiRoomConfiguration?
    @Published var terminalSetupError: String?
    @Published var pendingApproval: PendingApproval?
    @Published var approvalNote = ""
    @Published private(set) var watchingFiles = true

    @Published var filmToolExecutable: String {
        didSet {
            UserDefaults.standard.set(filmToolExecutable, forKey: "filmToolExecutable")
            preparePiRoom()
        }
    }
    @Published var animaticExecutable: String {
        didSet { UserDefaults.standard.set(animaticExecutable, forKey: "animaticExecutable") }
    }
    @Published var piExecutable: String {
        didSet {
            UserDefaults.standard.set(piExecutable, forKey: "piExecutable")
            preparePiRoom()
        }
    }
    @Published var mereRunExecutable: String {
        didSet {
            UserDefaults.standard.set(mereRunExecutable, forKey: "mereRunExecutable")
            preparePiRoom()
        }
    }

    /// The first not-yet-approved gate in contract order.
    var pendingGate: FilmGate? {
        guard let approvals = snapshot?.project.approvals else { return nil }
        return FilmGate.allCases.first { approvals[$0.rawValue]?.status == .pending }
    }

    private var watcher: FilmWorkspaceWatcher?
    /// Guards against a stale async load landing after the user switched
    /// projects; only the newest generation may publish a snapshot.
    private var loadGeneration = UUID()
    var commandTask: Task<Void, Never>?
    var piSetupTask: Task<Void, Never>?

    init() {
        filmToolExecutable = UserDefaults.standard.string(forKey: "filmToolExecutable") ?? "mere-film-tools"
        animaticExecutable = UserDefaults.standard.string(forKey: "animaticExecutable") ?? "animatic"
        piExecutable = UserDefaults.standard.string(forKey: "piExecutable") ?? "pi"
        mereRunExecutable = UserDefaults.standard.string(forKey: "mereRunExecutable")
            ?? ProcessInfo.processInfo.environment["MERE_RUN_EXECUTABLE"]
            ?? "mere.run"
        let arguments = ProcessInfo.processInfo.arguments
        let argumentManifest = arguments.firstIndex(of: "--run-manifest").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        let environmentManifest = ProcessInfo.processInfo.environment["MERE_FILM_RUN_MANIFEST"]
        if let startupManifest = argumentManifest ?? environmentManifest {
            openProject(URL(fileURLWithPath: startupManifest), reportErrors: true)
        } else if let last = UserDefaults.standard.string(forKey: "lastFilmRunManifest") {
            // Restoring silently is how people lose films; surface failures on
            // the welcome screen instead.
            openProject(URL(fileURLWithPath: last), reportErrors: false)
        }
    }

    func chooseProject() {
        let panel = NSOpenPanel()
        panel.title = "Open a Mere film"
        panel.message = "Choose the run.json created by mere-film-tools."
        panel.prompt = "Open Film"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openProject(url)
    }

    func openProject(_ url: URL, reportErrors: Bool = true) {
        let target = url.lastPathComponent == "run.json" ? url : url.appending(path: "run.json")
        let generation = UUID()
        loadGeneration = generation
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let standardized = target.standardizedFileURL
                // Decode off the main thread so large ledgers never block the
                // UI, even on slow volumes.
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try FilmProjectLoader.load(runManifest: standardized)
                }.value
                guard self.loadGeneration == generation else { return }
                self.applySnapshot(loaded)
                if !reportErrors { self.startupNotice = nil }
                self.errorMessage = nil
            } catch {
                // Watcher-driven refreshes race the tools' writes; a transient
                // decode failure must never interrupt work already on screen.
                if reportErrors {
                    self.errorMessage = Self.presentableMessage(error)
                    self.fullErrorDetails = String(describing: error)
                } else if self.snapshot == nil {
                    self.startupNotice = """
                        Couldn't reopen your last film (\(target.lastPathComponent)): \
                        \(Self.presentableMessage(error))
                        """
                }
            }
        }
    }

    /// Watcher events land here after debouncing. Failures keep the current
    /// snapshot and wait for the next event to retry.
    func refresh() {
        guard let runManifest = snapshot?.runManifest else { return }
        openProject(runManifest, reportErrors: false)
    }

    private func applySnapshot(_ loaded: FilmWorkspaceSnapshot) {
        let projectChanged = loaded.runManifest != snapshot?.runManifest
        if projectChanged {
            terminalSessionID = UUID()
            piRoomConfiguration = nil
            handoffReceipt = nil
            handoffValidation = nil
        }
        snapshot = loaded
        selectedShotID = selectedShotID ?? loaded.productionPlan?.shots.first?.id
        UserDefaults.standard.set(loaded.runManifest.path, forKey: "lastFilmRunManifest")
        do {
            watcher = try FilmWorkspaceWatcher(root: loaded.root) { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
            watchingFiles = true
        } catch {
            watcher = nil
            watchingFiles = false
        }
        if projectChanged || piRoomConfiguration == nil {
            preparePiRoom()
        }
    }

    func closeProject() {
        watcher = nil
        snapshot = nil
        selectedShotID = nil
        piRoomConfiguration = nil
        terminalSetupError = nil
        startupNotice = nil
        handoffReceipt = nil
        handoffValidation = nil
        piSetupTask?.cancel()
        commandTask?.cancel()
        UserDefaults.standard.removeObject(forKey: "lastFilmRunManifest")
    }

    func restartTerminal() {
        // A restart request when setup failed means "try setting up again",
        // not just "recycle the session".
        if piRoomConfiguration == nil || terminalSetupError != nil {
            preparePiRoom()
        }
        terminalSessionID = UUID()
    }

    func cancelRunning() {
        commandTask?.cancel()
    }
}
