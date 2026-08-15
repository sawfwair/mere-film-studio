import FilmStudioCore
import SwiftUI

enum StudioPalette {
    static let amber = Color(red: 0.91, green: 0.66, blue: 0.29)
    static let rose = Color(red: 1.0, green: 0.39, blue: 0.48)
    static let violet = Color(red: 0.57, green: 0.42, blue: 0.96)
    static let mint = Color(red: 0.34, green: 0.86, blue: 0.67)
    static let cyan = Color(red: 0.31, green: 0.78, blue: 0.91)
}

extension View {
    func studioPanel() -> some View {
        padding(18)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(.white.opacity(0.07))
            }
    }

    func studioEyebrow() -> some View {
        font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(.secondary)
    }
}

struct StudioPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(.black)
            .background(
                LinearGradient(colors: [StudioPalette.amber, Color(red: 0.98, green: 0.48, blue: 0.31)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct StudioSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.10)) }
    }
}

struct StatusCapsule: View {
    let status: String
    var body: some View {
        Text(status.replacingOccurrences(of: "-", with: " ").uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.9)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case "completed": StudioPalette.mint
        case "running": StudioPalette.cyan
        case "failed", "revision-required": StudioPalette.rose
        default: StudioPalette.amber
        }
    }
}

struct GateRail: View {
    let approvals: [String: FilmApproval]
    private let gates = ["brief", "treatment", "production", "picture-lock", "delivery"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HUMAN GATES").studioEyebrow()
            ForEach(Array(gates.enumerated()), id: \.offset) { _, gate in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(color(gate).opacity(0.16))
                        Image(systemName: symbol(gate)).font(.caption2.bold()).foregroundStyle(color(gate))
                    }
                    .frame(width: 27, height: 27)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(gate.replacingOccurrences(of: "-", with: " ").capitalized).font(.caption.bold())
                        Text(approvals[gate]?.status.uppercased() ?? "BLOCKED")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func color(_ gate: String) -> Color {
        switch approvals[gate]?.status {
        case "approved": StudioPalette.mint
        case "pending": StudioPalette.amber
        default: .secondary
        }
    }

    private func symbol(_ gate: String) -> String {
        switch approvals[gate]?.status {
        case "approved": "checkmark"
        case "pending": "hand.raised.fill"
        default: "lock.fill"
        }
    }
}

struct ProofDial: View {
    let proof: FilmProof
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.07), lineWidth: 9)
            Circle()
                .trim(from: 0, to: Double(proof.completedCount) / 10)
                .stroke(
                    AngularGradient(colors: [StudioPalette.amber, StudioPalette.rose, StudioPalette.violet, StudioPalette.amber], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(proof.completedCount)").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("OF 10").studioEyebrow()
            }
        }
        .frame(width: 112, height: 112)
    }
}

struct ProofChecklist: View {
    let proof: FilmProof
    private var rows: [(String, Bool, String)] {
        [
            ("Creation canon", proof.creation, "person.crop.rectangle.stack"),
            ("Selected clips", proof.clips, "film.stack"),
            ("Playable assembly", proof.assembly, "play.rectangle"),
            ("Dialogue intelligibility", proof.dialogue, "quote.bubble"),
            ("Sound and loudness", proof.sound, "waveform"),
            ("Caption sidecars", proof.captions, "captions.bubble"),
            ("Visual inspection", proof.inspection, "eye"),
            ("Independent review", proof.review, "person.badge.shield.checkmark"),
            ("Human decision", proof.humanReview, "hand.raised"),
            ("Delivery manifest", proof.delivery, "shippingbox"),
        ]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("PROOF STACK").studioEyebrow()
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Image(systemName: row.1 ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(row.1 ? StudioPalette.mint : Color.secondary.opacity(0.5))
                    Label(row.0, systemImage: row.2)
                        .font(.callout)
                    Spacer()
                    Text(row.1 ? "PROVED" : "PENDING").studioEyebrow()
                }
            }
        }
        .studioPanel()
    }
}

struct MetricCard: View {
    let label: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).studioEyebrow()
            Text(value).font(.system(size: 29, weight: .bold, design: .rounded)).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel()
    }
}

struct ArtifactImage: View {
    let url: URL?
    var body: some View {
        Group {
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [StudioPalette.violet.opacity(0.18), .black.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "photo.on.rectangle.angled").font(.largeTitle).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct EmptyStage: View {
    let title: String
    let detail: String
    let symbol: String
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
    }
}
