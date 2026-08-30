import FilmStudioCore
import SwiftUI

struct SoundView: View {
    let snapshot: FilmWorkspaceSnapshot
    @StateObject private var preview = AudioPreview()
    @State private var captions: [CaptionCue] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let plan = snapshot.productionPlan {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Score")
                            .panelTitle()
                        HStack(spacing: 10) {
                            if let score = audioTakes.first(where: { $0.isScore }) {
                                AudioPreviewButton(preview: preview, url: score.url)
                            }
                            Label(plan.scorePrompt, systemImage: "music.note.list")
                                .font(.title3)
                        }
                        HStack(spacing: 14) {
                            SoundMetric(symbol: "quote.bubble", value: "\(plan.shots.flatMap(\.dialogue).count)", label: "dialogue cues")
                            SoundMetric(symbol: "waveform.badge.plus", value: "\(plan.shots.flatMap(\.soundEffects).count)", label: "sound cues")
                            SoundMetric(symbol: "captions.bubble", value: snapshot.project.proof.captions ? "Ready" : "Pending", label: "captions")
                            SoundMetric(symbol: "dial.high", value: snapshot.project.proof.sound ? "Mixed" : "Pending", label: "-16 LUFS target")
                        }
                    }
                    .studioPanel()

                    if !captions.isEmpty, let source = captionFile {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Captions")
                                    .panelTitle()
                                Spacer()
                                Text("\(captions.count) cue\(captions.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            ForEach(captions) { cue in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(Studio.timecode(cue.startSeconds))
                                        .timecodeStyle()
                                        .foregroundStyle(Studio.accent)
                                    Text(cue.text)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .studioPanel()
                        .contextMenu {
                            Button("Show caption file in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([source])
                            }
                        }
                    }

                    if !audioTakes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Audio takes")
                                .panelTitle()
                            ForEach(audioTakes) { take in
                                HStack(spacing: 12) {
                                    AudioPreviewButton(preview: preview, url: take.url)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(take.label)
                                            .font(.callout.weight(.medium))
                                        Text(take.detail)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contextMenu {
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([take.url])
                                    }
                                }
                            }
                        }
                        .studioPanel()
                    }

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
        .onDisappear { preview.stop() }
        .task(id: captionFile?.path ?? "") {
            guard let captionFile else {
                captions = []
                return
            }
            let cues = await Task.detached(priority: .utility) {
                CaptionParser.load(from: captionFile)
            }.value
            captions = cues
        }
    }

    /// The newest caption sidecar: from the ledger when recorded, otherwise
    /// the conventional captions/ directory.
    private var captionFile: URL? {
        for kind in [ArtifactKind.subtitleVtt, .subtitleSrt] {
            if let artifact = snapshot.latestArtifact(kind: kind) {
                let url = snapshot.artifactURL(artifact)
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
        }
        let directory = snapshot.root.appending(path: "captions")
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return files.first { ["vtt", "srt"].contains($0.pathExtension.lowercased()) }
    }

    /// Every rendered piece of audio the ledger knows about, score first.
    /// The score file can exist before its ledger entry does (the tools write
    /// audio/score.wav during scoring), so that one path is also checked by
    /// convention.
    private var audioTakes: [AudioTake] {
        var takes: [AudioTake] = []
        var seenPaths = Set<String>()
        let kinds: [(ArtifactKind, String, Bool)] = [
            (.score, "Score", true),
            (.dialogue, "Dialogue", false),
            (.soundEffect, "Sound effect", false),
        ]
        for (kind, label, isScore) in kinds {
            for artifact in snapshot.project.artifacts where artifact.kind == kind {
                guard seenPaths.insert(artifact.path).inserted else { continue }
                let url = snapshot.artifactURL(artifact)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                takes.append(AudioTake(
                    id: artifact.path,
                    label: StudioText.humanize(url.deletingPathExtension().lastPathComponent),
                    detail: label,
                    url: url,
                    isScore: isScore
                ))
            }
        }
        if !takes.contains(where: \.isScore) {
            let conventional = snapshot.root.appending(path: "audio/score.wav")
            if FileManager.default.fileExists(atPath: conventional.path) {
                takes.insert(
                    AudioTake(id: "audio/score.wav", label: "Score", detail: "Score", url: conventional, isScore: true),
                    at: 0
                )
            }
        }
        return takes.sorted { $0.isScore && !$1.isScore }
    }
}

private struct AudioTake: Identifiable {
    let id: String
    let label: String
    let detail: String
    let url: URL
    let isScore: Bool
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
