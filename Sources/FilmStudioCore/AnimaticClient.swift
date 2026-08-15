import Foundation

public struct AnimaticImportReceipt: Codable, Sendable, Equatable {
    public let ok: Bool
    public let projectId: String
    public let episodeId: String?
    public let importedScenes: Int?
    public let importedShots: Int?
    public let importedAssets: Int?
    public let projectURL: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case projectId = "project_id"
        case episodeId = "episode_id"
        case importedScenes = "imported_scenes"
        case importedShots = "imported_shots"
        case importedAssets = "imported_assets"
        case projectURL = "project_url"
    }
}

public struct AnimaticClient: Sendable {
    public let executable: String

    public init(executable: String = "animatic") {
        self.executable = executable
    }

    public func importFilm(manifest: URL) async throws -> AnimaticImportReceipt {
        try await runImport(manifest: manifest, dryRun: false)
    }

    public func validateFilm(manifest: URL) async throws -> AnimaticImportReceipt {
        try await runImport(manifest: manifest, dryRun: true)
    }

    private func runImport(manifest: URL, dryRun: Bool) async throws -> AnimaticImportReceipt {
        let executableURL = try FilmToolClient.resolveExecutable(executable)
        let runner = FilmToolClient(executable: executableURL.path)
        var arguments = ["production", "import-film", manifest.path]
        if dryRun { arguments.append("--dry-run") }
        arguments.append(contentsOf: ["--output", "json"])
        let result = try await runner.run(arguments)
        do {
            return try JSONDecoder().decode(AnimaticImportReceipt.self, from: Data(result.stdout.utf8))
        } catch {
            throw FilmToolError.invalidJSON(error.localizedDescription)
        }
    }
}
