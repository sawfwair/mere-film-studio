import Foundation

/// Typed vocabulary for values that cross the film-contract wire as strings.
///
/// These are deliberately lossy: an unknown value from a newer contract
/// version decodes successfully and round-trips byte-for-byte instead of
/// failing the whole ledger load (ADR-002: the film directory is
/// authoritative; the app projects it, never gates it). All comparisons in
/// app code must use the static cases below — lint bans raw-literal
/// comparisons (`artifact_kind_literal`, `status_literal_comparison`).

/// The kind of a verified artifact in the film ledger.
public struct ArtifactKind: Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension ArtifactKind: CustomStringConvertible {
    public var description: String { rawValue }
}

extension ArtifactKind {
    public static let castMaster = ArtifactKind(rawValue: "cast-master")
    public static let locationMaster = ArtifactKind(rawValue: "location-master")
    public static let shotKeyframe = ArtifactKind(rawValue: "shot-keyframe")
    public static let shotClip = ArtifactKind(rawValue: "shot-clip")
    public static let dialogue = ArtifactKind(rawValue: "dialogue")
    public static let soundEffect = ArtifactKind(rawValue: "sound-effect")
    public static let score = ArtifactKind(rawValue: "score")
    public static let subtitleSrt = ArtifactKind(rawValue: "subtitle-srt")
    public static let subtitleVtt = ArtifactKind(rawValue: "subtitle-vtt")
    public static let captionReceipt = ArtifactKind(rawValue: "caption-receipt")
    public static let editBlock = ArtifactKind(rawValue: "edit-block")
    public static let editBlockReceipt = ArtifactKind(rawValue: "edit-block-receipt")
    public static let roughCut = ArtifactKind(rawValue: "rough-cut")
    public static let finalMaster = ArtifactKind(rawValue: "final-master")
    public static let deliveryMaster = ArtifactKind(rawValue: "delivery-master")
    public static let poster = ArtifactKind(rawValue: "poster")
    public static let thumbnail = ArtifactKind(rawValue: "thumbnail")
    public static let technicalReview = ArtifactKind(rawValue: "technical-review")
    public static let creativeReview = ArtifactKind(rawValue: "creative-review")
    public static let mediaInspection = ArtifactKind(rawValue: "media-inspection")
    public static let inspectionFrame = ArtifactKind(rawValue: "inspection-frame")
    public static let reviewFrame = ArtifactKind(rawValue: "review-frame")
    public static let dialogueQc = ArtifactKind(rawValue: "dialogue-qc")
    public static let soundQc = ArtifactKind(rawValue: "sound-qc")
    public static let takeSelection = ArtifactKind(rawValue: "take-selection")
    public static let productionReadiness = ArtifactKind(rawValue: "production-readiness")
    public static let reviewPackage = ArtifactKind(rawValue: "review-package")
    public static let humanReview = ArtifactKind(rawValue: "human-review")
    public static let delivery = ArtifactKind(rawValue: "delivery")

    /// Kinds eligible for the Animatic handoff manifest.
    public static let exportable: Set<ArtifactKind> = [
        .castMaster, .locationMaster, .shotKeyframe, .shotClip,
        .dialogue, .soundEffect, .score, .subtitleSrt, .subtitleVtt,
        .captionReceipt, .editBlock, .editBlockReceipt, .roughCut, .finalMaster,
        .deliveryMaster, .poster, .thumbnail, .technicalReview,
        .creativeReview, .mediaInspection, .inspectionFrame, .reviewFrame,
        .dialogueQc, .soundQc, .takeSelection, .productionReadiness,
        .reviewPackage, .humanReview, .delivery,
    ]
}

/// Lifecycle status shared by approvals, department tasks, shots, jobs, and
/// the project itself.
public struct FilmContractStatus: Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension FilmContractStatus: CustomStringConvertible {
    public var description: String { rawValue }
}

extension FilmContractStatus {
    public static let pending = FilmContractStatus(rawValue: "pending")
    public static let approved = FilmContractStatus(rawValue: "approved")
    public static let running = FilmContractStatus(rawValue: "running")
    public static let ready = FilmContractStatus(rawValue: "ready")
    public static let failed = FilmContractStatus(rawValue: "failed")
    public static let completed = FilmContractStatus(rawValue: "completed")
    public static let succeeded = FilmContractStatus(rawValue: "succeeded")
    public static let accepted = FilmContractStatus(rawValue: "accepted")
    public static let revisionRequired = FilmContractStatus(rawValue: "revision-required")

    public var isSettled: Bool {
        self == .completed || self == .succeeded || self == .accepted || self == .approved
    }

    public var isInFlight: Bool {
        self == .running || self == .ready
    }

    public var isFailed: Bool {
        self == .failed || self == .revisionRequired
    }
}
