import FilmStudioCore
import SwiftUI

struct StudioOverview: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Now in production")
                            .panelTitle()
                        Text(snapshot.project.idea)
                            .font(.system(size: 26, weight: .semibold))
                            .tracking(-0.3)
                            .lineLimit(4)
                        if !snapshot.project.brief.openQuestions.isEmpty {
                            Label(openQuestionsLabel, systemImage: "bubble.left.and.exclamationmark.bubble.right")
                                .font(.callout)
                                .foregroundStyle(Studio.accent)
                        }
                    }
                    Spacer()
                    ProofDial(proof: snapshot.project.proof)
                }
                .studioPanel()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 14)], spacing: 14) {
                    MetricCard(
                        label: "Shots",
                        value: "\(snapshot.productionPlan?.shots.count ?? snapshot.project.shots.count)",
                        detail: durationText
                    )
                    MetricCard(
                        label: "Departments",
                        value: "\(completedDepartments)/\(snapshot.project.departments.count)",
                        detail: "creative tasks complete"
                    )
                    MetricCard(
                        label: "Artifacts",
                        value: "\(snapshot.project.artifacts.count)",
                        detail: ByteCountFormatter.string(fromByteCount: artifactBytes, countStyle: .file)
                    )
                    MetricCard(
                        label: "Takes",
                        value: "\(snapshot.project.production.takesPerShot)×",
                        detail: "\(StudioText.humanize(snapshot.project.production.mode)) mode"
                    )
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

    private var openQuestionsLabel: String {
        let count = snapshot.project.brief.openQuestions.count
        return count == 1 ? "1 creative question for you" : "\(count) creative questions for you"
    }

    private var completedDepartments: Int {
        snapshot.project.departments.filter { ["succeeded", "accepted"].contains($0.status) }.count
    }

    private var artifactBytes: Int64 {
        snapshot.project.artifacts.reduce(0) { $0 + $1.bytes }
    }

    private var durationText: String {
        guard let duration = snapshot.productionPlan?.plannedDurationSeconds else { return "awaiting plan" }
        return "\(Studio.runtime(Int(duration.rounded()))) planned"
    }
}

private struct NextMoveCard: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    private var pendingGate: String? {
        GateRail.gates.first { snapshot.project.approvals[$0]?.status == "pending" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Next move")
                .panelTitle()
            Image(systemName: pendingGate == nil ? "play.circle.fill" : "hand.raised.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(pendingGate == nil ? Studio.pass : Studio.accent)
                .contentTransition(.symbolEffect(.replace))
            Text(pendingGate.map { "Review the \(StudioText.gateName($0).lowercased())" } ?? "Ready to continue")
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let gate = pendingGate {
                Button("Approve \(StudioText.gateName(gate).lowercased())") {
                    studio.approve(gate: gate)
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .disabled(studio.isBusy)
            } else {
                Button("Advance") { studio.advance() }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .disabled(studio.isBusy)
            }
        }
        .frame(minHeight: 220)
        .studioPanel()
        .animation(.spring(duration: 0.4), value: pendingGate)
    }

    private var detail: String {
        if let gate = pendingGate, let summary = snapshot.project.approvals[gate]?.summary {
            return summary
        }
        return "Pi advances through approved work and stops at the next gate."
    }
}

private struct DepartmentBoard: View {
    let tasks: [FilmDepartmentTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Departments")
                .panelTitle()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(tasks) { task in
                    HStack(spacing: 10) {
                        DepartmentGlyph(role: task.role, status: task.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(StudioText.humanize(task.role))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(StudioText.status(task.status))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Studio.raised, in: RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous))
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
            Circle().fill(color.opacity(0.15))
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: status == "running")
        }
        .frame(width: 32, height: 32)
    }

    private var color: Color {
        switch status {
        case "accepted", "succeeded": Studio.pass
        case "running", "ready": Studio.accent
        case "failed": Studio.fail
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
            Text("Notes")
                .panelTitle()
            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: issue.blocking ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundStyle(issue.blocking ? Studio.fail : Studio.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.message)
                        Text(StudioText.humanize(issue.code))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .studioPanel()
    }
}
