import AppKit
import FilmStudioCore
import GhosttyBridge
import SwiftUI

struct StudioSettingsView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        Form {
            Section("Local tools") {
                ExecutableField(label: "Film tools", text: $studio.filmToolExecutable)
                ExecutableField(label: "mere.run", text: $studio.mereRunExecutable)
                ExecutableField(label: "Pi", text: $studio.piExecutable)
                ExecutableField(label: "Animatic", text: $studio.animaticExecutable)
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
                            .foregroundStyle(Studio.pass)
                    case .unavailable(let reason):
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Studio.fail)
                    }
                }
                Text("Provider credentials remain inside Pi and are never read or stored by Mere Film Studio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 640)
    }
}

private struct ExecutableField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                TextField(label, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                Button("Choose…") { choose() }
            }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            text = url.path
        }
    }
}

private struct PiStatusRow: View {
    let executable: String

    var body: some View {
        LabeledContent("Pi agent") {
            if let resolved = try? PiExecutableResolver.resolve(executable) {
                Label(resolved.path, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Studio.pass)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Label("Not found", systemImage: "xmark.circle.fill")
                    .foregroundStyle(Studio.fail)
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
                    .foregroundStyle(Studio.pass)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Label("Not found", systemImage: "xmark.circle.fill")
                    .foregroundStyle(Studio.fail)
            }
        }
    }
}
