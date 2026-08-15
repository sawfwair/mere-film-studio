import Foundation
import Testing
@testable import FilmStudioCore

struct FilmStudioCoreTests {
    @Test func loadsCanonicalFilmLedgerAndNestedBrief() throws {
        let fixture = try WorkspaceFixture()
        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)

        #expect(snapshot.project.contractVersion == "mere.run/film-project.v1")
        #expect(snapshot.project.title == "Relay in the Storm")
        #expect(snapshot.project.brief.audience == "local AI filmmakers")
        #expect(snapshot.project.brief.genre == "micro science-fiction drama")
        #expect(snapshot.project.brief.targetDurationSeconds == 2)
        #expect(snapshot.productionPlan?.shots.first?.id == "relay-answers")
        #expect(snapshot.playableCutURL == fixture.root.appending(path: "cuts/rough-cut.mp4"))
    }

    @Test func handoffUsesVerifiedAssetsAndDeterministicTimeline() throws {
        let fixture = try WorkspaceFixture()
        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)
        let handoff = try AnimaticHandoffBuilder.build(
            from: snapshot,
            projectRoot: "../..",
            exportedAt: "2026-08-14T20:30:00Z"
        )

        #expect(handoff.contractVersion == "mere.run/film-animatic-handoff.v1")
        #expect(handoff.shots.count == 1)
        #expect(handoff.shots[0].timelineStartMilliseconds == 0)
        #expect(handoff.shots[0].durationMilliseconds == 2_000)
        #expect(handoff.shots[0].seed == 4_103)
        #expect(handoff.source.projectRoot == "../..")
        #expect(handoff.shots[0].keyframeAssetId != nil)
        #expect(handoff.shots[0].clipAssetId != nil)
        #expect(handoff.assets.count == 3)

        let output = fixture.root.appending(path: "exports/animatic/film-animatic-handoff.json")
        let manifestDigest = try AnimaticHandoffBuilder.write(handoff, to: output)
        let written = try JSONDecoder().decode(AnimaticHandoff.self, from: Data(contentsOf: output))
        #expect(written == handoff)
        #expect(manifestDigest == (try AnimaticHandoffBuilder.sha256(file: output)))
    }

    @Test func handoffRejectsTamperedArtifacts() throws {
        let fixture = try WorkspaceFixture()
        try Data("tampered".utf8).write(to: fixture.root.appending(path: "frames/relay-answers.png"))
        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)

        #expect(throws: AnimaticHandoffError.self) {
            _ = try AnimaticHandoffBuilder.build(from: snapshot)
        }
    }

    @Test func rejectsUnknownProjectContract() throws {
        let fixture = try WorkspaceFixture(contractVersion: "mere.run/film-project.v99")
        #expect(throws: FilmProjectError.unsupportedContract("mere.run/film-project.v99")) {
            _ = try FilmProjectLoader.load(runManifest: fixture.runManifest)
        }
    }

    @Test func resolvesNewestMereRunManagedPi() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-pi-tests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for version in ["v0.9.0", "v0.10.0", "v0.8.12"] {
            let executable = root.appending(path: "\(version)/pi/pi")
            try FileManager.default.createDirectory(
                at: executable.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("#!/bin/sh\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        }

        let candidates = PiExecutableResolver.bundledCandidates(in: root)
        let selected = candidates.first?.resolvingSymlinksInPath().path
        let expected = root.appending(path: "v0.10.0/pi/pi").resolvingSymlinksInPath().path
        #expect(selected == expected)
    }

    @Test func selectsHighestTierInstalledMereRunAgentModel() throws {
        let payload = """
        {
          "models": [
            {
              "id": "small",
              "displayName": "Small",
              "installed": true,
              "recommendedUnifiedMemoryGB": 16,
              "servingEngine": "text-code",
              "startableByMereRun": true
            },
            {
              "id": "best-installed",
              "displayName": "Best Installed",
              "installed": true,
              "recommendedUnifiedMemoryGB": 64,
              "servingEngine": "text-chat",
              "startableByMereRun": true
            },
            {
              "id": "missing",
              "displayName": "Missing",
              "installed": false,
              "recommendedUnifiedMemoryGB": 128,
              "servingEngine": "text-chat",
              "startableByMereRun": true
            }
          ],
          "pi": {"installed": true, "path": "/tmp/pi", "version": "v0.79.0"}
        }
        """
        let status = try JSONDecoder().decode(MereRunAgentStatus.self, from: Data(payload.utf8))
        #expect(status.bestInstalledModel?.id == "best-installed")
    }

    @Test func agentLaunchSeparatesPiRuntimeFromFilmToolCallback() {
        let arguments = FilmToolClient.agentLaunchArguments(
            runManifest: URL(fileURLWithPath: "/tmp/film/run.json"),
            piCommand: "/managed/pi",
            pluginCommand: "/tools/mere-film-tools"
        )

        #expect(arguments == [
            "agent", "--run-manifest", "/tmp/film/run.json",
            "--pi-command", "/managed/pi",
            "--plugin-command", "/tools/mere-film-tools",
            "--print-command",
        ])
    }

    @Test func planDecodesCurrentFilmToolEnvelope() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-plan-tests")
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let expected = root.appending(path: "paper-beacon/run.json")
        let executable = root.appending(path: "mere-film-tools")
        let payload = "{\"status\":{\"runManifest\":\"\(expected.path)\"}}"
        let script = "#!/bin/sh\nprintf '%s\\n' '\(payload)'\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let actual = try await FilmToolClient(executable: executable.path).plan(
            idea: "A paper boat becomes a lighthouse.",
            title: "Paper Beacon",
            durationSeconds: 15,
            outputDirectory: root,
            piCommand: "/managed/pi"
        )

        #expect(actual == expected)
    }
}

