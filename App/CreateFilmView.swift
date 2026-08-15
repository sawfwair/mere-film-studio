import AppKit
import SwiftUI

struct CreateFilmView: View {
    @EnvironmentObject private var studio: StudioModel
    @Environment(\.dismiss) private var dismiss
    @State private var idea = ""
    @State private var title = ""
    @State private var duration = 45
    @State private var parentDirectory = URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Movies/Mere Films")

    private static let durations = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New film")
                        .font(.largeTitle.bold())
                    Text("Give Pi the spark. You approve everything after.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "camera.aperture")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Studio.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Idea").fieldLabel()
                StudioTextEditor(
                    placeholder: "A lighthouse keeper receives a signal from a ship that vanished thirty years ago…",
                    text: $idea,
                    font: .title3,
                    minHeight: 124
                )
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Working title").fieldLabel()
                    TextField("Untitled film", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target length").fieldLabel()
                    Picker("Target length", selection: $duration) {
                        ForEach(Self.durations, id: \.self) { seconds in
                            Text(Studio.runtime(seconds)).tag(seconds)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(width: 280)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location").fieldLabel()
                    Text(parentDirectory.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Choose…") { chooseDirectory() }
                    .buttonStyle(StudioSecondaryButtonStyle())
            }

            Divider()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(StudioSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    studio.createFilm(
                        idea: idea.trimmingCharacters(in: .whitespacesAndNewlines),
                        title: effectiveTitle,
                        duration: duration,
                        parentDirectory: projectDirectory
                    )
                } label: {
                    Label("Create film", systemImage: "arrow.right")
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || studio.isBusy)
            }
        }
        .padding(28)
        .frame(width: 680)
        .background(StudioBackdrop())
    }

    private var effectiveTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(idea.split(separator: " ").prefix(6).joined(separator: " ")) : trimmed
    }

    private var projectDirectory: URL {
        let slug = effectiveTitle.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return parentDirectory.appending(path: slug.isEmpty ? "untitled-film" : slug)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { parentDirectory = url }
    }
}
