import FilmStudioCore
import GhosttyBridge
import SwiftUI

struct StudioWorkspaceView: View {
    @EnvironmentObject private var studio: StudioModel
    @StateObject private var terminalModel = GhosttyTerminalModel()

    var body: some View {
        guard let snapshot = studio.snapshot else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {
                StudioToolbar(snapshot: snapshot)
                Divider().opacity(0.45)

                HSplitView {
                    StudioSidebar(snapshot: snapshot)
                        .frame(minWidth: 205, idealWidth: 225, maxWidth: 260)

                    VSplitView {
                        sectionView(snapshot)
                            .frame(minWidth: 720, minHeight: 460)

                        if studio.terminalVisible {
                            PiRoom(snapshot: snapshot, model: terminalModel)
                                .frame(minHeight: 190, idealHeight: 285)
                        }
                    }

                    if studio.inspectorVisible {
                        StudioInspector(snapshot: snapshot)
                            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                    }
                }
            }
        )
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

private struct StudioToolbar: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "camera.aperture")
                .font(.title2)
                .foregroundStyle(StudioPalette.amber)

            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.project.title)
                    .font(.headline)
                Text("\(snapshot.project.phase.uppercased())  ·  \(snapshot.project.production.mode.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            StatusCapsule(status: snapshot.project.status)
            Spacer()

            if studio.isBusy {
                ProgressView()
                    .controlSize(.small)
                Text(studio.activity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button { studio.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh project")
            Button { studio.terminalVisible.toggle() } label: {
                Image(systemName: studio.terminalVisible ? "terminal.fill" : "terminal")
            }
            .help("Show or hide the Pi room")
            Button { studio.inspectorVisible.toggle() } label: {
                Image(systemName: "sidebar.right")
            }
            .help("Show or hide the inspector")
            Menu {
                Button("Recover interrupted work") { studio.recover() }
                Button("Reveal project in Finder") { NSWorkspace.shared.activateFileViewerSelecting([snapshot.runManifest]) }
                Divider()
                Button("Close project") { studio.closeProject() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

private struct StudioSidebar: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PRODUCTION").studioEyebrow()
                ForEach(StudioSection.allCases) { section in
                    Button {
                        studio.section = section
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: section.symbol)
                                .frame(width: 20)
                            Text(section.label)
                            Spacer()
                            if section == .review, !snapshot.project.reviewRequests.isEmpty {
                                Text("\(snapshot.project.reviewRequests.count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(StudioPalette.rose.opacity(0.25), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .foregroundStyle(studio.section == section ? .white : .secondary)
                        .background(
                            studio.section == section ? .white.opacity(0.10) : .clear,
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().opacity(0.45)
            GateRail(approvals: snapshot.project.approvals)
            Spacer()

            HStack {
                Image(systemName: snapshot.project.issues.contains(where: \.blocking) ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .foregroundStyle(snapshot.project.issues.contains(where: \.blocking) ? StudioPalette.rose : StudioPalette.mint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.project.issues.contains(where: \.blocking) ? "Action needed" : "Ledger healthy")
                        .font(.caption.bold())
                    Text("\(snapshot.project.artifacts.count) verified artifacts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.black.opacity(0.14))
    }
}

private struct PiRoom: View {
    @EnvironmentObject private var studio: StudioModel
    let snapshot: FilmWorkspaceSnapshot
    @ObservedObject var model: GhosttyTerminalModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("PI ROOM", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(StudioPalette.amber)
                Text(model.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(model.processExited ? StudioPalette.rose : (model.rendererHealthy ? StudioPalette.mint : StudioPalette.rose))
                    .frame(width: 7, height: 7)
                Text(model.processExited ? "SESSION ENDED" : "GHOSTTY · LOCAL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
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
