import FilmStudioCore
import SwiftUI

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
