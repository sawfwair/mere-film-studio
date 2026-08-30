import Foundation
import Testing
@testable import FilmStudioCore

struct AnimaticHandoffTests {
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

    @Test func handoffKeepsOnlyNewestAssetWhenLedgerRepeatsPath() throws {
        let fixture = try WorkspaceFixture()
        let manifestURL = fixture.root.appending(path: "film-project.json")
        guard var project = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any],
              let existingArtifacts = project["artifacts"] as? [[String: Any]],
              let keyframe = existingArtifacts.first(where: { $0["kind"] as? String == "shot-keyframe" }) else {
            Issue.record("fixture project JSON did not match the expected shape")
            return
        }
        // A reroll appends a fresh entry for the same path; the stale entry
        // stays in the ledger history.
        var stale = keyframe
        stale["sha256"] = "sha256:" + String(repeating: "0", count: 64)
        project["artifacts"] = [stale] + existingArtifacts
        try JSONSerialization.data(withJSONObject: project, options: [.sortedKeys]).write(to: manifestURL)

        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)
        let handoff = try AnimaticHandoffBuilder.build(from: snapshot)

        #expect(handoff.assets.count == 3)
        #expect(handoff.assets.filter { $0.relativePath == keyframe["path"] as? String }.count == 1)
        #expect(handoff.shots[0].keyframeAssetId != nil)
    }

    @Test func handoffRejectsTamperedArtifacts() throws {
        let fixture = try WorkspaceFixture()
        try Data("tampered".utf8).write(to: fixture.root.appending(path: "frames/relay-answers.png"))
        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)

        #expect(throws: AnimaticHandoffError.self) {
            _ = try AnimaticHandoffBuilder.build(from: snapshot)
        }
    }

    @Test func handoffRejectsMissingProductionPlan() throws {
        let fixture = try WorkspaceFixture()
        try FileManager.default.removeItem(at: fixture.root.appending(path: "production-plan.json"))
        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)

        #expect(throws: AnimaticHandoffError.productionPlanMissing) {
            _ = try AnimaticHandoffBuilder.build(from: snapshot)
        }
    }

    @Test func handoffRejectsArtifactsEscapingProjectRoot() throws {
        let outside = FileManager.default.temporaryDirectory
            .appending(path: "mere-film-studio-escape-\(UUID().uuidString).png")
        try Data("outside".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }

        let fixture = try WorkspaceFixture()
        let manifestURL = fixture.root.appending(path: "film-project.json")
        guard var project = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any],
              let existingArtifacts = project["artifacts"] as? [[String: Any]], !existingArtifacts.isEmpty else {
            Issue.record("fixture project JSON did not match the expected shape")
            return
        }
        var artifacts = existingArtifacts
        artifacts[0]["path"] = outside.path
        project["artifacts"] = artifacts
        try JSONSerialization.data(withJSONObject: project, options: [.sortedKeys]).write(to: manifestURL)

        let snapshot = try FilmProjectLoader.load(runManifest: fixture.runManifest)
        #expect(throws: AnimaticHandoffError.self) {
            _ = try AnimaticHandoffBuilder.build(from: snapshot)
        }
    }
}
