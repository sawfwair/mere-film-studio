import Foundation
import Testing
@testable import FilmStudioCore

struct ReviewFindingsTests {
    @Test func decodesMediaInspectionAsTheToolsWriteIt() throws {
        let json = """
        {
          "complete": true,
          "contractVersion": "mere.run/film-media-inspection.v1",
          "createdAt": "2026-08-15T16:34:44.863704+00:00",
          "inspector": {"command": "mere.run vision inspect", "model": "auto-qwen3-vl-2b"},
          "projectId": "tidelight",
          "summary": {"passed": 0, "review": 6, "shots": 6},
          "shots": [{
            "confidence": 0.7,
            "decision": "review",
            "frame": "reviews/inspection-frames/shot-1.png",
            "frameSha256": "sha256:abc",
            "mismatches": [{"code": "severity", "message": "Glow uneven.", "severity": "high"}],
            "observations": ["The glow concentrates on the right side."],
            "shotId": "shot-1"
          }]
        }
        """
        let inspection = try JSONDecoder().decode(FilmMediaInspection.self, from: Data(json.utf8))

        #expect(inspection.summary?.review == 6)
        #expect(inspection.shots[0].shotId == "shot-1")
        #expect(inspection.shots[0].flagged)
        #expect(inspection.shots[0].mismatches[0].severity == "high")
        #expect(inspection.shots[0].observations?.count == 1)
    }

    @Test func decodesTechnicalQCIncludingLoudnessAndVariedDetails() throws {
        let json = """
        {
          "contractVersion": "mere.run/film-technical-qc.v1",
          "passed": true,
          "checks": [
            {"detail": 27754719, "name": "non-empty-file", "passed": true},
            {"detail": {"codec_name": "h264", "coded_width": 1024}, "name": "video-stream", "passed": true},
            {"detail": "16:9", "name": "geometry", "passed": false}
          ],
          "loudnessAnalysis": {
            "available": true,
            "measurement": {"input_i": "-16.64", "input_tp": "-1.27"}
          },
          "master": {"bytes": 27754719, "durationSeconds": 30.4, "path": "cuts/rough-cut.mp4", "sha256": "sha256:def"}
        }
        """
        let qc = try JSONDecoder().decode(FilmTechnicalQC.self, from: Data(json.utf8))

        #expect(qc.passed)
        #expect(qc.checks.count == 3)
        #expect(qc.checks[2].passed == false)
        #expect(qc.measuredLUFS == -16.64)
        #expect(qc.master?.durationSeconds == 30.4)
    }
}
