import FilmStudioCore
import SwiftUI

struct StudioOverview: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NOW IN PRODUCTION").studioEyebrow()
                        Text(snapshot.project.idea)
                            .font(.system(size: 31, weight: .semibold, design: .rounded))
                            .tracking(-0.8)
                            .lineLimit(4)
                        if !snapshot.project.brief.openQuestions.isEmpty {
                            Label("\(snapshot.project.brief.openQuestions.count) creative question\(snapshot.project.brief.openQuestions.count == 1 ? "" : "s") for you", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                                .foregroundStyle(StudioPalette.amber)
                        }
                    }
                    Spacer()
                    ProofDial(proof: snapshot.project.proof)
                }
                .studioPanel()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 14)], spacing: 14) {
                    MetricCard(label: "Shots", value: "\(snapshot.productionPlan?.shots.count ?? snapshot.project.shots.count)", detail: durationText)
                    MetricCard(label: "Departments", value: "\(completedDepartments)/\(snapshot.project.departments.count)", detail: "creative tasks")
                    MetricCard(label: "Artifacts", value: "\(snapshot.project.artifacts.count)", detail: ByteCountFormatter.string(fromByteCount: artifactBytes, countStyle: .file))
                    MetricCard(label: "Takes", value: "\(snapshot.project.production.takesPerShot)×", detail: snapshot.project.production.mode.capitalized + " mode")
                }

                HStack(alignment: .top, spacing: 16) {
                    DepartmentBoard(tasks: snapshot.project.departments)
                        .frame(maxWidth: .infinity)
                    NextMoveCard(snapshot: snapshot)
                        .frame(width: 310)
                }

                if !snapshot.project.issues.isEmpty {
                    IssueStrip(issues: snapshot.project.issues)
                }
            }
            .padding(24)
        }
    }

    private var completedDepartments: Int {
        snapshot.project.departments.filter { ["succeeded", "accepted"].contains($0.status) }.count
    }

    private var artifactBytes: Int64 {
        snapshot.project.artifacts.reduce(0) { $0 + $1.bytes }
    }

    private var durationText: String {
        guard let duration = snapshot.productionPlan?.plannedDurationSeconds else { return "awaiting plan" }
        return duration < 60 ? "\(Int(duration.rounded())) seconds" : String(format: "%.1f minutes", duration / 60)
    }
}
private struct NextMoveCard: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var pendingGate: String? {
        ["brief", "treatment", "production", "picture-lock", "delivery"]
            .first { snapshot.project.approvals[$0]?.status == "pending" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NEXT MOVE").studioEyebrow()
            Image(systemName: pendingGate == nil ? "play.circle.fill" : "hand.raised.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(pendingGate == nil ? StudioPalette.mint : StudioPalette.amber)
            Text(pendingGate.map { "Review \($0.replacingOccurrences(of: "-", with: " "))" } ?? "Let the studio advance")
                .font(.title3.bold())
            Text(pendingGate.flatMap { snapshot.project.approvals[$0]?.summary } ?? "Pi will advance only through approved work and stop at the next human decision.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let gate = pendingGate {
                Button("Approve \(gate.replacingOccurrences(of: "-", with: " ").capitalized)") {
                    studio.approve(gate: gate)
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .disabled(studio.isBusy)
            } else {
                Button("Advance production") { studio.advance() }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .disabled(studio.isBusy)
            }
        }
        .frame(minHeight: 230)
        .studioPanel()
    }
}

private struct DepartmentBoard: View {
    let tasks: [FilmDepartmentTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("THE DEPARTMENTS").studioEyebrow()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(tasks) { task in
                    HStack(spacing: 10) {
                        DepartmentGlyph(role: task.role, status: task.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.role.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(task.id.replacingOccurrences(of: "-", with: " "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
                }
            }
        }
        .studioPanel()
    }
}

private struct DepartmentGlyph: View {
    let role: String
    let status: String

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.16))
            Image(systemName: symbol)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
        .frame(width: 34, height: 34)
    }

    private var color: Color {
        switch status {
        case "accepted", "succeeded": StudioPalette.mint
        case "running", "ready": StudioPalette.amber
        case "failed": StudioPalette.rose
        default: .secondary
        }
    }

    private var symbol: String {
        if role.contains("sound") { return "waveform" }
        if role.contains("camera") || role.contains("cinemat") { return "camera" }
        if role.contains("writer") || role.contains("story") { return "text.quote" }
        if role.contains("continuity") { return "link" }
        if role.contains("critic") { return "checkmark.bubble" }
        if role.contains("director") { return "megaphone" }
        return "person.fill"
    }
}

private struct IssueStrip: View {
    let issues: [FilmIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STUDIO NOTES").studioEyebrow()
            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: issue.blocking ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundStyle(issue.blocking ? StudioPalette.rose : StudioPalette.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.code.replacingOccurrences(of: "-", with: " ").capitalized).bold()
                        Text(issue.message).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .studioPanel()
    }
}
