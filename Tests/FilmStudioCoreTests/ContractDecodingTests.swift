import Foundation
import Testing
@testable import FilmStudioCore

struct ContractDecodingTests {
    @Test func rejectsProductionPlanFromAnotherProject() throws {
        let fixture = try WorkspaceFixture()
        let planURL = fixture.root.appending(path: "production-plan.json")
        guard var plan = try JSONSerialization.jsonObject(with: Data(contentsOf: planURL)) as? [String: Any] else {
            Issue.record("fixture plan JSON did not match the expected shape")
            return
        }
        plan["projectId"] = "someone-elses-film"
        try JSONSerialization.data(withJSONObject: plan, options: [.sortedKeys]).write(to: planURL)

        #expect(throws: FilmProjectError.self) {
            _ = try FilmProjectLoader.load(runManifest: fixture.runManifest)
        }
    }

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

    @Test func decodesFlatBriefShape() throws {
        let flatBrief: [String: Any] = [
            "audience": "flat readers",
            "genre": "essay",
            "tone": "calm",
            "rating": "PG",
            "language": "en",
            "platform": "web",
            "usage": "demo",
            "targetDurationSeconds": 30,
            "mustHaves": ["a beat"],
            "exclusions": [String](),
            "references": [String](),
            "openQuestions": ["why now?"],
        ]
        let fixture = try WorkspaceFixture(brief: flatBrief)
        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)

        #expect(snapshot.project.brief.audience == "flat readers")
        #expect(snapshot.project.brief.genre == "essay")
        #expect(snapshot.project.brief.tone == "calm")
        #expect(snapshot.project.brief.targetDurationSeconds == 30)
        #expect(snapshot.project.brief.mustHaves == ["a beat"])
        #expect(snapshot.project.brief.openQuestions == ["why now?"])
    }

    @Test func rejectsUnknownProjectContract() throws {
        let fixture = try WorkspaceFixture(contractVersion: "mere.run/film-project.v99")
        #expect(throws: FilmProjectError.unsupportedContract("mere.run/film-project.v99")) {
            _ = try FilmProjectLoader.load(runManifest: fixture.runManifest)
        }
    }

    @Test func reportsMissingManifestAndProject() throws {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-missing-\(UUID().uuidString)")
        do {
            _ = try FilmProjectLoader.load(runManifest: missing)
            Issue.record("expected missingRunManifest")
        } catch let error as FilmProjectError {
            // Only the case matters; the loader reports normalized paths.
            guard case .missingRunManifest = error else {
                Issue.record("expected missingRunManifest, got \(error)")
                return
            }
        }

        let manifestOnly = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-manifest-only-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: manifestOnly, withIntermediateDirectories: true)
        try Data("run".utf8).write(to: manifestOnly.appending(path: "run.json"))
        do {
            _ = try FilmProjectLoader.load(runManifest: manifestOnly)
            Issue.record("expected missingProject")
        } catch let error as FilmProjectError {
            guard case .missingProject = error else {
                Issue.record("expected missingProject, got \(error)")
                return
            }
        }
    }

    // MARK: Typed vocabulary

    @Test func artifactKindsDecodeLossilyAndRoundTrip() throws {
        let fixture = try WorkspaceFixture()
        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)

        // Known kinds decode to their symbolic cases.
        let keyframe = try #require(snapshot.project.artifacts.first { $0.kind == .shotKeyframe })
        #expect(keyframe.kind.rawValue == "shot-keyframe")

        // Unknown kinds from a future contract version must survive decoding
        // instead of failing the whole ledger load.
        var payload = try JSONSerialization.data(withJSONObject: [
            "bytes": 1, "contentType": "application/octet-stream", "createdAt": "t",
            "kind": "hologram-board", "path": "p", "sha256": "sha256:x", "source": "test",
        ])
        let unknown = try JSONDecoder().decode(FilmArtifact.self, from: payload)
        #expect(unknown.kind == ArtifactKind(rawValue: "hologram-board"))

        // Round trip keeps the raw string byte-for-byte.
        let reencoded = try JSONEncoder().encode(unknown.kind)
        let decodedAgain = try JSONDecoder().decode(ArtifactKind.self, from: reencoded)
        #expect(decodedAgain == unknown.kind)
        payload = Data()
        #expect(ArtifactKind.exportable.contains(.deliveryMaster))
    }

    @Test func contractStatusHelpersClassifyKnownStates() {
        #expect(FilmContractStatus.approved.isSettled)
        #expect(FilmContractStatus.succeeded.isSettled)
        #expect(FilmContractStatus.running.isInFlight)
        #expect(FilmContractStatus.ready.isInFlight)
        #expect(FilmContractStatus.failed.isFailed)
        #expect(FilmContractStatus.revisionRequired.isFailed)
        #expect(!FilmContractStatus.pending.isSettled)
        #expect(FilmContractStatus(rawValue: "quantum-leap").rawValue == "quantum-leap")
    }
}
