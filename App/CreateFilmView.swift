import AppKit
import SwiftUI

struct CreateFilmView: View {
    @EnvironmentObject private var studio: StudioModel
    @Environment(\.dismiss) private var dismiss
    @State private var idea = ""
    @State private var title = ""
    @State private var duration = 45.0
    @State private var parentDirectory = URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Movies/Mere Films")

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Start with the spark")
                        .font(.largeTitle.bold())
                    Text("Pi will develop the rest with you.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(StudioPalette.amber)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("THE IDEA").studioEyebrow()
                TextEditor(text: $idea)
                    .font(.title3)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(height: 132)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        if idea.isEmpty {
                            Text("A lighthouse keeper receives a signal from a ship that vanished thirty years ago…")
                                .foregroundStyle(.tertiary)
                                .padding(18)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WORKING TITLE").studioEyebrow()
                    TextField("Untitled film", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TARGET LENGTH").studioEyebrow()
                    HStack {
                        Slider(value: $duration, in: 10...180, step: 5)
                        Text("\(Int(duration)) sec")
                            .monospacedDigit()
                            .frame(width: 62)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PROJECTS FOLDER").studioEyebrow()
                    Text(parentDirectory.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Choose…") { chooseDirectory() }
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(StudioSecondaryButtonStyle())
                Spacer()
                Button {
                    studio.createFilm(
                        idea: idea.trimmingCharacters(in: .whitespacesAndNewlines),
                        title: effectiveTitle,
                        duration: Int(duration),
                        parentDirectory: projectDirectory
                    )
                } label: {
                    Label("Open the writers’ room", systemImage: "arrow.right")
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .disabled(idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || studio.isBusy)
            }
        }
        .padding(30)
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
