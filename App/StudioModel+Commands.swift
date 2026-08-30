import AppKit
import FilmStudioCore
import Foundation
import UniformTypeIdentifiers

// MARK: - Film operations

@MainActor
extension StudioModel {
    func createFilm(idea: String, title: String, duration: Int, parentDirectory: URL) {
        // No trailing refresh: the operation opens the new project itself, and
        // refreshing the previous film here would race that load and win.
        perform("Creating the studio project…", refreshes: false) { [filmToolExecutable, piExecutable] in
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

    /// Presents the approval sheet for a gate. Actual recording happens in
    /// `confirmPendingApproval` once the human has seen the evidence summary.
    func requestApproval(gate: FilmGate) {
        guard !isBusy, let snapshot else { return }
        approvalNote = ""
        pendingApproval = PendingApproval(
            runManifest: snapshot.runManifest,
            gate: gate,
            summary: snapshot.project.approvals[gate.rawValue]?.summary
        )
    }

    func confirmPendingApproval() {
        guard let pending = pendingApproval else { return }
        pendingApproval = nil
        guard snapshot?.runManifest == pending.runManifest else {
            errorMessage = "The open film changed while the approval sheet was up. Nothing was recorded."
            fullErrorDetails = nil
            return
        }
        approve(gate: pending.gate, note: approvalNote)
    }

    func approve(gate: FilmGate, note: String? = nil) {
        guard let run = snapshot?.runManifest else { return }
        let trimmed = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveNote = trimmed.isEmpty
            ? "Approved in Mere Film Studio without an added note."
            : trimmed
        perform("Recording \(gate.displayName.lowercased()) approval…") { [filmToolExecutable] in
            try await FilmToolClient(executable: filmToolExecutable).approve(
                runManifest: run,
                gate: gate.rawValue,
                note: effectiveNote,
                approvedBy: NSFullUserName().isEmpty ? "macOS user" : NSFullUserName()
            )
        }
    }

    func advance() {
        guard let run = snapshot?.runManifest else { return }
        guard let piRoomConfiguration else {
            errorMessage = StudioError.piRoomUnavailable.localizedDescription
            fullErrorDetails = nil
            return
        }
        perform("Pi and the studio are advancing the film…") { [filmToolExecutable] in
            _ = try await FilmToolClient(executable: filmToolExecutable)
                .advance(
                    runManifest: run,
                    piCommand: piRoomConfiguration.piExecutable.path,
                    piProvider: FilmToolClient.defaultPiProvider,
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
            fullErrorDetails = nil
            return
        }
        perform("Running technical and independent creative review…") { [filmToolExecutable] in
            _ = try await FilmToolClient(executable: filmToolExecutable)
                .review(
                    runManifest: run,
                    piCommand: piRoomConfiguration.piExecutable.path,
                    piProvider: FilmToolClient.defaultPiProvider,
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
        perform("Verifying assets and publishing to Animatic…") { [animaticExecutable] in
            // Build the handoff locally: every artifact is re-hashed before
            // Animatic ever sees the manifest.
            let manifest = try await Self.writeVerifiedHandoff(snapshot: snapshot)
            let receipt = try await AnimaticClient(executable: animaticExecutable)
                .importFilm(manifest: manifest)
            await MainActor.run {
                // Only show the receipt on the film it belongs to.
                if self.snapshot?.runManifest == snapshot.runManifest {
                    self.handoffReceipt = receipt
                }
            }
        }
    }

    func validateAnimaticHandoff() {
        guard let snapshot else { return }
        perform("Verifying the complete Animatic handoff…") { [animaticExecutable] in
            let manifest = try await Self.writeVerifiedHandoff(snapshot: snapshot)
            let receipt = try await AnimaticClient(executable: animaticExecutable)
                .validateFilm(manifest: manifest)
            await MainActor.run {
                if self.snapshot?.runManifest == snapshot.runManifest {
                    self.handoffValidation = receipt
                }
            }
        }
    }

    /// Copies the best playable cut wherever the human wants it, without a
    /// trip through Finder.
    func exportCurrentCut() {
        guard let snapshot, let cut = snapshot.playableCut else {
            errorMessage = "There is no playable cut to export yet."
            fullErrorDetails = nil
            return
        }
        let source = snapshot.artifactURL(cut)
        let panel = NSSavePanel()
        panel.title = "Export the current cut"
        panel.nameFieldStringValue = "\(snapshot.project.title).mp4"
        panel.allowedContentTypes = [.mpeg4Movie]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        perform("Exporting the current cut…") {
            try await Task.detached(priority: .userInitiated) {
                // The save panel already asked about replacing.
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: source, to: destination)
            }.value
            await MainActor.run {
                guard self.snapshot?.runManifest == snapshot.runManifest else { return }
                self.noticeMessage = "Exported the cut to \(destination.path)."
            }
        }
    }

    /// Re-hashes the newest ledger entry for every artifact path against the
    /// bytes on disk — the on-demand version of the product's promise that
    /// approved files can't change quietly.
    func verifyArtifacts() {
        guard let snapshot else { return }
        perform("Re-hashing every artifact against the ledger…") {
            let (checked, problems) = try await Task.detached(priority: .userInitiated) {
                try Self.artifactProblems(in: snapshot)
            }.value
            await MainActor.run {
                guard self.snapshot?.runManifest == snapshot.runManifest else { return }
                if problems.isEmpty {
                    self.noticeMessage = "All \(checked) artifacts match their recorded hashes."
                } else {
                    self.noticeMessage = Self.presentableText(
                        "\(problems.count) of \(checked) artifacts don't match the ledger:\n"
                            + problems.joined(separator: "\n")
                    )
                }
            }
        }
    }

    private nonisolated static func artifactProblems(
        in snapshot: FilmWorkspaceSnapshot
    ) throws -> (checked: Int, problems: [String]) {
        // Older entries for a re-recorded path are history, not the current
        // claim; only the newest entry per path is expected to match disk.
        var seen = Set<String>()
        let current = snapshot.project.artifacts.reversed().filter { seen.insert($0.path).inserted }.reversed()
        var problems: [String] = []
        for artifact in current {
            try Task.checkCancellation()
            let url = snapshot.artifactURL(artifact)
            guard FileManager.default.fileExists(atPath: url.path) else {
                problems.append("Missing: \(artifact.path)")
                continue
            }
            guard let actual = try? AnimaticHandoffBuilder.sha256(file: url) else {
                problems.append("Unreadable: \(artifact.path)")
                continue
            }
            if actual != artifact.sha256 {
                problems.append("Changed since recorded: \(artifact.path)")
            }
        }
        return (current.count, problems)
    }

    private static func writeVerifiedHandoff(snapshot: FilmWorkspaceSnapshot) async throws -> URL {
        let output = snapshot.root.appending(path: "exports/animatic/film-animatic-handoff.json")
        return try await Task.detached(priority: .userInitiated) {
            // The importer resolves projectRoot relative to the manifest's own
            // directory, and the manifest lives two levels below the project
            // root — "." here makes animatic look for exports/animatic/run.json.
            let handoff = try AnimaticHandoffBuilder.build(from: snapshot, projectRoot: "../..")
            _ = try AnimaticHandoffBuilder.write(handoff, to: output)
            return output
        }.value
    }

    private func perform(
        _ description: String,
        refreshes: Bool = true,
        operation: @escaping @Sendable () async throws -> Void
    ) {
        guard !isBusy else { return }
        isBusy = true
        activity = description
        errorMessage = nil
        fullErrorDetails = nil
        // The command belongs to the film that was open when it started; if
        // the human switches films meanwhile, don't refresh the new one over
        // a result it never asked for.
        let boundRun = snapshot?.runManifest
        commandTask?.cancel()
        commandTask = Task {
            do {
                try await operation()
                if refreshes, snapshot?.runManifest == boundRun { refresh() }
            } catch is CancellationError {
                // A replacement task or an explicit cancel owns the indicator.
            } catch {
                errorMessage = Self.presentableMessage(error)
                fullErrorDetails = String(describing: error)
            }
            isBusy = false
            activity = ""
        }
    }

    /// CLI stderr can be pages of JSON logs; alerts get a bounded excerpt.
    static func presentableMessage(_ error: Error) -> String {
        presentableText(error.localizedDescription)
    }

    static func presentableText(_ description: String) -> String {
        let limit = 800
        guard description.count > limit else { return description }
        let prefix = String(description.prefix(limit))
        // Prefer cutting at a line boundary so the excerpt stays readable.
        let lines = prefix.split(separator: "\n", omittingEmptySubsequences: false)
        let body = lines.count > 1 ? lines.dropLast().joined(separator: "\n") : prefix
        return body + "\n…\n(Output truncated — use Copy Details for everything.)"
    }

    static func shellEscape(_ value: String) -> String {
        FilmToolClient.shellEscape(value)
    }
}
