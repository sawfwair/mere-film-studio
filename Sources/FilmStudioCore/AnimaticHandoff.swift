import CryptoKit
import Foundation

public struct AnimaticHandoff: Codable, Sendable, Equatable {
    public let contractVersion: String
    public let exportedAt: String
    public let source: AnimaticHandoffSource
    public let project: AnimaticHandoffProject
    public let cast: [FilmCastMember]
    public let locations: [FilmLocation]
    public let shots: [AnimaticHandoffShot]
    public let assets: [AnimaticHandoffAsset]
    public let proof: FilmProof
}

public struct AnimaticHandoffSource: Codable, Sendable, Equatable {
    public let projectId: String
    public let projectRoot: String
    public let runManifest: String
    public let projectContractVersion: String
    public let updatedAt: String
}

public struct AnimaticHandoffProject: Codable, Sendable, Equatable {
    public let title: String
    public let idea: String
    public let logline: String?
    public let synopsis: String?
    public let theme: String?
    public let durationMilliseconds: Int
    public let fps: Int
    public let aspectRatio: String
    public let width: Int?
    public let height: Int?
}

public struct AnimaticHandoffShot: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let order: Int
    public let purpose: String
    public let prompt: String
    public let framePrompt: String
    public let timelineStartMilliseconds: Int
    public let durationMilliseconds: Int
    public let characterIds: [String]
    public let locationId: String
    public let transition: String
    public let take: Int
    public let seed: Int
    public let keyframeAssetId: String?
    public let clipAssetId: String?
    public let dialogue: [FilmDialogueLine]
    public let soundEffects: [FilmSoundEffect]
}

public struct AnimaticHandoffAsset: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: String
    public let relativePath: String
    public let sha256: String
    public let bytes: Int64
    public let contentType: String
    public let source: String
}

public enum AnimaticHandoffError: LocalizedError, Equatable {
    case productionPlanMissing
    case unsafeArtifactPath(String)
    case missingArtifact(String)
    case hashMismatch(path: String, expected: String, actual: String)
    case sizeMismatch(path: String, expected: Int64, actual: Int64)

    public var errorDescription: String? {
        switch self {
        case .productionPlanMissing: "An accepted production plan is required before publishing to Animatic."
        case .unsafeArtifactPath(let path): "The handoff contains an unsafe artifact path: \(path)"
        case .missingArtifact(let path): "The handoff artifact is missing: \(path)"
        case .hashMismatch(let path, let expected, let actual):
            "Artifact hash mismatch for \(path). Expected \(expected), got \(actual)."
        case .sizeMismatch(let path, let expected, let actual):
            "Artifact size mismatch for \(path). The ledger records \(expected) bytes, the file has \(actual)."
        }
    }
}

