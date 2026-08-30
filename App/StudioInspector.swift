import FilmStudioCore
import SwiftUI

struct StudioInspector: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if studio.section == .shots, let shot = selectedShot {
                    ShotInspector(snapshot: snapshot, shot: shot)
                        // Fresh identity per shot so a half-typed reroll note
                        // never carries over to a different shot.
                        .id(shot.id)
                } else {
                    ProjectInspector(snapshot: snapshot)
                }
            }
            .padding(16)
        }
    }

    private var selectedShot: FilmProductionShot? {
        guard let id = studio.selectedShotID else { return nil }
        return snapshot.productionPlan?.shots.first { $0.id == id }
    }
}

private struct ProjectInspector: View {
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        Group {
            Text("Brief")
                .panelTitle()
            InspectorField(label: "Audience", value: snapshot.project.brief.audience)
            InspectorField(label: "Genre", value: snapshot.project.brief.genre)
            InspectorField(label: "Tone", value: snapshot.project.brief.tone)
            InspectorField(label: "Rating", value: snapshot.project.brief.rating)
            InspectorField(label: "Usage", value: snapshot.project.brief.usage)
            InspectorField(label: "Platform", value: snapshot.project.brief.platform)
            InspectorList(label: "Must haves", items: snapshot.project.brief.mustHaves)
            InspectorList(label: "Exclusions", items: snapshot.project.brief.exclusions)

            if !snapshot.project.brief.openQuestions.isEmpty {
                Divider().opacity(0.4)
                Text("Creative questions for you")
                    .panelTitle()
                ForEach(Array(snapshot.project.brief.openQuestions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(format: "%02d", index + 1))
                            .timecodeStyle()
                            .foregroundStyle(Studio.accent)
                        Text(question)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
                Text("Answer in the Pi room below — the brief updates as you talk.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider().opacity(0.4)
            Text("Models")
                .panelTitle()
            ModelField(label: "Image master", value: snapshot.project.production.models.imageMaster)
            ModelField(label: "Shot image", value: snapshot.project.production.models.imageShot)
            ModelField(label: "Video", value: snapshot.project.production.models.video)
            ModelField(label: "Vision", value: snapshot.project.production.models.visionInspector)
            ModelField(label: "Speech", value: snapshot.project.production.models.speechTts)
            ModelField(label: "Music", value: snapshot.project.production.models.music)
        }
    }
}

private struct ShotInspector: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot
    let shot: FilmProductionShot
    @State private var rerollNote = ""

    var body: some View {
        Group {
            Text(StudioText.humanize(shot.id))
                .panelTitle()
            ArtifactImage(url: keyframe.map(snapshot.artifactURL), revision: keyframe?.sha256)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous))

            InspectorField(label: "Purpose", value: shot.purpose)
            InspectorField(label: "Duration", value: Studio.timecode(shot.durationSeconds))
            InspectorField(label: "Location", value: StudioText.humanize(shot.location))
            InspectorField(label: "Characters", value: shot.characters.map(StudioText.humanize).joined(separator: ", "))
            InspectorField(label: "Transition", value: StudioText.humanize(shot.transition))
            InspectorField(label: "Take", value: "\(shot.take) · seed \(shot.selectedSeed ?? shot.seed)")

            if clipCandidates.count > 1 || !archivedTakes.isEmpty {
                Divider().opacity(0.4)
                Text("Takes")
                    .panelTitle()
                if clipCandidates.count > 1 {
                    ForEach(clipCandidates) { job in
                        CandidateRow(
                            job: job,
                            selected: shot.selectedCandidate != nil && shot.selectedCandidate == job.candidateIndex,
                            url: candidateURL(job)
                        )
                    }
                }
                if !archivedTakes.isEmpty {
                    Text("Earlier takes")
                        .fieldLabel()
                    ForEach(archivedTakes) { take in
                        ArchivedTakeRow(take: take)
                    }
                }
            }

            Divider().opacity(0.4)
            Text("Motion prompt")
                .panelTitle()
            Text(shot.prompt)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Divider().opacity(0.4)
            Text("Targeted reroll")
                .panelTitle()
            StudioTextEditor(placeholder: "What should change?", text: $rerollNote, font: .callout, minHeight: 84)
            Button("Prepare reroll") { studio.reroll(shotID: shot.id, note: rerollNote) }
                .buttonStyle(StudioSecondaryButtonStyle())
                .disabled(rerollNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || studio.isBusy)
        }
    }

    private var keyframe: FilmArtifact? {
        snapshot.project.artifacts.last {
            $0.kind == .shotKeyframe && $0.path.hasSuffix("/\(shot.id).png")
        }
    }

    /// Clip render jobs for this shot, one per candidate on multi-take runs.
    private var clipCandidates: [FilmJob] {
        snapshot.project.jobs
            .filter { $0.subjectID == shot.id && $0.kind == .shotClip }
            .sorted { ($0.candidateIndex ?? 0) < ($1.candidateIndex ?? 0) }
    }

    private func candidateURL(_ job: FilmJob) -> URL? {
        guard let output = job.output else { return nil }
        let url = snapshot.root.appending(path: output)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The tools archive superseded renders under
    /// `recovery/<frame|clip>-<shot>-<timestamp>/` before rerolling.
    private var archivedTakes: [ArchivedTake] {
        let recovery = snapshot.root.appending(path: "recovery")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: recovery,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var takes: [ArchivedTake] = []
        for entry in entries {
            let name = entry.lastPathComponent
            for (prefix, label) in [("frame-\(shot.id)-", "Frame"), ("clip-\(shot.id)-", "Clip")]
            where name.hasPrefix(prefix) {
                guard let file = try? FileManager.default.contentsOfDirectory(
                    at: entry,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ).first else { continue }
                takes.append(ArchivedTake(
                    id: name,
                    label: label,
                    date: Self.displayDate(String(name.dropFirst(prefix.count))),
                    url: file
                ))
            }
        }
        // The directory-name timestamp sorts lexicographically; newest first.
        return takes.sorted { $0.id > $1.id }
    }

    /// "2026-08-15T15-05-38.015292+00-00" → "2026-08-15 15:05".
    private static func displayDate(_ stamp: String) -> String {
        let parts = stamp.split(separator: "T")
        guard parts.count == 2 else { return stamp }
        let time = parts[1].split(separator: "-")
        guard time.count >= 2 else { return String(parts[0]) }
        return "\(parts[0]) \(time[0]):\(time[1])"
    }
}

