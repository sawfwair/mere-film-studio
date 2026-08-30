import Foundation

/// The five human gates of the film contract. Single source of truth for
/// ordering and display names — UI code must derive gate rails, "next gate"
/// pickers, and labels from here rather than restating the list.
public enum FilmGate: String, CaseIterable, Sendable, Identifiable {
    case brief
    case treatment
    case production
    case pictureLock = "picture-lock"
    case delivery

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .brief: "Brief"
        case .treatment: "Treatment"
        case .production: "Production"
        case .pictureLock: "Picture lock"
        case .delivery: "Delivery"
        }
    }
}

/// Immutable view of one film workspace on disk: the ledger plus the two
/// optional planning documents the UI renders directly.
public struct FilmWorkspaceSnapshot: Sendable, Equatable {
    public let root: URL
    public let runManifest: URL
    public let project: FilmProject
    public let productionPlan: FilmProductionPlan?
    public let treatment: FilmTreatment?

    public init(
        root: URL,
        runManifest: URL,
        project: FilmProject,
        productionPlan: FilmProductionPlan?,
        treatment: FilmTreatment?
    ) {
        self.root = root
        self.runManifest = runManifest
        self.project = project
        self.productionPlan = productionPlan
        self.treatment = treatment
    }

    /// Resolves an artifact's recorded path against the project root.
    public func artifactURL(_ artifact: FilmArtifact) -> URL {
        artifact.path.hasPrefix("/")
            ? URL(fileURLWithPath: artifact.path)
            : root.appending(path: artifact.path)
    }

    public func latestArtifact(kind: ArtifactKind) -> FilmArtifact? {
        project.artifacts.last { $0.kind == kind }
    }

    /// The best playable cut, in descending order of authority. Missing files
    /// are skipped so a stale ledger entry never breaks playback.
    public var playableCut: FilmArtifact? {
        for kind in [ArtifactKind.deliveryMaster, .finalMaster, .roughCut] {
            if let artifact = latestArtifact(kind: kind),
               FileManager.default.fileExists(atPath: artifactURL(artifact).path) {
                return artifact
            }
        }
        return nil
    }

    public var playableCutURL: URL? {
        playableCut.map(artifactURL)
    }
}

/// One film project as serialized in `film-project.json`. Field order and
/// optionality mirror the wire contract; unknown contract statuses decode
/// lossily (see `FilmContractStatus`).
public struct FilmProject: Decodable, Sendable, Equatable {
    public let contractVersion: String
    public let projectId: String
    public let title: String
    public let idea: String
    public let createdAt: String
    public let updatedAt: String
    public let status: FilmContractStatus
    /// Free-form narrative phase from the tools (e.g. "development"); kept as
    /// a raw string because the tools evolve phases independently of the app.
    public let phase: String
    public let brief: FilmBrief
    public let approvals: [String: FilmApproval]
    public let departments: [FilmDepartmentTask]
    public let shots: [FilmShotState]
    public let reviewRequests: [FilmReviewRequest]
    public let jobs: [FilmJob]
    public let production: FilmProductionConfiguration
    public let artifacts: [FilmArtifact]
    public let proof: FilmProof
    public let issues: [FilmIssue]

    public init(
        contractVersion: String,
        projectId: String,
        title: String,
        idea: String,
        createdAt: String,
        updatedAt: String,
        status: FilmContractStatus,
        phase: String,
        brief: FilmBrief,
        approvals: [String: FilmApproval],
        departments: [FilmDepartmentTask],
        shots: [FilmShotState],
        reviewRequests: [FilmReviewRequest],
        jobs: [FilmJob],
        production: FilmProductionConfiguration,
        artifacts: [FilmArtifact],
        proof: FilmProof,
        issues: [FilmIssue]
    ) {
        self.contractVersion = contractVersion
        self.projectId = projectId
        self.title = title
        self.idea = idea
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.phase = phase
        self.brief = brief
        self.approvals = approvals
        self.departments = departments
        self.shots = shots
        self.reviewRequests = reviewRequests
        self.jobs = jobs
        self.production = production
        self.artifacts = artifacts
        self.proof = proof
        self.issues = issues
    }
}

/// The creative brief. Decodes both wire shapes: the current nested form
/// (`target`/`creative` sub-objects) and the legacy flat form, preferring
/// nested values when both are present.
public struct FilmBrief: Decodable, Sendable, Equatable {
    public let audience: String?
    public let genre: String?
    public let tone: String?
    public let rating: String?
    public let language: String?
    public let platform: String?
    public let usage: String?
    public let targetDurationSeconds: Double?
    public let mustHaves: [String]
    public let exclusions: [String]
    public let references: [String]
    public let openQuestions: [String]

    enum CodingKeys: String, CodingKey {
        case audience, genre, tone, rating, language, platform, usage
        case targetDurationSeconds, mustHaves, exclusions, references, openQuestions
        case target, creative
    }

    private struct Target: Decodable {
        let audience: String?
        let durationSeconds: Double?
        let language: String?
        let platform: String?
        let rating: String?
        let usage: String?
    }

