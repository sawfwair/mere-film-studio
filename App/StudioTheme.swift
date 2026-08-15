import SwiftUI

/// The studio design language: near-black neutral surfaces, a single amber
/// accent (the tally light), and green/red reserved strictly for pass/fail
/// state. Every radius, surface, and label style comes from here.
enum Studio {
    // MARK: Accent and status

    static let accent = Color(red: 0.93, green: 0.67, blue: 0.30)
    static let pass = Color(red: 0.38, green: 0.79, blue: 0.55)
    static let fail = Color(red: 0.93, green: 0.42, blue: 0.42)

    // MARK: Surfaces

    static let backdrop = Color(red: 0.055, green: 0.055, blue: 0.063)
    static let raised = Color.white.opacity(0.05)
    static let recessed = Color.black.opacity(0.16)
    static let stroke = Color.white.opacity(0.08)
    static let strokeStrong = Color.white.opacity(0.18)

    // MARK: Radii

    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 14

    // MARK: Timecode

    /// One duration format for the whole app: `m:ss.t`.
    static func timecode(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let minutes = Int(clamped) / 60
        let remainder = clamped - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, remainder)
    }

    /// Whole-second variant for target lengths and totals: `m:ss`.
    static func runtime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Every machine identifier crosses through here before it reaches the
/// screen, so the UI never shows raw enum or slug spellings.
enum StudioText {
    static func gateName(_ gate: String) -> String {
        switch gate {
        case "brief": "Brief"
        case "treatment": "Treatment"
        case "production": "Production"
        case "picture-lock": "Picture lock"
        case "delivery": "Delivery"
        default: humanize(gate)
        }
    }

    static func status(_ raw: String?) -> String {
        switch raw {
        case nil, "": "Idle"
        case "completed", "succeeded", "accepted": "Complete"
        case "running": "Running"
        case "ready": "Ready"
        case "failed": "Failed"
        case "revision-required": "Revision required"
        case "pending": "Awaiting you"
        case "approved": "Approved"
        case .some(let other): humanize(other)
        }
    }

    /// "shot-04-lighthouse-interior" → "Shot 04 lighthouse interior".
    static func humanize(_ identifier: String) -> String {
        let words = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard let first = words.first else { return identifier }
        return first.uppercased() + words.dropFirst()
    }
}

// MARK: - Text styles

extension View {
    /// Sentence-case panel heading. The quiet replacement for the old
    /// tracked-caps eyebrows.
    func panelTitle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    /// Small-caps field label. Reserved for dense metadata rows in the
    /// inspector and forms — not for section headings.
    func fieldLabel() -> some View {
        font(.system(size: 10, weight: .medium))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
    }

    /// Monospaced timecode/readout styling.
    func timecodeStyle() -> some View {
        font(.system(.caption, design: .monospaced, weight: .medium))
            .monospacedDigit()
    }

    func studioPanel() -> some View {
        padding(16)
            .background(Studio.raised, in: RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Studio.radiusLarge, style: .continuous)
                    .strokeBorder(Studio.stroke)
            }
    }
}

// MARK: - Buttons

struct StudioPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StudioPrimaryButtonBody(configuration: configuration)
    }

    private struct StudioPrimaryButtonBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .foregroundStyle(isEnabled ? .black : .black.opacity(0.55))
                .background(
                    Studio.accent.opacity(background),
                    in: RoundedRectangle(cornerRadius: Studio.radiusSmall + 2, style: .continuous)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }

        private var background: Double {
            guard isEnabled else { return 0.35 }
            if configuration.isPressed { return 0.8 }
            return hovering ? 1.0 : 0.9
        }
    }
}

struct StudioSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StudioSecondaryButtonBody(configuration: configuration)
    }

    private struct StudioSecondaryButtonBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .background(
                    Color.white.opacity(background),
                    in: RoundedRectangle(cornerRadius: Studio.radiusSmall + 2, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Studio.radiusSmall + 2, style: .continuous)
                        .strokeBorder(hovering && isEnabled ? Studio.strokeStrong : Studio.stroke)
                }
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .onHover { hovering = $0 }
        }

        private var background: Double {
            guard isEnabled else { return 0.03 }
            if configuration.isPressed { return 0.12 }
            return hovering ? 0.09 : 0.06
        }
    }
}

// MARK: - Hover lift

private struct HoverLift: ViewModifier {
    @State private var hovering = false
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .animation(.easeOut(duration: 0.16), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    /// Subtle scale-on-hover for interactive cards.
    func studioHoverLift(_ scale: CGFloat = 1.012) -> some View {
        modifier(HoverLift(scale: scale))
    }
}
