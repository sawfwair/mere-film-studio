import AppKit
import FilmStudioCore
import Foundation

// MARK: - Film operations

@MainActor
extension StudioModel {
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

    /// Presents the approval sheet for a gate. Actual recording happens in
    /// `confirmPendingApproval` once the human has seen the evidence summary.
    func requestApproval(gate: FilmGate) {
        guard !isBusy else { return }
        approvalNote = ""
        pendingApproval = PendingApproval(
            gate: gate,
            summary: snapshot?.project.approvals[gate.rawValue]?.summary
        )
    }

    func confirmPendingApproval() {
        guard let pending = pendingApproval else { return }
        pendingApproval = nil
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
            await MainActor.run { self.handoffReceipt = receipt }
        }
    }

    func validateAnimaticHandoff() {
        guard let snapshot else { return }
        perform("Verifying the complete Animatic handoff…") { [animaticExecutable] in
            let manifest = try await Self.writeVerifiedHandoff(snapshot: snapshot)
            let receipt = try await AnimaticClient(executable: animaticExecutable)
                .validateFilm(manifest: manifest)
            await MainActor.run { self.handoffValidation = receipt }
        }
    }

    private static func writeVerifiedHandoff(snapshot: FilmWorkspaceSnapshot) async throws -> URL {
        let output = snapshot.root.appending(path: "exports/animatic/film-animatic-handoff.json")
        return try await Task.detached(priority: .userInitiated) {
            let handoff = try AnimaticHandoffBuilder.build(from: snapshot)
            _ = try AnimaticHandoffBuilder.write(handoff, to: output)
            return output
        }.value
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
