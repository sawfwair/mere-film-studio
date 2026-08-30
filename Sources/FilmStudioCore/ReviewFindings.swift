import Foundation

/// Per-shot verdicts from the local vision inspector
/// (`mere.run/film-media-inspection.v1`).
public struct FilmMediaInspection: Decodable, Sendable, Equatable {
    public struct Summary: Decodable, Sendable, Equatable {
        public let passed: Int
        public let review: Int
        public let shots: Int
    }

    public struct Mismatch: Decodable, Sendable, Equatable {
        public let code: String
        public let message: String
        public let severity: String
    }

    public struct Shot: Decodable, Sendable, Equatable, Identifiable {
        public let shotId: String
        /// "pass" or "review"; kept raw so newer verdicts still decode.
        public let decision: String
        public let confidence: Double
        public let frame: String?
        public let frameSha256: String?
        public let mismatches: [Mismatch]
        public let observations: [String]?

        public var id: String { shotId }

        public var flagged: Bool { decision != "pass" }
    }

    public let contractVersion: String
    public let complete: Bool
    public let summary: Summary?
    public let shots: [Shot]
}

/// The technical QC report for the current master. Check details vary per
/// check and are deliberately not decoded; the loudness measurement is the
/// one detail the UI reports.
public struct FilmTechnicalQC: Decodable, Sendable, Equatable {
    public struct Check: Decodable, Sendable, Equatable, Identifiable {
        public let name: String
        public let passed: Bool

        public var id: String { name }
    }

    public struct Master: Decodable, Sendable, Equatable {
        public let path: String
        public let bytes: Int64?
        public let durationSeconds: Double?
        public let sha256: String?
    }

    public let contractVersion: String?
    public let passed: Bool
    public let checks: [Check]
    public let master: Master?
    /// Integrated loudness of the master in LUFS, when the analysis ran.
    public let measuredLUFS: Double?

    enum CodingKeys: String, CodingKey {
        case contractVersion, passed, checks, master, loudnessAnalysis
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        contractVersion = try values.decodeIfPresent(String.self, forKey: .contractVersion)
        passed = try values.decode(Bool.self, forKey: .passed)
        checks = try values.decode([Check].self, forKey: .checks)
        master = try values.decodeIfPresent(Master.self, forKey: .master)
        let loudness = (try? values.decodeIfPresent(QCLoudness.self, forKey: .loudnessAnalysis)).flatMap { $0 }
        measuredLUFS = loudness?.measurement?.inputI.flatMap(Double.init)
    }
}

private struct QCLoudnessMeasurement: Decodable {
    let inputI: String?

    enum CodingKeys: String, CodingKey {
        case inputI = "input_i"
    }
}

private struct QCLoudness: Decodable {
    let measurement: QCLoudnessMeasurement?
}

/// Loads the review evidence documents the ledger points at. A missing or
/// unreadable document returns nil: the review UI degrades to the proof
/// checklist rather than failing the section.
public enum ReviewFindingsLoader {
    public static func mediaInspection(in snapshot: FilmWorkspaceSnapshot) -> FilmMediaInspection? {
        decodeLatest(FilmMediaInspection.self, kind: .mediaInspection, in: snapshot)
    }

    public static func technicalQC(in snapshot: FilmWorkspaceSnapshot) -> FilmTechnicalQC? {
        decodeLatest(FilmTechnicalQC.self, kind: .technicalReview, in: snapshot)
    }

    private static func decodeLatest<T: Decodable>(
        _ type: T.Type,
        kind: ArtifactKind,
        in snapshot: FilmWorkspaceSnapshot
    ) -> T? {
        guard let artifact = snapshot.latestArtifact(kind: kind) else { return nil }
        let url = snapshot.artifactURL(artifact)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
