import FilmStudioCore
import SwiftUI

@main
struct MereFilmStudioApp: App {
    @StateObject private var studio = StudioModel()

    var body: some Scene {
        WindowGroup {
            StudioRootView()
                .environmentObject(studio)
                .frame(minWidth: 1_180, minHeight: 760)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1_520, height: 940)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Film…") { studio.showCreateFilm = true }
                    .keyboardShortcut("n")
                Button("Open Film…") { studio.chooseProject() }
                    .keyboardShortcut("o")
                Menu("Open Recent") {
                    ForEach(studio.recentFilms) { film in
                        Button(film.title) { studio.openProject(URL(fileURLWithPath: film.path)) }
                    }
                    Divider()
                    Button("Clear Menu") { studio.clearRecents() }
                }
                .disabled(studio.recentFilms.isEmpty)
                Divider()
                Button("Export Current Cut…") { studio.exportCurrentCut() }
                    .keyboardShortcut("e")
                    .disabled(studio.snapshot == nil || studio.isBusy)
            }
            CommandMenu("Production") {
                Button("Refresh Project") { studio.refresh() }
                    .keyboardShortcut("r")
                Button("Approve Current Gate") {
                    if let gate = studio.pendingGate { studio.requestApproval(gate: gate) }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(studio.pendingGate == nil || studio.isBusy)
                Button("Advance to Next Gate") { studio.advance() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(studio.snapshot == nil || studio.isBusy)
                Button("Run Studio Review") { studio.review() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(studio.snapshot == nil || studio.isBusy)
                Button("Verify Artifacts") { studio.verifyArtifacts() }
                    .disabled(studio.snapshot == nil || studio.isBusy)
                Button("Cancel Running Command") { studio.cancelRunning() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!studio.isBusy)
                Divider()
                Button("Verify Animatic Handoff") { studio.validateAnimaticHandoff() }
                    .disabled(studio.snapshot == nil || studio.isBusy)
                Button("Push to Animatic") { studio.publishToAnimatic() }
                    .disabled(studio.snapshot == nil || studio.isBusy)
                Divider()
                Button(studio.terminalVisible ? "Hide Pi Room" : "Show Pi Room") {
                    studio.terminalVisible.toggle()
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])
                Button(studio.inspectorVisible ? "Hide Inspector" : "Show Inspector") {
                    studio.inspectorVisible.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
            CommandMenu("Go") {
                ForEach(Array(StudioSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.label) { studio.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                        .disabled(studio.snapshot == nil)
                }
            }
        }

        Settings {
            StudioSettingsView()
                .environmentObject(studio)
        }
        .windowResizability(.contentSize)
    }
}
