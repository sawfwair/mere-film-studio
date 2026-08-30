import FilmStudioCore
import SwiftUI

struct ShotBoardView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot
    @FocusState private var focusedShotID: String?
    /// Shots the vision inspector flagged for human review.
    @State private var flaggedShots: Set<String> = []

    var body: some View {
        if let shots = snapshot.productionPlan?.shots, !shots.isEmpty {
            // One pass over the ledger per render, not one scan per shot.
            let keyframes = artifactIndex(kind: .shotKeyframe)
            let clips = artifactIndex(kind: .shotClip)
            VStack(spacing: 0) {
                FilmTimeline(snapshot: snapshot, shots: shots, keyframes: keyframes)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                shotGrid(shots: shots, keyframes: keyframes, clips: clips)
            }
            .onAppear { focusedShotID = studio.selectedShotID }
            .onChange(of: studio.selectedShotID) { _, newValue in
                focusedShotID = newValue
            }
            .task(id: snapshot.latestArtifact(kind: .mediaInspection)?.sha256 ?? "") {
                let snapshot = snapshot
                let inspection = await Task.detached(priority: .utility) {
                    ReviewFindingsLoader.mediaInspection(in: snapshot)
                }.value
                flaggedShots = Set(inspection?.shots.filter(\.flagged).map(\.shotId) ?? [])
            }
        } else {
            EmptyStage(
                title: "No shot plan yet",
                detail: "Approve the treatment and preproduction will block the film shot by shot.",
                symbol: "rectangle.stack"
            )
        }
    }

    private func shotGrid(
        shots: [FilmProductionShot],
        keyframes: [String: FilmArtifact],
        clips: [String: FilmArtifact]
    ) -> some View {
        GeometryReader { geometry in
            // Estimate the grid's live column count so arrow keys can move
            // up/down between rows as well as left/right along a row.
            let columnWidth: CGFloat = 316
            let columns = max(1, Int((geometry.size.width - 48) / columnWidth))
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                        let keyframe = keyframes[shot.id]
                        let clip = clips[shot.id].map(snapshot.artifactURL)
                        ShotCard(
                            index: index,
                            shot: shot,
                            keyframe: keyframe.map(snapshot.artifactURL),
                            keyframeRevision: keyframe?.sha256,
                            clip: clip,
                            flagged: flaggedShots.contains(shot.id),
                            selected: studio.selectedShotID == shot.id
                        ) {
                            studio.selectedShotID = shot.id
                        }
                        .focused($focusedShotID, equals: shot.id)
                        .onMoveCommand { direction in
                            moveTo(direction, from: index, within: shots, columns: columns)
                        }
                        // Space previews the focused shot's clip, the way
                        // Finder previews a file.
                        .onKeyPress(.space) {
                            guard let clip else { return .ignored }
                            NSWorkspace.shared.open(clip)
                            return .handled
                        }
                        .contextMenu {
                            if let clip {
                                Button("Open clip") { NSWorkspace.shared.open(clip) }
                            }
                            if let keyframe {
                                Button("Show keyframe in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([snapshot.artifactURL(keyframe)])
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
        }
    }

    private func moveTo(
        _ direction: MoveCommandDirection,
        from index: Int,
        within shots: [FilmProductionShot],
        columns: Int
    ) {
        let target: Int?
        switch direction {
        case .left: target = index - 1
        case .right: target = index + 1
        case .up: target = index - columns
        case .down: target = index + columns
        default: target = nil
        }
        guard let target, shots.indices.contains(target) else { return }
        studio.selectedShotID = shots[target].id
    }

    /// Latest artifact of `kind` per shot, keyed by the file's basename
    /// (which the tools name after the shot id).
    private func artifactIndex(kind: ArtifactKind) -> [String: FilmArtifact] {
        var index: [String: FilmArtifact] = [:]
        for artifact in snapshot.project.artifacts where artifact.kind == kind {
            index[URL(fileURLWithPath: artifact.path).deletingPathExtension().lastPathComponent] = artifact
        }
        return index
    }
}

private struct ShotCard: View {
    let index: Int
    let shot: FilmProductionShot
    let keyframe: URL?
    let keyframeRevision: String?
    let clip: URL?
    let flagged: Bool
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
        // Drag the shot out to Finder or another app: the clip when one is
        // rendered, otherwise the keyframe.
        .onDrag {
            guard let url = clip ?? keyframe,
                  let provider = NSItemProvider(contentsOf: url) else { return NSItemProvider() }
            return provider
        }
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
                ArtifactImage(url: keyframe, revision: keyframeRevision)
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
                if flagged {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Studio.accent)
                        .help("The vision inspector flagged this shot for review")
                        .accessibilityLabel("Flagged by vision inspection")
                }
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
