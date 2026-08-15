import AVKit
import FilmStudioCore
import SwiftUI

struct DevelopmentView: View {
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let treatment = snapshot.treatment {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("THE TREATMENT").studioEyebrow()
                        Text(treatment.logline)
                            .font(.system(size: 27, weight: .semibold, design: .rounded))
                        Text(treatment.synopsis)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                        Divider().opacity(0.4)
                        HStack(alignment: .top, spacing: 22) {
                            LanguageCard(title: "Visual language", text: treatment.visualLanguage, symbol: "eye")
                            LanguageCard(title: "Sound language", text: treatment.soundLanguage, symbol: "ear")
                            LanguageCard(title: "Theme", text: treatment.theme, symbol: "lightbulb")
                        }
                    }
                    .studioPanel()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("STORY BEATS").studioEyebrow()
                        ForEach(Array(treatment.beats.enumerated()), id: \.offset) { index, beat in
                            HStack(alignment: .top, spacing: 14) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .foregroundStyle(StudioPalette.amber)
                                Text(beat)
                                    .font(.body)
                                Spacer()
                            }
                            if index < treatment.beats.count - 1 { Divider().opacity(0.25) }
                        }
                    }
                    .studioPanel()
                } else {
                    EmptyStage(title: "Treatment is taking shape", detail: "Work with Pi in the room below, then approve the brief to unleash the development departments.", symbol: "text.book.closed")
                }

                if let plan = snapshot.productionPlan {
                    CanonGrid(snapshot: snapshot, plan: plan)
                }
            }
            .padding(24)
        }
    }
}

private struct CanonGrid: View {
    let snapshot: FilmWorkspaceSnapshot
    let plan: FilmProductionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CONTINUITY CANON").studioEyebrow()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(plan.cast) { member in
                    CanonCard(
                        image: artifactURL(kind: "cast-master", suffix: "/\(member.id).png"),
                        eyebrow: "CAST",
                        title: member.name,
                        detail: member.visual,
                        footnote: member.wardrobe
                    )
                }
                ForEach(plan.locations) { location in
                    CanonCard(
                        image: artifactURL(kind: "location-master", suffix: "/\(location.id).png"),
                        eyebrow: "LOCATION",
                        title: location.name,
                        detail: location.visual,
                        footnote: location.ambience
                    )
                }
            }
        }
    }

    private func artifactURL(kind: String, suffix: String) -> URL? {
        snapshot.project.artifacts.last { $0.kind == kind && $0.path.hasSuffix(suffix) }.map(snapshot.artifactURL)
    }
}

struct ShotBoardView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        if let shots = snapshot.productionPlan?.shots, !shots.isEmpty {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                        ShotCard(
                            index: index,
                            shot: shot,
                            keyframe: keyframe(for: shot.id),
                            clipExists: clip(for: shot.id) != nil,
                            selected: studio.selectedShotID == shot.id
                        )
                        .onTapGesture { studio.selectedShotID = shot.id }
                    }
                }
                .padding(24)
            }
        } else {
            EmptyStage(title: "No shot plan yet", detail: "Approve the treatment and let the preproduction departments block the film.", symbol: "rectangle.stack")
        }
    }

    private func keyframe(for shotID: String) -> URL? {
        snapshot.project.artifacts.last {
            $0.kind == "shot-keyframe" && $0.path.hasSuffix("/\(shotID).png")
        }.map(snapshot.artifactURL)
    }

    private func clip(for shotID: String) -> URL? {
        snapshot.project.artifacts.last {
            $0.kind == "shot-clip" && $0.path.hasSuffix("/\(shotID).mp4")
        }.map(snapshot.artifactURL)
    }
}

private struct ShotCard: View {
    let index: Int
    let shot: FilmProductionShot
    let keyframe: URL?
    let clipExists: Bool
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ArtifactImage(url: keyframe)
                    .frame(height: 174)
                    .clipped()
                HStack {
                    Text(String(format: "SHOT %02d", index + 1))
                    Spacer()
                    Label(clipExists ? "CLIP" : "FRAME", systemImage: clipExists ? "play.fill" : "photo")
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
                .padding(10)
                .background(.black.opacity(0.58))
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(shot.id.replacingOccurrences(of: "-", with: " ").capitalized)
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.1fs", shot.durationSeconds))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(shot.purpose)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack {
                    Label("Take \(shot.take)", systemImage: "film.stack")
                    Spacer()
                    Label(shot.transition.capitalized, systemImage: "arrow.right")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(13)
        }
        .background(.white.opacity(selected ? 0.095 : 0.05), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(selected ? StudioPalette.amber : .white.opacity(0.07), lineWidth: selected ? 1.5 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct SoundView: View {
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let plan = snapshot.productionPlan {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SCORE DIRECTION").studioEyebrow()
                        Label(plan.scorePrompt, systemImage: "music.note.list")
                            .font(.title3)
                        HStack(spacing: 14) {
                            SoundMetric(symbol: "quote.bubble", value: "\(plan.shots.flatMap(\.dialogue).count)", label: "dialogue cues")
                            SoundMetric(symbol: "waveform.badge.plus", value: "\(plan.shots.flatMap(\.soundEffects).count)", label: "sound cues")
                            SoundMetric(symbol: "captions.bubble", value: snapshot.project.proof.captions ? "Ready" : "Pending", label: "captions")
                            SoundMetric(symbol: "dial.high", value: snapshot.project.proof.sound ? "Mixed" : "Pending", label: "-16 LUFS target")
                        }
                    }
                    .studioPanel()

                    ForEach(plan.shots.filter { !$0.dialogue.isEmpty || !$0.soundEffects.isEmpty }) { shot in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(shot.id.replacingOccurrences(of: "-", with: " ").capitalized).font(.headline)
                                Spacer()
                                Text(String(format: "%.1f sec", shot.durationSeconds)).monospacedDigit().foregroundStyle(.secondary)
                            }
                            ForEach(Array(shot.dialogue.enumerated()), id: \.offset) { _, line in
                                CueRow(time: line.startSeconds, symbol: "quote.bubble.fill", title: line.speaker.capitalized, detail: line.text)
                            }
                            ForEach(Array(shot.soundEffects.enumerated()), id: \.offset) { _, cue in
                                CueRow(time: cue.startSeconds, symbol: "waveform", title: "SFX · \(Int(cue.levelDb)) dB", detail: cue.prompt)
                            }
                        }
                        .studioPanel()
                    }
                } else {
                    EmptyStage(title: "The soundtrack starts in preproduction", detail: "Dialogue performances, authored effects, captions, and score will share one accepted timeline.", symbol: "waveform")
                }
            }
            .padding(24)
        }
    }
}

