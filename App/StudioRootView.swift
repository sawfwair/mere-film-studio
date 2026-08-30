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
        // Drop a film project folder (or its run.json) anywhere to open it.
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            studio.openProject(url)
            return true
        }
        .sheet(isPresented: $studio.showCreateFilm) {
            CreateFilmView()
                .environmentObject(studio)
        }
        .sheet(item: $studio.pendingApproval) { approval in
            ApprovalSheet(approval: approval)
                .environmentObject(studio)
        }
        .alert("Couldn’t complete that", isPresented: errorBinding) {
            Button("Copy Details") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(studio.fullErrorDetails ?? studio.errorMessage ?? "", forType: .string)
            }
            Button("OK", role: .cancel) { studio.errorMessage = nil }
        } message: {
            Text(studio.errorMessage ?? "Unknown error")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            // While the create sheet is up, failures render inline in the
            // sheet; an alert here would try to present behind it.
            get: { studio.errorMessage != nil && !studio.showCreateFilm },
            set: { if !$0 { studio.errorMessage = nil } }
        )
    }
}

/// Gates are never approved sight-unseen: the sheet restates the evidence
/// summary and captures a real note for the ledger.
private struct ApprovalSheet: View {
    @EnvironmentObject private var studio: StudioModel
    @Environment(\.dismiss) private var dismiss
    let approval: PendingApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Studio.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Approve the \(approval.gate.displayName.lowercased())")
                        .font(.title2.weight(.semibold))
                    Text("This is recorded against the project ledger and cannot be undone.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let summary = approval.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Evidence summary").fieldLabel()
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }
                .studioPanel()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Approval note").fieldLabel()
                StudioTextEditor(
                    placeholder: "Anything worth recording about why you approved this…",
                    text: $studio.approvalNote,
                    font: .callout,
                    minHeight: 84
                )
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(StudioSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Record Approval") {
                    dismiss()
                    studio.confirmPendingApproval()
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(studio.isBusy)
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(StudioBackdrop())
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
