import FilmStudioCore
import SwiftUI

struct DeliveryView: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery")
                            .panelTitle()
                        Text(snapshot.project.proof.delivery ? "The master is ready." : "Delivery locks when every check passes.")
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.3)
                        Text("The package binds the accepted cut, evidence, captions, poster, thumbnail, and checksums. Changing any surface breaks the lock.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    Spacer()
                    ProofDial(proof: snapshot.project.proof)
                }
                .studioPanel()

                HStack(alignment: .top, spacing: 16) {
                    ProofChecklist(proof: snapshot.project.proof)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Continue in Animatic")
                            .panelTitle()
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 34))
                            .foregroundStyle(Studio.accent)
                        Text("Push every selected take into an editable, versioned timeline.")
                            .font(.headline)
                        Text("The handoff re-verifies every source hash before Animatic receives it.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Verify") {
                                studio.validateAnimaticHandoff()
                            }
                            .buttonStyle(StudioSecondaryButtonStyle())

                            Button {
                                studio.publishToAnimatic()
                            } label: {
                                Label("Push to Animatic", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(StudioPrimaryButtonStyle())
                        }
                        .disabled(studio.isBusy || snapshot.productionPlan == nil)

                        if let validation = studio.handoffValidation, validation.ok {
                            Label("Verified — \(validation.importedAssets ?? 0) assets", systemImage: "checkmark.shield.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Studio.pass)
                        }

                        if let receipt = studio.handoffReceipt {
                            Label("Imported as \(receipt.projectId)", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Studio.pass)
                        }
                    }
                    .frame(width: 330)
                    .studioPanel()
                }
            }
            .padding(24)
        }
    }
}
