import AVKit
import FilmStudioCore
import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let cut = snapshot.playableCut {
                    NativePlayer(url: snapshot.artifactURL(cut), revision: cut.sha256)
                        .frame(minHeight: 390)
                        .clipShape(RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous)
                                .strokeBorder(Studio.stroke)
                        }
                } else {
                    EmptyStage(
                        title: "No cut yet",
                        detail: "A playable cut appears here once production and assembly succeed.",
                        symbol: "play.rectangle"
                    )
                }

                HStack(alignment: .top, spacing: 16) {
                    ProofChecklist(snapshot: snapshot)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Review")
                            .panelTitle()
                        Text("Machines provide evidence. You lock the picture.")
                            .font(.title3.weight(.semibold))
                        Text("Technical QC, vision inspection, and independent critics run before your approval is recorded against the cut's hash.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("Run studio review") { studio.review() }
                            .buttonStyle(StudioPrimaryButtonStyle())
                            .disabled(studio.isBusy || snapshot.playableCutURL == nil)
                        if let package = presentArtifact(.reviewPackage) {
                            Button("Open review package") { NSWorkspace.shared.open(snapshot.artifactURL(package)) }
                                .buttonStyle(StudioSecondaryButtonStyle())
                        }
                        HStack(spacing: 8) {
                            if let qc = presentArtifact(.technicalReview) {
                                Button("Technical QC") { NSWorkspace.shared.open(snapshot.artifactURL(qc)) }
                                    .buttonStyle(StudioSecondaryButtonStyle())
                            }
                            if let vision = presentArtifact(.mediaInspection) {
                                Button("Vision findings") { NSWorkspace.shared.open(snapshot.artifactURL(vision)) }
                                    .buttonStyle(StudioSecondaryButtonStyle())
                            }
                        }
                    }
                    .frame(width: 320)
                    .studioPanel()
                }

                FindingsPanels(snapshot: snapshot)

                if !pendingRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Targeted rerolls")
                            .panelTitle()
                        ForEach(pendingRequests) { request in
                            HStack(alignment: .top) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundStyle(Studio.accent)
                                VStack(alignment: .leading) {
                                    Text(StudioText.humanize(request.shotId))
                                        .font(.headline)
                                    Text(request.note)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Prepare") { studio.reroll(shotID: request.shotId, note: request.note) }
                                    .buttonStyle(StudioSecondaryButtonStyle())
                            }
                        }
                    }
                    .studioPanel()
                }
            }
            .padding(24)
        }
    }

    /// Requests the tools have already applied keep their history in the
    /// ledger; only unapplied ones are actionable here.
    private var pendingRequests: [FilmReviewRequest] {
        snapshot.project.reviewRequests.filter { $0.appliedAt == nil }
    }

    private func presentArtifact(_ kind: ArtifactKind) -> FilmArtifact? {
        guard let artifact = snapshot.latestArtifact(kind: kind),
              FileManager.default.fileExists(atPath: snapshot.artifactURL(artifact).path) else { return nil }
        return artifact
    }
}

/// The review evidence, readable in place: per-shot vision verdicts and the
/// technical QC checks, decoded from the documents the ledger points at.
private struct FindingsPanels: View {
    let snapshot: FilmWorkspaceSnapshot
    @State private var inspection: FilmMediaInspection?
    @State private var qc: FilmTechnicalQC?

    /// Reload only when the underlying evidence documents actually change.
    private var revisionKey: String {
        let mi = snapshot.latestArtifact(kind: .mediaInspection)?.sha256 ?? ""
        let tr = snapshot.latestArtifact(kind: .technicalReview)?.sha256 ?? ""
        return "\(mi)|\(tr)"
    }

    var body: some View {
        Group {
            if inspection != nil || qc != nil {
                HStack(alignment: .top, spacing: 16) {
                    if let inspection {
                        VisionInspectionPanel(snapshot: snapshot, inspection: inspection)
                            .frame(maxWidth: .infinity)
                    }
                    if let qc {
                        if inspection == nil {
                            TechnicalQCPanel(qc: qc)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        } else {
                            TechnicalQCPanel(qc: qc)
                                .frame(width: 320)
                        }
                    }
                }
            }
        }
        .task(id: revisionKey) {
            let snapshot = snapshot
            let loaded = await Task.detached(priority: .utility) {
                (
                    ReviewFindingsLoader.mediaInspection(in: snapshot),
                    ReviewFindingsLoader.technicalQC(in: snapshot)
                )
            }.value
            inspection = loaded.0
            qc = loaded.1
        }
    }
}

