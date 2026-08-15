import FilmStudioCore
import SwiftUI

struct StudioRootView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        ZStack {
            StudioBackdrop()
            if studio.snapshot == nil {
                WelcomeView()
            } else {
                StudioWorkspaceView()
            }
        }
        .sheet(isPresented: $studio.showCreateFilm) {
            CreateFilmView()
                .environmentObject(studio)
        }
        .alert("The studio hit a problem", isPresented: errorBinding) {
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
struct StudioBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.041, blue: 0.059)
            RadialGradient(
                colors: [StudioPalette.violet.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 760
            )
            RadialGradient(
                colors: [StudioPalette.amber.opacity(0.10), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}
