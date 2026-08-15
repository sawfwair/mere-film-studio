import FilmStudioCore
import Foundation

extension StudioModel {
    var terminalCommand: String? {
        guard let configuration = piRoomConfiguration,
              let prompt = configuration.launchSpec.command.last,
              configuration.launchSpec.command.count >= 2 else { return nil }
        var arguments = [
            configuration.mereRunExecutable.path,
            "agent", "start",
            "--inline",
            "--no-bootstrap",
            "--model", configuration.model.id,
            "--pi-path", configuration.piExecutable.path,
            "--working-directory", configuration.launchSpec.cwd,
            "--prompt", prompt,
        ]
        for argument in configuration.launchSpec.command.dropFirst().dropLast() {
            arguments.append(contentsOf: ["--pi-argument", argument])
        }
        return arguments
            .map(Self.shellEscape)
            .joined(separator: " ")
    }

    var terminalEnvironment: [String: String] {
        guard let configuration = piRoomConfiguration else { return [:] }
        return configuration.launchSpec.environment.merging([
            "MERE_FILM_TOOLS_PI_PROVIDER": "mere-run",
            "MERE_FILM_TOOLS_PI_MODEL": configuration.model.id,
        ]) { _, override in override }
    }

    var piRoomModelLabel: String {
        piRoomConfiguration.map { "\($0.model.displayName) · \($0.model.id)" }
            ?? "Preparing local agent…"
    }

    var terminalUnavailableReason: String {
        if let terminalSetupError { return terminalSetupError }
        if (try? FilmToolClient.resolveExecutable(filmToolExecutable)) == nil {
            return "Set a valid mere-film-tools executable in Settings."
        }
        if (try? FilmToolClient.resolveExecutable(mereRunExecutable)) == nil {
            return "Set the branch-built mere.run executable in Settings."
        }
        if (try? PiExecutableResolver.resolve(piExecutable)) == nil {
            return "Set a valid Pi executable in Settings. MereRun-managed Pi installations are detected automatically."
        }
        return "Preparing the branch-built mere.run provider and film harness…"
    }

    func preparePiRoom() {
        guard let runManifest = snapshot?.runManifest else { return }
        piSetupTask?.cancel()
        piRoomConfiguration = nil
        terminalSetupError = nil
        let filmToolExecutable = filmToolExecutable
        let mereRunExecutable = mereRunExecutable
        let piExecutable = piExecutable
        piSetupTask = Task {
            do {
                let pi = try PiExecutableResolver.resolve(piExecutable)
                let mereRun = try FilmToolClient.resolveExecutable(mereRunExecutable)
                async let launchSpec = FilmToolClient(executable: filmToolExecutable)
                    .agentLaunchSpec(runManifest: runManifest, piCommand: pi.path)
                async let status = MereRunAgentClient(executable: mereRun.path).status()
                let (resolvedLaunchSpec, resolvedStatus) = try await (launchSpec, status)
                guard let model = resolvedStatus.bestInstalledModel else {
                    throw StudioError.noInstalledAgentModel
                }
                try Task.checkCancellation()
                guard snapshot?.runManifest == runManifest else { return }
                piRoomConfiguration = PiRoomConfiguration(
                    launchSpec: resolvedLaunchSpec,
                    mereRunExecutable: mereRun,
                    piExecutable: pi,
                    model: model
                )
                terminalSessionID = UUID()
            } catch is CancellationError {
                return
            } catch {
                terminalSetupError = error.localizedDescription
            }
        }
    }
}

struct PiRoomConfiguration: Sendable {
    let launchSpec: PiAgentLaunchSpec
    let mereRunExecutable: URL
    let piExecutable: URL
    let model: MereRunAgentModel
}

enum StudioError: LocalizedError {
    case piRoomUnavailable
    case noInstalledAgentModel

    var errorDescription: String? {
        switch self {
        case .piRoomUnavailable:
            "The local Pi room is not ready. Check the mere.run and Pi paths in Settings."
        case .noInstalledAgentModel:
            "The selected mere.run build did not report an installed, startable local agent model."
        }
    }
}