struct ReviewView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let cut = snapshot.playableCutURL {
                    NativePlayer(url: cut)
                        .frame(minHeight: 390)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10)) }
                } else {
                    EmptyStage(title: "The screening room is waiting", detail: "A playable cut appears here after production and assembly succeed.", symbol: "play.rectangle")
                }

                HStack(alignment: .top, spacing: 16) {
                    ProofChecklist(proof: snapshot.project.proof)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("REVIEW ACTION").studioEyebrow()
                        Text("Machines provide evidence. You lock the picture.")
                            .font(.title3.bold())
                        Text("Technical QC, local vision, and independent critics must pass before your hash-bound decision can enter the ledger.")
                            .foregroundStyle(.secondary)
                        Button("Run studio review") { studio.review() }
                            .buttonStyle(StudioPrimaryButtonStyle())
                            .disabled(studio.isBusy || snapshot.playableCutURL == nil)
                        if let package = snapshot.project.artifacts.last(where: { $0.kind == "review-package" }) {
                            Button("Open review package") { NSWorkspace.shared.open(snapshot.artifactURL(package)) }
                                .buttonStyle(StudioSecondaryButtonStyle())
                        }
                    }
                    .frame(width: 320)
                    .studioPanel()
                }

                if !snapshot.project.reviewRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TARGETED REROLLS").studioEyebrow()
                        ForEach(snapshot.project.reviewRequests) { request in
                            HStack(alignment: .top) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundStyle(StudioPalette.rose)
                                VStack(alignment: .leading) {
                                    Text(request.shotId).font(.headline)
                                    Text(request.note).foregroundStyle(.secondary)
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

struct DeliveryView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DELIVERY").studioEyebrow()
                        Text(snapshot.project.proof.delivery ? "The master is ready." : "Every promise must be proved.")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Delivery is bound to the accepted cut, evidence, captions, poster, thumbnail, and checksums. Any changed surface breaks the lock.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    Spacer()
                    ProofDial(proof: snapshot.project.proof)
                }
                .studioPanel()

                HStack(alignment: .top, spacing: 16) {
                    ProofChecklist(proof: snapshot.project.proof)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("CONTINUE IN ANIMATIC").studioEyebrow()
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 38))
                            .foregroundStyle(StudioPalette.violet)
                        Text("Push every selected take into an editable, versioned production timeline.")
                            .font(.headline)
                        Text("The handoff re-verifies every source hash before Animatic receives it.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Verify") {
                                studio.validateAnimaticHandoff()
                            }
                            .buttonStyle(StudioSecondaryButtonStyle())

                            Button {
                                studio.publishToAnimatic()
                            } label: {
                                Label("Push to Animatic", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(StudioPrimaryButtonStyle())
                        }
                        .disabled(studio.isBusy || snapshot.productionPlan == nil)

                        if let validation = studio.handoffValidation, validation.ok {
                            Label("Verified for \(validation.importedAssets ?? 0) assets", systemImage: "checkmark.shield.fill")
                                .font(.caption.bold())
                                .foregroundStyle(StudioPalette.mint)
                        }

                        if let receipt = studio.handoffReceipt {
                            Label("Imported as \(receipt.projectId)", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(StudioPalette.mint)
                        }
                    }
                    .frame(width: 330)
                    .studioPanel()
                }
            }
            .padding(24)
        }
    }
}

private struct LanguageCard: View {
    let title: String
    let text: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption.bold()).foregroundStyle(StudioPalette.amber)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CanonCard: View {
    let image: URL?
    let eyebrow: String
    let title: String
    let detail: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtifactImage(url: image).frame(height: 170).clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow).studioEyebrow()
                Text(title).font(.title3.bold())
                Text(detail).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                if !footnote.isEmpty {
                    Text(footnote).font(.caption).foregroundStyle(.tertiary).lineLimit(2)
                }
            }
            .padding(13)
        }
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

private struct SoundMetric: View {
    let symbol: String
    let value: String
    let label: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(StudioPalette.amber)
            VStack(alignment: .leading) {
                Text(value).font(.headline).monospacedDigit()
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(11)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct CueRow: View {
    let time: Double
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%05.2f", time)).font(.system(.caption, design: .monospaced)).foregroundStyle(StudioPalette.amber)
            Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.bold())
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
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
