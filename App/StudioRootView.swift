import FilmStudioCore
import SwiftUI

struct StudioRootView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        Group {
            if studio.snapshot == nil {
                ZStack {
                    StudioBackdrop()
                    WelcomeView()
                }
            } else {
                StudioWorkspaceView()
                    .background(StudioBackdrop())
            }
        }
        .sheet(isPresented: $studio.showCreateFilm) {
            CreateFilmView()
                .environmentObject(studio)
        }
        .alert("Couldn’t complete that", isPresented: errorBinding) {
            Button("OK", role: .cancel) { studio.errorMessage = nil }
        } message: {
            Text(studio.errorMessage ?? "Unknown error")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { studio.errorMessage != nil },
            set: { if !$0 { studio.errorMessage = nil } }
        )
    }
}

/// Near-flat charcoal ground with a barely-there warm cast in one corner.
struct StudioBackdrop: View {
    var body: some View {
        ZStack {
            Studio.backdrop
            RadialGradient(
                colors: [Studio.accent.opacity(0.045), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 900
            )
        }
        .ignoresSafeArea()
    }
}
