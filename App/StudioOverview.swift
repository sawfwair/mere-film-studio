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
                            Button {
                                studio.inspectorVisible = true
                            } label: {
                                Label(openQuestionsLabel, systemImage: "bubble.left.and.exclamationmark.bubble.right")
                                    .font(.callout)
                                    .foregroundStyle(Studio.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Read the questions in the inspector")
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

                if hasOutstandingJobs {
                    ProductionActivityStrip(jobs: snapshot.project.jobs)
                }

                HStack(alignment: .top, spacing: 16) {
                    DepartmentBoard(tasks: snapshot.project.departments)
                        .frame(maxWidth: .infinity)
                    NextMoveCard(snapshot: snapshot)
                        .frame(width: 310)
                }

                if !snapshot.project.issues.isEmpty || !failedJobs.isEmpty {
                    IssueStrip(issues: snapshot.project.issues, failedJobs: failedJobs)
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
        snapshot.project.departments.filter { $0.status.isSettled }.count
    }

    private var artifactBytes: Int64 {
        snapshot.project.artifacts.reduce(0) { $0 + $1.bytes }
    }

    private var failedJobs: [FilmJob] {
        snapshot.project.jobs.filter { $0.status?.isFailed == true }
    }

    private var hasOutstandingJobs: Bool {
        snapshot.project.jobs.contains { $0.status?.isInFlight == true || $0.status == .planned }
    }

    private var durationText: String {
        guard let duration = snapshot.productionPlan?.plannedDurationSeconds else { return "awaiting plan" }
        return "\(Studio.runtime(Int(duration.rounded()))) planned"
    }
}

private struct NextMoveCard: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    private var pendingGate: FilmGate? {
        FilmGate.allCases.first { snapshot.project.approvals[$0.rawValue]?.status == .pending }
    }

    /// A gate awaiting the human outranks a failure: the tools only ask for
    /// approval on work that actually finished.
    private var blockingIssue: FilmIssue? {
        pendingGate == nil ? snapshot.project.issues.first(where: \.blocking) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Next move")
                .panelTitle()
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
            Text(headline)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let gate = pendingGate {
                Button("Approve \(gate.displayName.lowercased())") {
                    studio.requestApproval(gate: gate)
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .disabled(studio.isBusy)
            } else {
                Button(blockingIssue == nil ? "Advance" : "Resume") { studio.advance() }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .disabled(studio.isBusy)
            }
        }
        .frame(minHeight: 220)
        .studioPanel()
        .animation(.spring(duration: 0.4), value: headline)
    }

    private var symbol: String {
        if pendingGate != nil { return "hand.raised.circle.fill" }
        if blockingIssue != nil { return "exclamationmark.triangle.fill" }
        return "play.circle.fill"
    }

    private var tint: Color {
        if pendingGate != nil { return Studio.accent }
        if blockingIssue != nil { return Studio.fail }
        return Studio.pass
    }

    private var headline: String {
        if let gate = pendingGate { return "Review the \(gate.displayName.lowercased())" }
        if blockingIssue != nil { return "Production hit a problem" }
        return "Ready to continue"
    }

    private var detail: String {
        if let gate = pendingGate, let summary = snapshot.project.approvals[gate.rawValue]?.summary {
            return summary
        }
        if let issue = blockingIssue { return issue.message }
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
                    .help(help(for: task))
                }
            }
        }
        .studioPanel()
    }
}

extension DepartmentBoard {
    /// The paper trail behind a department tile, on hover.
    fileprivate func help(for task: FilmDepartmentTask) -> String {
        var lines = ["\(StudioText.humanize(task.role)) — \(StudioText.status(task.status))"]
        if task.attempts > 1 { lines.append("\(task.attempts) attempts") }
        if !task.dependsOn.isEmpty {
            lines.append("Builds on " + task.dependsOn.map(StudioText.humanize).joined(separator: ", "))
        }
        if task.synthesis { lines.append("Synthesizes the department drafts") }
        return lines.joined(separator: "\n")
    }
}

private struct DepartmentGlyph: View {
    let role: String
    let status: FilmContractStatus

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.15))
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: status == .running)
        }
        .frame(width: 32, height: 32)
    }

    private var color: Color {
        if status.isSettled { return Studio.pass }
        if status.isInFlight { return Studio.accent }
        if status.isFailed { return Studio.fail }
        return .secondary
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

/// What the render queue is doing right now. The ledger rewrites during a
/// run, so the file watcher keeps this current without polling.
private struct ProductionActivityStrip: View {
    let jobs: [FilmJob]

    private var running: [FilmJob] { jobs.filter { $0.status?.isInFlight == true } }
    private var queuedCount: Int { jobs.filter { $0.status == .planned }.count }
    private var doneCount: Int { jobs.filter { $0.status?.isSettled == true }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Production activity")
                    .panelTitle()
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(doneCount), total: Double(max(jobs.count, 1)))
                .tint(Studio.accent)
            ForEach(running.prefix(4)) { job in
                HStack(spacing: 10) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.caption)
                        .foregroundStyle(Studio.accent)
                        .symbolEffect(.pulse, isActive: true)
                    Text(title(for: job))
                        .font(.callout)
                    Spacer(minLength: 0)
                    if let attempts = attemptsLabel(for: job) {
                        Text(attempts)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if running.count > 4 {
                Text("and \(running.count - 4) more running")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .studioPanel()
    }

    private var summary: String {
        var text = "\(doneCount) of \(jobs.count) jobs done"
        if queuedCount > 0 { text += " · \(queuedCount) queued" }
        return text
    }

    private func title(for job: FilmJob) -> String {
        var text = StudioText.humanize(job.kind?.rawValue ?? job.id)
        if let subject = job.subjectID { text += " — \(StudioText.humanize(subject))" }
        return text
    }

    private func attemptsLabel(for job: FilmJob) -> String? {
        guard let candidate = job.candidateIndex else { return nil }
        return "take \(candidate)"
    }
}

private struct IssueStrip: View {
    let issues: [FilmIssue]
    let failedJobs: [FilmJob]

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
            ForEach(failedJobs) { job in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Studio.fail)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: job))
                        if let error = job.error, !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .studioPanel()
    }

    private func title(for job: FilmJob) -> String {
        var text = "\(StudioText.humanize(job.kind?.rawValue ?? "Job")) failed"
        if let subject = job.subjectID { text += " — \(StudioText.humanize(subject))" }
        return text
    }
}
