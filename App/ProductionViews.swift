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
                        Text("Treatment")
                            .panelTitle()
                        Text(treatment.logline)
                            .font(.system(size: 24, weight: .semibold))
                            .tracking(-0.2)
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
                        Text("Story beats")
                            .panelTitle()
                        ForEach(Array(treatment.beats.enumerated()), id: \.offset) { index, beat in
                            HStack(alignment: .top, spacing: 14) {
                                Text(String(format: "%02d", index + 1))
                                    .timecodeStyle()
                                    .foregroundStyle(Studio.accent)
                                Text(beat)
                                    .font(.body)
                                Spacer()
                            }
                            if index < treatment.beats.count - 1 {
                                Divider().opacity(0.25)
                            }
                        }
                    }
                    .studioPanel()
                } else {
                    EmptyStage(
                        title: "No treatment yet",
                        detail: "Develop the idea with Pi in the room below. Approving the brief starts development.",
                        symbol: "text.book.closed"
                    )
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
            Text("Continuity canon")
                .panelTitle()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(plan.cast) { member in
                    CanonCard(
                        image: artifactURL(kind: "cast-master", suffix: "/\(member.id).png"),
                        category: "Cast",
                        title: member.name,
                        detail: member.visual,
                        footnote: member.wardrobe
                    )
                }
                ForEach(plan.locations) { location in
                    CanonCard(
                        image: artifactURL(kind: "location-master", suffix: "/\(location.id).png"),
                        category: "Location",
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
                            clip: clip(for: shot.id),
                            selected: studio.selectedShotID == shot.id
                        ) {
                            studio.selectedShotID = shot.id
                        }
                        .contextMenu {
                            if let clip = clip(for: shot.id) {
                                Button("Open clip") { NSWorkspace.shared.open(clip) }
                            }
                            if let keyframe = keyframe(for: shot.id) {
                                Button("Show keyframe in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([keyframe])
                                }
                            }
                            Button("Copy motion prompt") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(shot.prompt, forType: .string)
                            }
                            Divider()
                            Button("Reroll…") {
                                studio.selectedShotID = shot.id
                                studio.inspectorVisible = true
                            }
                        }
                    }
                }
                .padding(24)
            }
        } else {
            EmptyStage(
                title: "No shot plan yet",
                detail: "Approve the treatment and preproduction will block the film shot by shot.",
                symbol: "rectangle.stack"
            )
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
    let clip: URL?
    let selected: Bool
    let select: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 0) {
                slate
                details
            }
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(selected ? 0.09 : 0.05), in: RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous)
                .strokeBorder(
                    selected ? Studio.accent : (hovering ? Studio.strokeStrong : Studio.stroke),
                    lineWidth: selected ? 1.5 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
        .studioHoverLift()
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    /// Keyframe (or a looping clip preview on hover) with a slate strip in a
    /// bottom gradient scrim.
    private var slate: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                ArtifactImage(url: keyframe)
                if hovering, let clip {
                    LoopingClipView(url: clip)
                        .transition(.opacity)
                }
            }
            .frame(height: 174)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                .frame(height: 56)

            HStack {
                Text(String(format: "SHOT %02d", index + 1))
                    .timecodeStyle()
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if clip != nil {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(Studio.timecode(shot.durationSeconds))
                    .timecodeStyle()
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 9)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(StudioText.humanize(shot.id))
                .font(.headline)
                .lineLimit(1)
            Text(shot.purpose)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Label("Take \(shot.take)", systemImage: "film.stack")
                Spacer()
                Label(StudioText.humanize(shot.transition), systemImage: "arrow.right")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(13)
    }
}

struct SoundView: View {
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let plan = snapshot.productionPlan {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Score")
                            .panelTitle()
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
                                Text(StudioText.humanize(shot.id))
                                    .font(.headline)
                                Spacer()
                                Text(Studio.timecode(shot.durationSeconds))
                                    .timecodeStyle()
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(Array(shot.dialogue.enumerated()), id: \.offset) { _, line in
                                CueRow(time: line.startSeconds, symbol: "quote.bubble.fill", title: StudioText.humanize(line.speaker), detail: line.text)
                            }
                            ForEach(Array(shot.soundEffects.enumerated()), id: \.offset) { _, cue in
                                CueRow(time: cue.startSeconds, symbol: "waveform", title: "SFX · \(Int(cue.levelDb)) dB", detail: cue.prompt)
                            }
                        }
                        .studioPanel()
                    }
                } else {
                    EmptyStage(
                        title: "No sound plan yet",
                        detail: "Dialogue, effects, captions, and score are planned during preproduction and share one timeline.",
                        symbol: "waveform"
                    )
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

struct DeliveryView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery")
                            .panelTitle()
                        Text(snapshot.project.proof.delivery ? "The master is ready." : "Delivery locks when every check passes.")
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.3)
                        Text("The package binds the accepted cut, evidence, captions, poster, thumbnail, and checksums. Changing any surface breaks the lock.")
                            .font(.body)
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

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Continue in Animatic")
                            .panelTitle()
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 34))
                            .foregroundStyle(Studio.accent)
                        Text("Push every selected take into an editable, versioned timeline.")
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
                            Label("Verified — \(validation.importedAssets ?? 0) assets", systemImage: "checkmark.shield.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Studio.pass)
                        }

                        if let receipt = studio.handoffReceipt {
                            Label("Imported as \(receipt.projectId)", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Studio.pass)
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
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Studio.accent)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CanonCard: View {
    let image: URL?
    let category: String
    let title: String
    let detail: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtifactImage(url: image)
                .frame(height: 170)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(category)
                    .fieldLabel()
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if !footnote.isEmpty {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .padding(13)
        }
        .background(Studio.raised, in: RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous)
                .strokeBorder(Studio.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
        .studioHoverLift(1.008)
    }
}

private struct SoundMetric: View {
    let symbol: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Studio.accent)
            VStack(alignment: .leading) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(11)
        .background(Studio.raised, in: RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous))
    }
}

private struct CueRow: View {
    let time: Double
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(Studio.timecode(time))
                .timecodeStyle()
                .foregroundStyle(Studio.accent)
            Image(systemName: symbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
