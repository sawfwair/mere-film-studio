import AVKit
import FilmStudioCore
import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let cut = snapshot.playableCutURL {
                    NativePlayer(url: cut)
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
                    ProofChecklist(proof: snapshot.project.proof)
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
                        if let package = snapshot.project.artifacts.last(where: { $0.kind == .reviewPackage }) {
                            Button("Open review package") { NSWorkspace.shared.open(snapshot.artifactURL(package)) }
                                .buttonStyle(StudioSecondaryButtonStyle())
                        }
                    }
                    .frame(width: 320)
                    .studioPanel()
                }

                if !snapshot.project.reviewRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Targeted rerolls")
                            .panelTitle()
                        ForEach(snapshot.project.reviewRequests) { request in
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
}

private struct NativePlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.player = AVPlayer(url: url)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        let currentURL = (view.player?.currentItem?.asset as? AVURLAsset)?.url
        if currentURL != url {
            view.player = AVPlayer(url: url)
        }
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player?.pause()
        view.player = nil
    }
}
