import Foundation

/// The treatment document produced when the brief gate is approved.
public struct FilmTreatment: Codable, Sendable, Equatable {
    public let title: String
    public let logline: String
    public let synopsis: String
    public let theme: String
    public let beats: [String]
    public let visualLanguage: String
    public let soundLanguage: String
}

/// The shot-by-shot production plan produced during preproduction.
public struct FilmProductionPlan: Codable, Sendable, Equatable {
    public let contractVersion: String
    public let projectId: String
    public let title: String
    public let createdAt: String
    public let target: FilmTarget
    public let scorePrompt: String
    public let cast: [FilmCastMember]
    public let locations: [FilmLocation]
    public let shots: [FilmProductionShot]
    public let plannedDurationSeconds: Double
}

public struct FilmTarget: Codable, Sendable, Equatable {
    public let aspectRatio: String?
    public let audience: String?
    public let durationSeconds: Double?
    public let fps: Int?
    public let height: Int?
    public let language: String?
    public let platform: String?
    public let rating: String?
    public let usage: String?
    public let width: Int?
}

public struct FilmCastMember: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let visual: String
    public let wardrobe: String
    public let voice: String
    public let seed: Int?
}

public struct FilmLocation: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let visual: String
    public let ambience: String
    public let seed: Int?
}

public struct FilmProductionShot: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let purpose: String
    public let framePrompt: String
    public let prompt: String
    public let durationSeconds: Double
    public let seed: Int
    public let characters: [String]
    public let location: String
    public let dialogue: [FilmDialogueLine]
    public let soundEffects: [FilmSoundEffect]
    public let transition: String
    public let status: FilmContractStatus
    public let take: Int
    public let selectedCandidate: Int?
    public let selectedSeed: Int?
}

public struct FilmDialogueLine: Codable, Sendable, Equatable {
    public let speaker: String
    public let text: String
    public let startSeconds: Double
    public let delivery: String
}

public struct FilmSoundEffect: Codable, Sendable, Equatable {
    public let prompt: String
    public let startSeconds: Double
    public let durationSeconds: Double
    public let levelDb: Double
    public let seed: Int
}
