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