private struct VisionInspectionPanel: View {
    let snapshot: FilmWorkspaceSnapshot
    let inspection: FilmMediaInspection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Vision inspection")
                    .panelTitle()
                Spacer()
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ForEach(inspection.shots) { shot in
                InspectionShotRow(snapshot: snapshot, shot: shot)
                if shot.id != inspection.shots.last?.id {
                    Divider().opacity(0.25)
                }
            }
        }
        .studioPanel()
    }

    private var summaryText: String {
        let passed = inspection.summary?.passed ?? inspection.shots.filter { !$0.flagged }.count
        let total = inspection.summary?.shots ?? inspection.shots.count
        return "\(passed) of \(total) shots passed"
    }
}

private struct InspectionShotRow: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot
    let shot: FilmMediaInspection.Shot

    @State private var showObservations = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArtifactImage(url: frameURL, revision: shot.frameSha256)
                .frame(width: 88, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: Studio.radiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(StudioText.humanize(shot.shotId))
                        .font(.callout.weight(.semibold))
                    Text(shot.flagged ? "Needs review" : "Passed")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((shot.flagged ? Studio.accent : Studio.pass).opacity(0.18), in: Capsule())
                        .foregroundStyle(shot.flagged ? Studio.accent : Studio.pass)
                    Text("confidence \(Int((shot.confidence * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                ForEach(Array(shot.mismatches.enumerated()), id: \.offset) { _, mismatch in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(severityTint(mismatch.severity))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(mismatch.message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                if let observations = shot.observations, !observations.isEmpty {
                    Button {
                        showObservations.toggle()
                    } label: {
                        Label(
                            "\(observations.count) observation\(observations.count == 1 ? "" : "s")",
                            systemImage: showObservations ? "chevron.down" : "chevron.right"
                        )
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    if showObservations {
                        ForEach(Array(observations.enumerated()), id: \.offset) { _, observation in
                            Text(observation)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Button("View shot") {
                studio.selectedShotID = shot.shotId
                studio.section = .shots
            }
            .buttonStyle(StudioSecondaryButtonStyle())
        }
    }

    private var frameURL: URL? {
        shot.frame.map { snapshot.root.appending(path: $0) }
    }

    private func severityTint(_ severity: String) -> Color {
        switch severity {
        case "high": Studio.fail
        case "medium": Studio.accent
        default: .secondary
        }
    }
}

private struct TechnicalQCPanel: View {
    let qc: FilmTechnicalQC

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Technical QC")
                    .panelTitle()
                Spacer()
                Text(qc.passed ? "Passed" : "Failed")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((qc.passed ? Studio.pass : Studio.fail).opacity(0.18), in: Capsule())
                    .foregroundStyle(qc.passed ? Studio.pass : Studio.fail)
            }
            ForEach(qc.checks) { check in
                HStack(spacing: 8) {
                    Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(check.passed ? Studio.pass : Studio.fail)
                    Text(StudioText.humanize(check.name))
                        .font(.callout)
                    Spacer(minLength: 0)
                }
            }
            if qc.measuredLUFS != nil || qc.master?.durationSeconds != nil {
                Divider().opacity(0.4)
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .studioPanel()
    }

    private var footer: String {
        var parts: [String] = []
        if let lufs = qc.measuredLUFS {
            parts.append(String(format: "Measured %.1f LUFS", lufs))
        }
        if let duration = qc.master?.durationSeconds {
            parts.append("master \(Studio.timecode(duration))")
        }
        return parts.joined(separator: " · ")
    }
}

private struct NativePlayer: NSViewRepresentable {
    let url: URL
    /// Content hash of the cut. Re-renders overwrite the same path, so the
    /// URL alone can't tell the player the film changed underneath it.
    let revision: String

    final class Coordinator {
        var revision: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.player = AVPlayer(url: url)
        context.coordinator.revision = revision
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        let currentURL = (view.player?.currentItem?.asset as? AVURLAsset)?.url
        if currentURL != url || context.coordinator.revision != revision {
            view.player = AVPlayer(url: url)
            context.coordinator.revision = revision
        }
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player?.pause()
        view.player = nil
    }
}