private struct ArchivedTake: Identifiable {
    let id: String
    let label: String
    let date: String
    let url: URL
}

private struct CandidateRow: View {
    let job: FilmJob
    let selected: Bool
    let url: URL?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: selected ? "checkmark.circle.fill" : "film")
                .foregroundStyle(selected ? AnyShapeStyle(Studio.accent) : AnyShapeStyle(.secondary))
                .frame(width: 16)
            Text("Candidate \(job.candidateIndex.map(String.init) ?? "?")")
                .font(.caption.weight(selected ? .semibold : .regular))
            Text(StudioText.status(job.status))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            if let url {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(Studio.accent)
                }
                .buttonStyle(.plain)
                .help("Play this candidate")
                .accessibilityLabel("Play candidate \(job.candidateIndex.map(String.init) ?? "")")
            }
        }
    }
}

private struct ArchivedTakeRow: View {
    let take: ArchivedTake

    var body: some View {
        Button {
            StudioAppDelegate.preview([take.url])
        } label: {
            HStack(spacing: 8) {
                Image(systemName: take.label == "Clip" ? "film" : "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text("\(take.label) · \(take.date)")
                    .font(.caption)
                    .monospacedDigit()
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Quick Look the archived take")
    }
}

/// Bulleted variant of `InspectorField`; hidden entirely when empty.
private struct InspectorList: View {
    let label: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .fieldLabel()
                ForEach(items, id: \.self) { item in
                    Text("· \(item)")
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct InspectorField: View {
    let label: String
    let value: String?

    private var resolvedValue: String? {
        value.flatMap { $0.isEmpty ? nil : $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .fieldLabel()
            Text(resolvedValue ?? "Not set")
                .font(.callout)
                .foregroundStyle(resolvedValue == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .textSelection(.enabled)
        }
    }
}

private struct ModelField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "auto" : value)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
    }
}
