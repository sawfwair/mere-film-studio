import FilmStudioCore
import SwiftUI

struct ShotBoardView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot
    @FocusState private var focusedShotID: String?

    var body: some View {
        if let shots = snapshot.productionPlan?.shots, !shots.isEmpty {
            GeometryReader { geometry in
                // Estimate the grid's live column count so arrow keys can move
                // up/down between rows as well as left/right along a row.
                let columnWidth: CGFloat = 316
                let columns = max(1, Int((geometry.size.width - 48) / columnWidth))
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
                            .focused($focusedShotID, equals: shot.id)
                            .onMoveCommand { direction in
                                moveTo(direction, from: index, within: shots, columns: columns)
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
            }
            .onAppear { focusedShotID = studio.selectedShotID }
            .onChange(of: studio.selectedShotID) { _, newValue in
                focusedShotID = newValue
            }
        } else {
            EmptyStage(
                title: "No shot plan yet",
                detail: "Approve the treatment and preproduction will block the film shot by shot.",
                symbol: "rectangle.stack"
            )
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

    private func keyframe(for shotID: String) -> URL? {
        snapshot.project.artifacts.last {
            $0.kind == .shotKeyframe && $0.path.hasSuffix("/\(shotID).png")
        }.map(snapshot.artifactURL)
    }

    private func clip(for shotID: String) -> URL? {
        snapshot.project.artifacts.last {
            $0.kind == .shotClip && $0.path.hasSuffix("/\(shotID).mp4")
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
