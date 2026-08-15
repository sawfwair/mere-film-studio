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
        case .overview: "sparkles.rectangle.stack"
        case .story: "text.book.closed"
        case .shots: "rectangle.stack.badge.play"
        case .sound: "waveform"
        case .review: "checkmark.seal"
        case .delivery: "shippingbox"
        }
    }
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
    @Published var handoffReceipt: AnimaticImportReceipt?
    @Published var handoffValidation: AnimaticImportReceipt?
    @Published var selectedShotID: String?
    @Published var terminalSessionID = UUID()
    @Published var piRoomConfiguration: PiRoomConfiguration?
    @Published var terminalSetupError: String?

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

    private var watcher: FilmWorkspaceWatcher?
    private var commandTask: Task<Void, Never>?
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
            openProject(URL(fileURLWithPath: last), reportErrors: false)
        }
    }

    deinit {
        commandTask?.cancel()
        piSetupTask?.cancel()
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
        do {
            let normalized = url.lastPathComponent == "run.json" ? url : url.appending(path: "run.json")
            let loaded = try FilmProjectLoader.load(runManifest: normalized)
            let projectChanged = loaded.runManifest != snapshot?.runManifest
            if projectChanged {
                terminalSessionID = UUID()
                piRoomConfiguration = nil
            }
            snapshot = loaded
            selectedShotID = selectedShotID ?? loaded.productionPlan?.shots.first?.id
            UserDefaults.standard.set(loaded.runManifest.path, forKey: "lastFilmRunManifest")
            watcher = FilmWorkspaceWatcher(root: loaded.root) { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
            if projectChanged || piRoomConfiguration == nil {
                preparePiRoom()
            }
            errorMessage = nil
        } catch {
            if reportErrors { errorMessage = error.localizedDescription }
        }
    }

    func closeProject() {
        watcher = nil
        snapshot = nil
        selectedShotID = nil
        piRoomConfiguration = nil
        terminalSetupError = nil
        piSetupTask?.cancel()
        UserDefaults.standard.removeObject(forKey: "lastFilmRunManifest")
    }

    func refresh() {
        guard let runManifest = snapshot?.runManifest else { return }
        openProject(runManifest)
    }

    func restartTerminal() {
        terminalSessionID = UUID()
    }

    func createFilm(idea: String, title: String, duration: Int, parentDirectory: URL) {
        perform("Creating the studio project…") { [filmToolExecutable, piExecutable] in
            let client = FilmToolClient(executable: filmToolExecutable)
            let pi = try PiExecutableResolver.resolve(piExecutable)
            let run = try await client.plan(
                idea: idea,
                title: title,
                durationSeconds: duration,
                outputDirectory: parentDirectory,
                piCommand: pi.path
            )
            await MainActor.run {
                self.showCreateFilm = false
                self.openProject(run)
            }
        }
    }

    func approve(gate: String) {
        guard let run = snapshot?.runManifest else { return }
        perform("Recording \(gate) approval…") { [filmToolExecutable] in
            try await FilmToolClient(executable: filmToolExecutable).approve(
                runManifest: run,
                gate: gate,
                note: "Explicitly approved in Mere Film Studio after reviewing the current evidence.",
                approvedBy: NSFullUserName().isEmpty ? "macOS user" : NSFullUserName()
            )
        }
    }

    func advance() {
        guard let run = snapshot?.runManifest else { return }
        guard let piRoomConfiguration else {
            errorMessage = StudioError.piRoomUnavailable.localizedDescription
            return
        }
        perform("Pi and the studio are advancing the film…") { [filmToolExecutable] in
            _ = try await FilmToolClient(executable: filmToolExecutable)
                .advance(
                    runManifest: run,
                    piCommand: piRoomConfiguration.piExecutable.path,
                    piProvider: "mere-run",
                    piModel: piRoomConfiguration.model.id
                )
        }
    }

    func recover() {
        guard let run = snapshot?.runManifest else { return }
        perform("Recovering interrupted studio work…") { [filmToolExecutable] in
            _ = try await FilmToolClient(executable: filmToolExecutable).recover(runManifest: run)
        }
    }

    func review() {
        guard let run = snapshot?.runManifest else { return }
        guard let piRoomConfiguration else {
            errorMessage = StudioError.piRoomUnavailable.localizedDescription
            return
        }
        perform("Running technical and independent creative review…") { [filmToolExecutable] in
            _ = try await FilmToolClient(executable: filmToolExecutable)
                .review(
                    runManifest: run,
                    piCommand: piRoomConfiguration.piExecutable.path,
                    piProvider: "mere-run",
                    piModel: piRoomConfiguration.model.id
                )
        }
    }

    func reroll(shotID: String, note: String) {
        guard let run = snapshot?.runManifest else { return }
        perform("Preparing a targeted reroll…") { [filmToolExecutable] in
            _ = try await FilmToolClient(executable: filmToolExecutable)
                .reroll(runManifest: run, shotID: shotID, note: note)
        }
    }

    func publishToAnimatic() {
        guard let snapshot else { return }
        perform("Verifying assets and publishing to Animatic…") { [filmToolExecutable, animaticExecutable] in
            let output = snapshot.root.appending(path: "exports/animatic/film-animatic-handoff.json")
            let export = try await FilmToolClient(executable: filmToolExecutable)
                .exportAnimatic(runManifest: snapshot.runManifest, output: output)
            let receipt = try await AnimaticClient(executable: animaticExecutable)
                .importFilm(manifest: URL(fileURLWithPath: export.manifest))
            await MainActor.run { self.handoffReceipt = receipt }
        }
    }

    func validateAnimaticHandoff() {
        guard let snapshot else { return }
        perform("Verifying the complete Animatic handoff…") { [filmToolExecutable, animaticExecutable] in
            let output = snapshot.root.appending(path: "exports/animatic/film-animatic-handoff.json")
            let export = try await FilmToolClient(executable: filmToolExecutable)
                .exportAnimatic(runManifest: snapshot.runManifest, output: output)
            let receipt = try await AnimaticClient(executable: animaticExecutable)
                .validateFilm(manifest: URL(fileURLWithPath: export.manifest))
            await MainActor.run { self.handoffValidation = receipt }
        }
    }

    private func perform(_ description: String, operation: @escaping @Sendable () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        activity = description
        errorMessage = nil
        commandTask?.cancel()
        commandTask = Task {
            do {
                try await operation()
                refresh()
            } catch is CancellationError {
                // A replacement task owns the activity indicator.
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
            activity = ""
        }
    }

    static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private final class FilmWorkspaceWatcher {
    private let descriptor: CInt
    private let source: DispatchSourceFileSystemObject

    init?(root: URL, onChange: @escaping @Sendable () -> Void) {
        descriptor = open(root.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue(label: "run.mere.filmstudio.project-watcher", qos: .utility)
        )
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { [descriptor] in close(descriptor) }
        source.resume()
    }

    deinit { source.cancel() }
}