private struct WorkspaceFixture {
    let root: URL
    let runManifest: URL

    init(contractVersion: String = "mere.run/film-project.v1") throws {
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
        try writeJSON(project(contractVersion: contractVersion, frameHash: frameHash, clipHash: clipHash, cutHash: cutHash), to: root.appending(path: "film-project.json"))
        try writeJSON(productionPlan, to: root.appending(path: "production-plan.json"))
        try writeJSON(treatment, to: root.appending(path: "treatment.json"))
    }

    private func writeJSON(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func project(contractVersion: String, frameHash: String, clipHash: String, cutHash: String) -> [String: Any] {
        [
            "contractVersion": contractVersion,
            "projectId": "relay-in-the-storm",
            "title": "Relay in the Storm",
            "idea": "A lighthouse relay answers a storm.",
            "createdAt": "2026-08-14T20:00:00Z",
            "updatedAt": "2026-08-14T20:25:00Z",
            "status": "review",
            "phase": "review",
            "brief": [
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
                    "mustHaves": [],
                    "exclusions": [],
                    "references": [],
                ],
                "openQuestions": [],
            ],
            "approvals": [:],
            "departments": [],
            "shots": [["id": "relay-answers", "status": "ready", "take": 1]],
            "reviewRequests": [],
            "jobs": [],
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
            "issues": [],
        ]
    }

    private func artifact(kind: String, path: String, hash: String, bytes: Int, contentType: String) -> [String: Any] {
        [
            "bytes": bytes, "contentType": contentType, "createdAt": "2026-08-14T20:20:00Z",
            "kind": kind, "path": path, "sha256": hash, "source": "test",
        ]
    }

    private var productionPlan: [String: Any] {
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
                "characters": ["keeper"], "location": "relay-desk", "dialogue": [],
                "soundEffects": [], "transition": "cut", "status": "ready", "take": 1,
            ]],
            "plannedDurationSeconds": 2,
        ]
    }

    private var treatment: [String: Any] {
        [
            "title": "Relay in the Storm", "logline": "A keeper answers a storm.",
            "synopsis": "One decisive mechanical moment.", "theme": "resolve",
            "beats": ["storm", "click"], "visualLanguage": "storm blue and amber",
            "soundLanguage": "pressure and brass",
        ]
    }
}
