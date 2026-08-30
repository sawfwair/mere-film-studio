import AppKit
import FilmStudioCore
import SwiftUI

// MARK: - Proof dial

struct ProofDial: View {
    let completed: Int
    let total: Int

    init(proof: FilmProof) {
        completed = proof.completedCount
        total = ProofChecklist.rows(proof).count
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 7)
            Circle()
                .trim(from: 0, to: total == 0 ? 0 : Double(completed) / Double(total))
                .stroke(
                    isComplete ? Studio.pass : Studio.accent,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(completed)")
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("of \(total)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 104, height: 104)
        .animation(.spring(duration: 0.7), value: completed)
    }

    private var isComplete: Bool {
        total > 0 && completed >= total
    }
}

// MARK: - Proof checklist

struct ProofChecklist: View {
    let snapshot: FilmWorkspaceSnapshot

    private var proof: FilmProof { snapshot.project.proof }

    /// Each proof claim, with the artifact kinds that hold its evidence, in
    /// descending order of authority.
    static func rows(_ proof: FilmProof) -> [(title: String, proved: Bool, symbol: String, kinds: [ArtifactKind])] {
        [
            ("Creation canon", proof.creation, "person.crop.rectangle.stack", [.productionReadiness]),
            ("Selected clips", proof.clips, "film.stack", [.takeSelection]),
            ("Playable assembly", proof.assembly, "play.rectangle", [.deliveryMaster, .finalMaster, .roughCut]),
            ("Dialogue intelligibility", proof.dialogue, "quote.bubble", [.dialogueQc, .technicalReview]),
            ("Sound and loudness", proof.sound, "waveform", [.soundQc, .technicalReview]),
            ("Caption sidecars", proof.captions, "captions.bubble", [.captionReceipt, .subtitleSrt, .subtitleVtt]),
            ("Visual inspection", proof.inspection, "eye", [.mediaInspection]),
            ("Independent review", proof.review, "person.badge.shield.checkmark", [.creativeReview, .reviewPackage]),
            ("Human decision", proof.humanReview, "hand.raised", [.humanReview]),
            ("Delivery manifest", proof.delivery, "shippingbox", [.delivery]),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proof")
                .panelTitle()
            ForEach(Self.rows(proof), id: \.title) { row in
                ProofRow(
                    title: row.title,
                    proved: row.proved,
                    symbol: row.symbol,
                    evidence: evidence(for: row.kinds),
                    root: snapshot
                )
            }
        }
        .animation(.spring(duration: 0.4), value: proof)
        .studioPanel()
    }

    private func evidence(for kinds: [ArtifactKind]) -> FilmArtifact? {
        for kind in kinds {
            if let artifact = snapshot.latestArtifact(kind: kind),
               FileManager.default.fileExists(atPath: snapshot.artifactURL(artifact).path) {
                return artifact
            }
        }
        return nil
    }
}

/// One proof claim. When the ledger holds the evidence file, the row opens
/// it — a receipt you can read, not just a checkmark.
private struct ProofRow: View {
    let title: String
    let proved: Bool
    let symbol: String
    let evidence: FilmArtifact?
    let root: FilmWorkspaceSnapshot

    @State private var hovering = false

    var body: some View {
        if let evidence {
            Button {
                NSWorkspace.shared.open(root.artifactURL(evidence))
            } label: {
                content
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help("Open \(evidence.path)")
            .accessibilityLabel("\(title): open evidence")
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: proved ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(proved ? Studio.pass : Color.secondary.opacity(0.4))
                .contentTransition(.symbolEffect(.replace))
            Label(title, systemImage: symbol)
                .font(.callout)
            if evidence != nil {
                Image(systemName: "arrow.up.forward")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(hovering ? AnyShapeStyle(Studio.accent) : AnyShapeStyle(.quaternary))
            }
            Spacer()
            Text(proved ? "Proved" : "Pending")
                .font(.caption2.weight(.medium))
                .foregroundStyle(proved ? AnyShapeStyle(Studio.pass) : AnyShapeStyle(.tertiary))
        }
        .contentShape(Rectangle())
    }
}
