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
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Film…") { studio.showCreateFilm = true }
                    .keyboardShortcut("n")
                Button("Open Film…") { studio.chooseProject() }
                    .keyboardShortcut("o")
            }
            CommandMenu("Production") {
                Button("Refresh Project") { studio.refresh() }
                    .keyboardShortcut("r")
                Button("Advance to Next Gate") { studio.advance() }
                    .disabled(studio.snapshot == nil || studio.isBusy)
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
            }
        }

        Settings {
            StudioSettingsView()
                .environmentObject(studio)
        }
    }
}
