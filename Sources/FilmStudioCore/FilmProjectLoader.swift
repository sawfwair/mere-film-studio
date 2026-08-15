import Foundation

public enum FilmProjectError: LocalizedError, Equatable {
    case missingRunManifest(URL)
    case missingProject(URL)
    case unsupportedContract(String)
    case invalidProject(String)

    public var errorDescription: String? {
        switch self {
        case .missingRunManifest(let url): "No run.json exists at \(url.path)."
        case .missingProject(let url): "No film-project.json exists at \(url.path)."
        case .unsupportedContract(let version): "Unsupported film contract: \(version)."
        case .invalidProject(let message): "The film project could not be read: \(message)"
        }
    }
}
public enum FilmProjectLoader {
    public static func load(runManifest input: URL) throws -> FilmWorkspaceSnapshot {
        let runManifest = input.standardizedFileURL
        guard FileManager.default.fileExists(atPath: runManifest.path) else {
            throw FilmProjectError.missingRunManifest(runManifest)
        }
        let root = runManifest.deletingLastPathComponent()
        let projectURL = root.appending(path: "film-project.json")
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw FilmProjectError.missingProject(projectURL)
        }

        do {
            let decoder = JSONDecoder()
            let project = try decoder.decode(FilmProject.self, from: Data(contentsOf: projectURL))
            guard project.contractVersion == "mere.run/film-project.v1" else {
                throw FilmProjectError.unsupportedContract(project.contractVersion)
            }
            let productionPlan: FilmProductionPlan? = try decodeIfPresent(
                FilmProductionPlan.self,
                at: root.appending(path: "production-plan.json"),
                using: decoder
            )
            let treatment: FilmTreatment? = try decodeIfPresent(
                FilmTreatment.self,
                at: root.appending(path: "treatment.json"),
                using: decoder
            )
            return FilmWorkspaceSnapshot(
                root: root,
                runManifest: runManifest,
                project: project,
                productionPlan: productionPlan,
                treatment: treatment
            )
        } catch let error as FilmProjectError {
            throw error
        } catch {
            throw FilmProjectError.invalidProject(error.localizedDescription)
        }
    }

    private static func decodeIfPresent<T: Decodable>(
        _ type: T.Type,
        at url: URL,
        using decoder: JSONDecoder
    ) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(type, from: Data(contentsOf: url))
    }
}
