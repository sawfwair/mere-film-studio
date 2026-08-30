import Foundation
@testable import FilmStudioCore

/// Builds a minimal but complete film workspace in a temporary directory so
/// contract tests exercise real files and real hashes.
struct WorkspaceFixture {
    let root: URL
    let runManifest: URL

    init(
        contractVersion: String = "mere.run/film-project.v1",
        brief: [String: Any]? = nil
    ) throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-tests")
            .appending(path: UUID().uuidString)
        runManifest = root.appending(path: "run.json")
        try FileManager.default.createDirectory(at: root.appending(path: "frames"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appending(path: "clips"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appending(path: "cuts"), withIntermediateDirectories: true)

        try Data("run".utf8).write(to: runManifest)
        try Data("frame".utf8).write(to: root.appending(path: "frames/relay-answers.png"))
        try Data("clip".utf8).write(to: root.appending(path: "clips/relay-answers.mp4"))
        try Data("rough-cut".utf8).write(to: root.appending(path: "cuts/rough-cut.mp4"))

        let frameHash = try AnimaticHandoffBuilder.sha256(file: root.appending(path: "frames/relay-answers.png"))
        let clipHash = try AnimaticHandoffBuilder.sha256(file: root.appending(path: "clips/relay-answers.mp4"))
        let cutHash = try AnimaticHandoffBuilder.sha256(file: root.appending(path: "cuts/rough-cut.mp4"))
        let project = Self.makeProject(
            contractVersion: contractVersion,
            frameHash: frameHash,
            clipHash: clipHash,
            cutHash: cutHash,
            brief: brief
        )
        try writeJSON(project, to: root.appending(path: "film-project.json"))
        try writeJSON(Self.productionPlan, to: root.appending(path: "production-plan.json"))
        try writeJSON(Self.treatment, to: root.appending(path: "treatment.json"))
    }

    func writeJSON(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Documents (computed so [String: Any] stays off global state)

    private static func makeProject(
        contractVersion: String,
        frameHash: String,
        clipHash: String,
        cutHash: String,
        brief: [String: Any]?
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "contractVersion": contractVersion,
            "projectId": "relay-in-the-storm",
            "title": "Relay in the Storm",
            "idea": "A lighthouse relay answers a storm.",
            "createdAt": "2026-08-14T20:00:00Z",
            "updatedAt": "2026-08-14T20:25:00Z",
            "status": "review",
            "phase": "review",
            "brief": nestedBrief,
            "approvals": [String: Any](),
            "departments": [[String: Any]](),
            "shots": [["id": "relay-answers", "status": "ready", "take": 1]],
            "reviewRequests": [[String: Any]](),
            "jobs": [[String: Any]](),
            "production": [
                "mode": "draft",
                "takesPerShot": 1,
                "generateScore": false,
                "inspectGeneratedMedia": true,
                "maxParallelAgents": 3,
                "piTimeoutSeconds": 900,
                "mediaTimeoutSeconds": 14400,
                "models": [
                    "imageMaster": "image-master", "imageShot": "image-shot",
                    "video": "video", "visionInspector": "vision",
                    "speechAsr": "asr", "speechTts": "tts", "sfx": "sfx", "music": "music",
                ],
            ],
            "artifacts": [
                artifact(kind: "shot-keyframe", path: "frames/relay-answers.png", hash: frameHash, bytes: 5, contentType: "image/png"),
                artifact(kind: "shot-clip", path: "clips/relay-answers.mp4", hash: clipHash, bytes: 4, contentType: "video/mp4"),
                artifact(kind: "rough-cut", path: "cuts/rough-cut.mp4", hash: cutHash, bytes: 9, contentType: "video/mp4"),
            ],
            "proof": [
                "creation": true, "clips": true, "assembly": true, "dialogue": true,
                "sound": true, "captions": true, "inspection": true, "review": true,
                "humanReview": false, "delivery": false,
            ],
            "issues": [[String: Any]](),
        ]
        if let brief {
            payload["brief"] = brief
        }
        return payload
    }

    private static func artifact(kind: String, path: String, hash: String, bytes: Int, contentType: String) -> [String: Any] {
        [
            "bytes": bytes, "contentType": contentType, "createdAt": "2026-08-14T20:20:00Z",
            "kind": kind, "path": path, "sha256": hash, "source": "test",
        ]
    }

    private static var nestedBrief: [String: Any] {
        [
            "contractVersion": "mere.run/film-brief.v1",
            "title": "Relay in the Storm",
            "idea": "A lighthouse relay answers a storm.",
            "target": [
                "audience": "local AI filmmakers",
                "durationSeconds": 2,
                "language": "en",
                "platform": "web",
                "rating": "G",
                "usage": "noncommercial",
            ],
            "creative": [
                "genre": "micro science-fiction drama",
                "tone": "tense and tactile",
                "mustHaves": [String](),
                "exclusions": [String](),
                "references": [String](),
            ],
            "openQuestions": [String](),
        ]
    }

    private static var productionPlan: [String: Any] {
        [
            "contractVersion": "mere.run/film-production-plan.v1",
            "projectId": "relay-in-the-storm",
            "title": "Relay in the Storm",
            "createdAt": "2026-08-14T20:10:00Z",
            "target": ["aspectRatio": "16:9", "durationSeconds": 2, "fps": 24, "width": 1920, "height": 1080],
            "scorePrompt": "restrained maritime pulse",
            "cast": [["id": "keeper", "name": "Mara", "visual": "weathered keeper", "wardrobe": "mustard sweater", "voice": "quiet", "seed": 4101]],
            "locations": [["id": "relay-desk", "name": "Relay Desk", "visual": "brass relay", "ambience": "storm", "seed": 4102]],
            "shots": [[
                "id": "relay-answers", "purpose": "decisive beat", "framePrompt": "relay close-up",
                "prompt": "relay snaps shut", "durationSeconds": 2, "seed": 4103,
                "characters": ["keeper"], "location": "relay-desk", "dialogue": [[String: Any]](),
                "soundEffects": [[String: Any]](), "transition": "cut", "status": "ready", "take": 1,
            ]],
            "plannedDurationSeconds": 2,
        ]
    }

    private static var treatment: [String: Any] {
        [
            "title": "Relay in the Storm", "logline": "A keeper answers a storm.",
            "synopsis": "One decisive mechanical moment.", "theme": "resolve",
            "beats": ["storm", "click"], "visualLanguage": "storm blue and amber",
            "soundLanguage": "pressure and brass",
        ]
    }
}
