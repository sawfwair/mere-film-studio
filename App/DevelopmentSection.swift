import FilmStudioCore
import SwiftUI

struct DevelopmentView: View {
    let snapshot: FilmWorkspaceSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let treatment = snapshot.treatment {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Treatment")
                            .panelTitle()
                        Text(treatment.logline)
                            .font(.system(size: 24, weight: .semibold))
                            .tracking(-0.2)
                        Text(treatment.synopsis)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                        Divider().opacity(0.4)
                        HStack(alignment: .top, spacing: 22) {
                            LanguageCard(title: "Visual language", text: treatment.visualLanguage, symbol: "eye")
                            LanguageCard(title: "Sound language", text: treatment.soundLanguage, symbol: "ear")
                            LanguageCard(title: "Theme", text: treatment.theme, symbol: "lightbulb")
                        }
                    }
                    .studioPanel()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Story beats")
                            .panelTitle()
                        ForEach(Array(treatment.beats.enumerated()), id: \.offset) { index, beat in
                            HStack(alignment: .top, spacing: 14) {
                                Text(String(format: "%02d", index + 1))
                                    .timecodeStyle()
                                    .foregroundStyle(Studio.accent)
                                Text(beat)
                                    .font(.body)
                                Spacer()
                            }
                            if index < treatment.beats.count - 1 {
                                Divider().opacity(0.25)
                            }
                        }
                    }
                    .studioPanel()
                } else {
                    EmptyStage(
                        title: "No treatment yet",
                        detail: "Develop the idea with Pi in the room below. Approving the brief starts development.",
                        symbol: "text.book.closed"
                    )
                }

                if let plan = snapshot.productionPlan {
                    CanonGrid(snapshot: snapshot, plan: plan)
                }
            }
            .padding(24)
        }
    }
}

private struct CanonGrid: View {
    let snapshot: FilmWorkspaceSnapshot
    let plan: FilmProductionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Continuity canon")
                .panelTitle()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(plan.cast) { member in
                    CanonCard(
                        image: artifactURL(kind: .castMaster, suffix: "/\(member.id).png"),
                        category: "Cast",
                        title: member.name,
                        detail: member.visual,
                        footnote: member.wardrobe
                    )
                }
                ForEach(plan.locations) { location in
                    CanonCard(
                        image: artifactURL(kind: .locationMaster, suffix: "/\(location.id).png"),
                        category: "Location",
                        title: location.name,
                        detail: location.visual,
                        footnote: location.ambience
                    )
                }
            }
        }
    }

    private func artifactURL(kind: ArtifactKind, suffix: String) -> URL? {
        snapshot.project.artifacts.last { $0.kind == kind && $0.path.hasSuffix(suffix) }.map(snapshot.artifactURL)
    }
}

private struct LanguageCard: View {
    let title: String
    let text: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Studio.accent)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CanonCard: View {
    let image: URL?
    let category: String
    let title: String
    let detail: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtifactImage(url: image)
                .frame(height: 170)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(category)
                    .fieldLabel()
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if !footnote.isEmpty {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .padding(13)
        }
        .background(Studio.raised, in: RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous)
                .strokeBorder(Studio.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
        .studioHoverLift(1.008)
    }
}