public enum AnimaticHandoffBuilder {
    public static func build(
        from snapshot: FilmWorkspaceSnapshot,
        projectRoot: String = ".",
        exportedAt: String? = nil
    ) throws -> AnimaticHandoff {
        guard let plan = snapshot.productionPlan else { throw AnimaticHandoffError.productionPlanMissing }
        // Re-hashing every exported artifact here is the whole point of the
        // handoff: Animatic never receives a manifest we haven't verified.
        let assets = try verifiedAssets(in: snapshot)

        let assetsByPath = Dictionary(uniqueKeysWithValues: assets.map { ($0.relativePath, $0) })
        var cursor = 0
        let shots = plan.shots.enumerated().map { index, shot in
            let duration = Int((shot.durationSeconds * 1_000).rounded())
            defer { cursor += duration }
            return AnimaticHandoffShot(
                id: shot.id,
                order: index,
                purpose: shot.purpose,
                prompt: shot.prompt,
                framePrompt: shot.framePrompt,
                timelineStartMilliseconds: cursor,
                durationMilliseconds: duration,
                characterIds: shot.characters,
                locationId: shot.location,
                transition: shot.transition,
                take: shot.take,
                seed: shot.selectedSeed ?? shot.seed,
                keyframeAssetId: assetsByPath["frames/\(shot.id).png"]?.id,
                clipAssetId: assetsByPath["clips/\(shot.id).mp4"]?.id,
                dialogue: shot.dialogue,
                soundEffects: shot.soundEffects
            )
        }

        return AnimaticHandoff(
            contractVersion: "mere.run/film-animatic-handoff.v1",
            exportedAt: exportedAt ?? ISO8601DateFormatter().string(from: Date()),
            source: AnimaticHandoffSource(
                projectId: snapshot.project.projectId,
                projectRoot: projectRoot,
                runManifest: "run.json",
                projectContractVersion: snapshot.project.contractVersion,
                updatedAt: snapshot.project.updatedAt
            ),
            project: AnimaticHandoffProject(
                title: snapshot.project.title,
                idea: snapshot.project.idea,
                logline: snapshot.treatment?.logline,
                synopsis: snapshot.treatment?.synopsis,
                theme: snapshot.treatment?.theme,
                // The cursor is the sum of the per-shot roundings; deriving
                // the total from plannedDurationSeconds independently could
                // disagree with the timeline by a few milliseconds.
                durationMilliseconds: cursor,
                fps: plan.target.fps ?? 24,
                aspectRatio: plan.target.aspectRatio ?? "16:9",
                width: plan.target.width,
                height: plan.target.height
            ),
            cast: plan.cast,
            locations: plan.locations,
            shots: shots,
            assets: assets,
            proof: snapshot.project.proof
        )
    }

    private static func verifiedAssets(in snapshot: FilmWorkspaceSnapshot) throws -> [AnimaticHandoffAsset] {
        // Rerolls and resumed runs can append a second ledger entry for the
        // same path; only the newest one can still match the bytes on disk,
        // and downstream lookups key assets by path.
        let exportable = snapshot.project.artifacts.filter { ArtifactKind.exportable.contains($0.kind) }
        var seen = Set<String>()
        let latestPerPath = Array(exportable.reversed().filter { seen.insert($0.path).inserted }.reversed())
        return try latestPerPath
            .map { artifact in
                try validate(artifact: artifact, in: snapshot)
                return AnimaticHandoffAsset(
                    id: try stableAssetID(artifact),
                    kind: artifact.kind.rawValue,
                    relativePath: artifact.path,
                    sha256: artifact.sha256,
                    bytes: artifact.bytes,
                    contentType: artifact.contentType,
                    source: artifact.source
                )
            }
    }

    public static func write(_ handoff: AnimaticHandoff, to url: URL) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(handoff)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return try sha256(file: url)
    }

    public static func sha256(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(file url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return "sha256:" + hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func validate(artifact: FilmArtifact, in snapshot: FilmWorkspaceSnapshot) throws {
        guard !artifact.path.hasPrefix("/"), !artifact.path.split(separator: "/").contains("..") else {
            throw AnimaticHandoffError.unsafeArtifactPath(artifact.path)
        }
        let url = snapshot.artifactURL(artifact)
        let resolvedRoot = snapshot.root.resolvingSymlinksInPath().standardizedFileURL.path
        let resolvedArtifact = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolvedArtifact.hasPrefix(resolvedRoot + "/") else {
            throw AnimaticHandoffError.unsafeArtifactPath(artifact.path)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AnimaticHandoffError.missingArtifact(artifact.path)
        }
        let actualBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
        if let actualBytes, actualBytes != artifact.bytes {
            throw AnimaticHandoffError.sizeMismatch(path: artifact.path, expected: artifact.bytes, actual: actualBytes)
        }
        let actual = try sha256(file: url)
        guard actual == artifact.sha256 else {
            throw AnimaticHandoffError.hashMismatch(path: artifact.path, expected: artifact.sha256, actual: actual)
        }
    }

    private static func stableAssetID(_ artifact: FilmArtifact) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: ["path": artifact.path, "sha256": artifact.sha256],
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        let digest = sha256(data).replacingOccurrences(of: "sha256:", with: "")
        return "film_asset_\(digest.prefix(20))"
    }
}
