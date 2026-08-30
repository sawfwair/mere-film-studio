import FilmStudioCore
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var studio: StudioModel
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 64) {
            VStack(alignment: .leading, spacing: 28) {
                if let notice = studio.startupNotice {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Studio.accent)
                        Text(notice)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                        Spacer(minLength: 0)
                        Button {
                            studio.startupNotice = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss notice")
                    }
                    .padding(14)
                    .background(Studio.raised, in: RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous)
                            .strokeBorder(Studio.accent.opacity(0.35))
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Studio.accent)
                    Text("MERE FILM STUDIO")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(.secondary)
                }
                .entrance(appeared, delay: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("An idea walks in.")
                    Text("A film walks out.")
                }
                .font(.system(size: 54, weight: .semibold))
                .tracking(-1.2)
                .entrance(appeared, delay: 0.08)

                Text("Pi runs the departments. Local Mere models make every frame, voice, sound, and note of score — all on this machine. Nothing advances without your approval.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .frame(maxWidth: 560, alignment: .leading)
                    .entrance(appeared, delay: 0.16)

                HStack(spacing: 12) {
                    Button {
                        studio.showCreateFilm = true
                    } label: {
                        Label("Start a film", systemImage: "plus")
                            .frame(minWidth: 124)
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)

                    Button {
                        studio.chooseProject()
                    } label: {
                        Label("Open a film…", systemImage: "folder")
                    }
                    .buttonStyle(StudioSecondaryButtonStyle())
                }
                .entrance(appeared, delay: 0.24)

                if !missingTools.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Studio.accent)
                        Text("The studio can't find \(missingTools.formatted(.list(type: .and))). Point it at the installed tools before starting a film.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        SettingsLink {
                            Text("Open Settings…")
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .entrance(appeared, delay: 0.26)
                }

                if !existingRecents.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent films")
                            .panelTitle()
                        VStack(spacing: 2) {
                            ForEach(existingRecents.prefix(5)) { film in
                                RecentFilmRow(film: film)
                            }
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .entrance(appeared, delay: 0.3)
                }
            }

            GateCard()
                .entrance(appeared, delay: 0.3)
        }
        .padding(64)
        .onAppear { appeared = true }
    }

    /// A film deleted from disk is gone; showing it would be a dead end.
    private var existingRecents: [RecentFilm] {
        studio.recentFilms.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Tools "Start a film" will need but the studio can't resolve today.
    private var missingTools: [String] {
        var missing: [String] = []
        if (try? FilmToolClient.resolveExecutable(studio.filmToolExecutable)) == nil { missing.append("mere-film-tools") }
        if (try? FilmToolClient.resolveExecutable(studio.mereRunExecutable)) == nil { missing.append("mere.run") }
        if (try? PiExecutableResolver.resolve(studio.piExecutable)) == nil { missing.append("Pi") }
        return missing
    }
}

private struct RecentFilmRow: View {
    @EnvironmentObject private var studio: StudioModel
    let film: RecentFilm

    @State private var hovering = false

    var body: some View {
        Button {
            studio.openProject(URL(fileURLWithPath: film.path))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "film")
                    .foregroundStyle(Studio.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(film.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(folder)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 12)
                if hovering {
                    Button {
                        studio.removeRecent(film)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from recent films")
                    .accessibilityLabel("Remove \(film.title) from recent films")
                } else {
                    Text(film.openedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: Studio.radiusSmall + 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            Color.white.opacity(hovering ? 0.05 : 0),
            in: RoundedRectangle(cornerRadius: Studio.radiusSmall + 2, style: .continuous)
        )
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
    }

    private var folder: String {
        URL(fileURLWithPath: film.path).deletingLastPathComponent().path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

/// Illustration of the pipeline — deliberately dimmed and static so it reads
/// as a diagram, not live status.
private struct GateCard: View {
    private let gates = FilmGate.allCases.map(\.displayName)

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 76, weight: .ultraLight))
                .foregroundStyle(Studio.accent.opacity(0.9))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(gates.enumerated()), id: \.offset) { index, gate in
                    GateIllustrationRow(number: index + 1, name: gate, isFirst: index == 0, isLast: index == gates.count - 1)
                }
            }
            .frame(maxWidth: 220)

            Text("Five human gates. One durable film.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 380)
        .background(Studio.raised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Studio.stroke)
        }
    }
}

private struct GateIllustrationRow: View {
    let number: Int
    let name: String
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(isFirst ? AnyShapeStyle(Studio.accent) : AnyShapeStyle(.tertiary))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().strokeBorder(isFirst ? Studio.accent.opacity(0.6) : Studio.stroke)
                    )
                if !isLast {
                    Rectangle()
                        .fill(Studio.stroke)
                        .frame(width: 1, height: 16)
                }
            }
            Text(name)
                .font(.callout.weight(.medium))
                .foregroundStyle(isFirst ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .padding(.bottom, isLast ? 0 : 16)
            Spacer(minLength: 0)
        }
    }
}

private extension View {
    func entrance(_ appeared: Bool, delay: Double) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }
}
