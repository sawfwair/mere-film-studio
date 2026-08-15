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
            ArtifactImage(url: keyframe)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous))

            InspectorField(label: "Purpose", value: shot.purpose)
            InspectorField(label: "Duration", value: Studio.timecode(shot.durationSeconds))
            InspectorField(label: "Location", value: StudioText.humanize(shot.location))
            InspectorField(label: "Characters", value: shot.characters.map(StudioText.humanize).joined(separator: ", "))
            InspectorField(label: "Transition", value: StudioText.humanize(shot.transition))
            InspectorField(label: "Take", value: "\(shot.take)")

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

    private var keyframe: URL? {
        snapshot.project.artifacts.last {
            $0.kind == "shot-keyframe" && $0.path.hasSuffix("/\(shot.id).png")
        }.map(snapshot.artifactURL)
    }
}

private struct InspectorField: View {
    let label: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .fieldLabel()
            Text(value?.isEmpty == false ? value! : "Not set")
                .font(.callout)
                .foregroundStyle(value?.isEmpty == false ? .primary : .tertiary)
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