    private struct Creative: Decodable {
        let genre: String?
        let tone: String?
        let mustHaves: [String]?
        let exclusions: [String]?
        let references: [String]?
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let target = try values.decodeIfPresent(Target.self, forKey: .target)
        let creative = try values.decodeIfPresent(Creative.self, forKey: .creative)
        let flatAudience = try values.decodeIfPresent(String.self, forKey: .audience)
        let flatGenre = try values.decodeIfPresent(String.self, forKey: .genre)
        let flatTone = try values.decodeIfPresent(String.self, forKey: .tone)
        let flatRating = try values.decodeIfPresent(String.self, forKey: .rating)
        let flatLanguage = try values.decodeIfPresent(String.self, forKey: .language)
        let flatPlatform = try values.decodeIfPresent(String.self, forKey: .platform)
        let flatUsage = try values.decodeIfPresent(String.self, forKey: .usage)
        let flatDuration = try values.decodeIfPresent(Double.self, forKey: .targetDurationSeconds)
        let flatMustHaves = try values.decodeIfPresent([String].self, forKey: .mustHaves)
        let flatExclusions = try values.decodeIfPresent([String].self, forKey: .exclusions)
        let flatReferences = try values.decodeIfPresent([String].self, forKey: .references)
        audience = target?.audience ?? flatAudience
        genre = creative?.genre ?? flatGenre
        tone = creative?.tone ?? flatTone
        rating = target?.rating ?? flatRating
        language = target?.language ?? flatLanguage
        platform = target?.platform ?? flatPlatform
        usage = target?.usage ?? flatUsage
        targetDurationSeconds = target?.durationSeconds ?? flatDuration
        mustHaves = creative?.mustHaves ?? flatMustHaves ?? []
        exclusions = creative?.exclusions ?? flatExclusions ?? []
        references = creative?.references ?? flatReferences ?? []
        openQuestions = try values.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
    }

    public init(
        audience: String? = nil,
        genre: String? = nil,
        tone: String? = nil,
        rating: String? = nil,
        language: String? = nil,
        platform: String? = nil,
        usage: String? = nil,
        targetDurationSeconds: Double? = nil,
        mustHaves: [String] = [],
        exclusions: [String] = [],
        references: [String] = [],
        openQuestions: [String] = []
    ) {
        self.audience = audience
        self.genre = genre
        self.tone = tone
        self.rating = rating
        self.language = language
        self.platform = platform
        self.usage = usage
        self.targetDurationSeconds = targetDurationSeconds
        self.mustHaves = mustHaves
        self.exclusions = exclusions
        self.references = references
        self.openQuestions = openQuestions
    }
}

public struct FilmApproval: Codable, Sendable, Equatable {
    public let status: FilmContractStatus
    public let summary: String?
    public let requestedAt: String?
    public let approvedAt: String?
    public let approvedBy: String?
    public let note: String?
}

public struct FilmDepartmentTask: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let role: String
    public let phase: String
    public let dependsOn: [String]
    public let synthesis: Bool
    public let status: FilmContractStatus
    public let attempts: Int
}

public struct FilmShotState: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let status: FilmContractStatus?
    public let take: Int?
    public let selectedCandidate: Int?

    public init(
        id: String,
        status: FilmContractStatus? = nil,
        take: Int? = nil,
        selectedCandidate: Int? = nil
    ) {
        self.id = id
        self.status = status
        self.take = take
        self.selectedCandidate = selectedCandidate
    }
}

public struct FilmReviewRequest: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(shotId):\(recordedAt)" }
    public let shotId: String
    public let note: String
    public let status: FilmContractStatus
    public let recordedAt: String
    public let appliedAt: String?
    public let archivedTake: Int?
}

public struct FilmJob: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: ArtifactKind?
    public let status: FilmContractStatus?
    public let shotId: String?
    /// What the job worked on (a shot, cast member, or location id). The
    /// current tools serialize this as `subject`; `shotId` covers older runs.
    public let subject: String?
    /// Which take candidate this job renders, for multi-take productions.
    public let candidateIndex: Int?
    /// Project-relative path of the file the job produces.
    public let output: String?
    public let error: String?

    /// The shot or canon id this job belongs to, whichever field the wire
    /// contract carried.
    public var subjectID: String? { shotId ?? subject }
}

public struct FilmProductionConfiguration: Codable, Sendable, Equatable {
    public let mode: String
    public let takesPerShot: Int
    public let generateScore: Bool
    public let inspectGeneratedMedia: Bool
    public let maxParallelAgents: Int
    public let piTimeoutSeconds: Int
    public let mediaTimeoutSeconds: Int
    public let models: FilmModelConfiguration
}

public struct FilmModelConfiguration: Codable, Sendable, Equatable {
    public let imageMaster: String
    public let imageShot: String
    public let video: String
    public let visionInspector: String
    public let speechAsr: String
    public let speechTts: String
    public let sfx: String
    public let music: String
}

public struct FilmArtifact: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(kind):\(path):\(sha256)" }
    public let bytes: Int64
    public let contentType: String
    public let createdAt: String
    public let kind: ArtifactKind
    public let path: String
    public let sha256: String
    public let source: String
}

public struct FilmProof: Codable, Sendable, Equatable {
    public let creation: Bool
    public let clips: Bool
    public let assembly: Bool
    public let dialogue: Bool
    public let sound: Bool
    public let captions: Bool
    public let inspection: Bool
    public let review: Bool
    public let humanReview: Bool
    public let delivery: Bool

    public var completedCount: Int {
        [creation, clips, assembly, dialogue, sound, captions, inspection, review, humanReview, delivery]
            .filter { $0 }.count
    }
}

public struct FilmIssue: Codable, Sendable, Equatable, Identifiable {
    public var id: String { code }
    public let code: String
    public let message: String
    public let blocking: Bool
    public let recordedAt: String?
}
