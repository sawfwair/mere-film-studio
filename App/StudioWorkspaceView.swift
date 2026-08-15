import FilmStudioCore
import GhosttyBridge
import SwiftUI

struct StudioWorkspaceView: View {
    @EnvironmentObject private var studio: StudioModel
    @StateObject private var terminalModel = GhosttyTerminalModel()

    var body: some View {
        if let snapshot = studio.snapshot {
            HSplitView {
                StudioSidebar(snapshot: snapshot)
                    .frame(minWidth: 208, idealWidth: 230, maxWidth: 280)

                VSplitView {
                    ZStack {
                        sectionView(snapshot)
                            .id(studio.section)
                            .transition(.opacity)
                    }
                    .animation(.easeOut(duration: 0.18), value: studio.section)
                    .frame(minWidth: 620, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)

                    if studio.terminalVisible {
                        PiRoom(snapshot: snapshot, model: terminalModel)
                            .frame(minHeight: 190, idealHeight: 285)
                    }
                }
                .layoutPriority(1)

                if studio.inspectorVisible {
                    StudioInspector(snapshot: snapshot)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
                }
            }
            .navigationTitle(snapshot.project.title)
            .navigationSubtitle(subtitle(snapshot))
            .toolbar { WorkspaceToolbar(snapshot: snapshot) }
        }
    }

    private func subtitle(_ snapshot: FilmWorkspaceSnapshot) -> String {
        "\(StudioText.humanize(snapshot.project.phase)) · \(StudioText.humanize(snapshot.project.production.mode)) mode"
    }

    @ViewBuilder
    private func sectionView(_ snapshot: FilmWorkspaceSnapshot) -> some View {
        switch studio.section {
        case .overview: StudioOverview(snapshot: snapshot)
        case .story: DevelopmentView(snapshot: snapshot)
        case .shots: ShotBoardView(snapshot: snapshot)
        case .sound: SoundView(snapshot: snapshot)
        case .review: ReviewView(snapshot: snapshot)
        case .delivery: DeliveryView(snapshot: snapshot)
        }
    }
}

private struct WorkspaceToolbar: ToolbarContent {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            StatusBadge(status: snapshot.project.status)
        }
        ToolbarItemGroup {
            if studio.isBusy {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(studio.activity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 260)
                }
                .transition(.opacity)
            }
            Button {
                studio.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh project")

            Button {
                studio.terminalVisible.toggle()
            } label: {
                Label("Pi room", systemImage: studio.terminalVisible ? "terminal.fill" : "terminal")
            }
            .help(studio.terminalVisible ? "Hide the Pi room" : "Show the Pi room")

            Button {
                studio.inspectorVisible.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .help(studio.inspectorVisible ? "Hide the inspector" : "Show the inspector")

            Menu {
                Button("Recover interrupted work") { studio.recover() }
                Button("Reveal project in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([snapshot.runManifest])
                }
                Divider()
                Button("Close project") { studio.closeProject() }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
}

private struct StudioSidebar: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(StudioSection.allCases) { section in
                            SidebarRow(
                                section: section,
                                selected: studio.section == section,
                                badge: section == .review ? snapshot.project.reviewRequests.count : 0
                            ) {
                                studio.section = section
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Gates")
                            .fieldLabel()
                            .padding(.horizontal, 10)
                        GateRail(approvals: snapshot.project.approvals)
                            .padding(.horizontal, 10)
                    }
                }
                .padding(12)
            }
            Spacer(minLength: 0)
            SidebarHealthRow(snapshot: snapshot)
        }
        .background(Studio.recessed)
    }
}

private struct SidebarRow: View {
    let section: StudioSection
    let selected: Bool
    let badge: Int
    let activate: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: activate) {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .frame(width: 20)
                    .foregroundStyle(selected ? Studio.accent : .secondary)
                Text(section.label)
                    .font(.body.weight(selected ? .semibold : .regular))
                Spacer(minLength: 0)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Studio.accent.opacity(0.22), in: Capsule())
                        .foregroundStyle(Studio.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: Studio.radiusSmall + 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? .primary : .secondary)
        .background(
            Color.white.opacity(selected ? 0.09 : (hovering ? 0.05 : 0)),
            in: RoundedRectangle(cornerRadius: Studio.radiusSmall + 2, style: .continuous)
        )
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
    }
}

private struct SidebarHealthRow: View {
    let snapshot: FilmWorkspaceSnapshot

    private var blocked: Bool {
        snapshot.project.issues.contains(where: \.blocking)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: blocked ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                .foregroundStyle(blocked ? Studio.fail : Studio.pass)
            VStack(alignment: .leading, spacing: 1) {
                Text(blocked ? "Action needed" : "Ledger healthy")
                    .font(.caption.weight(.semibold))
                Text("\(snapshot.project.artifacts.count) verified artifacts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.black.opacity(0.18))
    }
}

private struct PiRoom: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot
    @ObservedObject var model: GhosttyTerminalModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Pi room", systemImage: "terminal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Studio.accent)
                Text(model.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(model.processExited ? Studio.fail : (model.rendererHealthy ? Studio.pass : Studio.fail))
                    .frame(width: 7, height: 7)
                Text(model.processExited ? "SESSION ENDED" : "GHOSTTY · LOCAL")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Button {
                    studio.restartTerminal()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Restart Pi session")
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.black.opacity(0.28))

            if let command = studio.terminalCommand {
                GhosttyTerminalView(
                    command: command,
                    workingDirectory: snapshot.root,
                    environment: studio.terminalEnvironment.merging([
                        "MERE_FILM_RUN_MANIFEST": snapshot.runManifest.path,
                    ]) { _, override in override },
                    model: model
                )
                .id(studio.terminalSessionID)
            } else {
                ContentUnavailableView(
                    "Pi room unavailable",
                    systemImage: "terminal",
                    description: Text(studio.terminalUnavailableReason)
                )
            }
        }
        .background(Color(red: 0.035, green: 0.032, blue: 0.043))
    }
}
