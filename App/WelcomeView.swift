import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        HStack(spacing: 72) {
            VStack(alignment: .leading, spacing: 28) {
                Label("MERE FILM STUDIO", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.8)
                    .foregroundStyle(StudioPalette.amber)

                VStack(alignment: .leading, spacing: 12) {
                    Text("An idea walks in.")
                    Text("A film walks out.")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [StudioPalette.amber, StudioPalette.rose],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .tracking(-2.5)

                Text("Pi directs a full creative department. Local Mere models create every frame, voice, sound, and score. You stay in control at every gate.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .frame(maxWidth: 590, alignment: .leading)

                HStack(spacing: 12) {
                    Button {
                        studio.showCreateFilm = true
                    } label: {
                        Label("Start a film", systemImage: "sparkles.rectangle.stack")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())

                    Button {
                        studio.chooseProject()
                    } label: {
                        Label("Open a production", systemImage: "folder")
                    }
                    .buttonStyle(StudioSecondaryButtonStyle())
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .strokeBorder(.white.opacity(0.10))
                    }
                    .shadow(color: StudioPalette.violet.opacity(0.22), radius: 70, y: 30)

                VStack(spacing: 30) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 92, weight: .ultraLight))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(StudioPalette.amber, StudioPalette.violet)

                    GateConstellation()

                    Text("Five human gates. One durable film.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(36)
            }
            .frame(width: 450, height: 510)
        }
        .padding(72)
    }
}

private struct GateConstellation: View {
    private let gates = ["Brief", "Treatment", "Production", "Picture", "Delivery"]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(gates.enumerated()), id: \.offset) { index, gate in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(index == 0 ? StudioPalette.amber : .white.opacity(0.08))
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(index == 0 ? .black : .secondary)
                    }
                    .frame(width: 28, height: 28)
                    Text(gate)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    Spacer()
                    Image(systemName: index == 0 ? "arrow.right" : "lock")
                        .foregroundStyle(index == 0 ? StudioPalette.amber : Color.secondary.opacity(0.5))
                }
            }
        }
    }
}
