import FilmStudioCore
import GhosttyBridge
import SwiftUI

struct StudioSettingsView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        Form {
            Section("Local tools") {
                TextField("mere-film-tools", text: $studio.filmToolExecutable)
                TextField("branch-built mere.run", text: $studio.mereRunExecutable)
                TextField("Pi", text: $studio.piExecutable)
                TextField("animatic", text: $studio.animaticExecutable)
                ToolStatusRow(label: "Film tools", executable: studio.filmToolExecutable)
                ToolStatusRow(label: "mere.run provider", executable: studio.mereRunExecutable)
                PiStatusRow(executable: studio.piExecutable)
                ToolStatusRow(label: "Animatic", executable: studio.animaticExecutable)
                LabeledContent("Local agent model", value: studio.piRoomModelLabel)
            }
            Section("Terminal") {
                LabeledContent("Renderer") {
                    switch GhosttyBridge.availability {
                    case .available(let version):
                        Label("Ghostty \(version)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(StudioPalette.mint)
                    case .unavailable(let reason):
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(StudioPalette.rose)
                    }
                }
                Text("Provider credentials remain inside Pi and are never read or stored by Mere Film Studio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 720, height: 540)
    }
}

private struct PiStatusRow: View {
    let executable: String

    var body: some View {
        LabeledContent("Pi agent") {
            if let resolved = try? PiExecutableResolver.resolve(executable) {
                Label(resolved.path, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(StudioPalette.mint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Label("Not found", systemImage: "xmark.circle.fill")
                    .foregroundStyle(StudioPalette.rose)
            }
        }
    }
}

private struct ToolStatusRow: View {
    let label: String
    let executable: String

    var body: some View {
        LabeledContent(label) {
            if let resolved = try? FilmToolClient.resolveExecutable(executable) {
                Label(resolved.path, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(StudioPalette.mint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Label("Not found", systemImage: "xmark.circle.fill")
                    .foregroundStyle(StudioPalette.rose)
            }
        }
    }
}
