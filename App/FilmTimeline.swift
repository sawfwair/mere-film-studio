import FilmStudioCore
import SwiftUI

/// The film at a glance: one block per shot, width proportional to its
/// planned duration, sound cues ticked along the bottom edge. Clicking a
/// block selects the shot everywhere else.
struct FilmTimeline: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot
    let shots: [FilmProductionShot]
    let keyframes: [String: FilmArtifact]
    /// When the board is filtered, the timeline stays a map of the whole
    /// film; blocks outside the filter dim instead of disappearing.
    var matching: Set<String>?

    private var totalSeconds: Double {
        max(shots.reduce(0) { $0 + $1.durationSeconds }, 0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timeline")
                    .panelTitle()
                Spacer()
                Text("\(shots.count) shots · \(Studio.timecode(totalSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                let gaps = CGFloat(max(shots.count - 1, 0)) * 2
                let available = max(geometry.size.width - gaps, 0)
                HStack(alignment: .top, spacing: 2) {
                    ForEach(shots) { shot in
                        TimelineBlock(
                            shot: shot,
                            keyframe: keyframes[shot.id],
                            snapshot: snapshot,
                            selected: studio.selectedShotID == shot.id
                        ) {
                            studio.selectedShotID = shot.id
                        }
                        .frame(width: max(available * shot.durationSeconds / totalSeconds, 26))
                        .opacity(matching == nil || matching?.contains(shot.id) == true ? 1 : 0.3)
                    }
                }
            }
            .frame(height: 54)
        }
    }
}

private struct TimelineBlock: View {
    let shot: FilmProductionShot
    let keyframe: FilmArtifact?
    let snapshot: FilmWorkspaceSnapshot
    let selected: Bool
    let select: () -> Void

    private struct Cue: Identifiable {
        let id: Int
        let fraction: Double
        let tint: Color
    }

    /// Dialogue and effect entry points, placed where they start in the shot.
    private var cues: [Cue] {
        let duration = max(shot.durationSeconds, 0.1)
        let dialogue = shot.dialogue.map(\.startSeconds)
        let effects = shot.soundEffects.map(\.startSeconds)
        return (dialogue.map { ($0, Studio.accent) } + effects.map { ($0, Color.white.opacity(0.55)) })
            .enumerated()
            .map { index, cue in
                Cue(id: index, fraction: min(max(cue.0 / duration, 0), 1), tint: cue.1)
            }
    }

    var body: some View {
        Button(action: select) {
            ZStack {
                ArtifactImage(url: keyframe.map(snapshot.artifactURL), revision: keyframe?.sha256)
                LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    ForEach(cues) { cue in
                        Circle()
                            .fill(cue.tint)
                            .frame(width: 4, height: 4)
                            .position(
                                x: 4 + cue.fraction * max(geometry.size.width - 8, 0),
                                y: geometry.size.height - 5
                            )
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(selected ? Studio.accent : Studio.stroke, lineWidth: selected ? 1.5 : 1)
        }
        .help("\(StudioText.humanize(shot.id)) — \(Studio.timecode(shot.durationSeconds))\n\(shot.purpose)")
        .accessibilityLabel("Select \(StudioText.humanize(shot.id))")
    }
}
