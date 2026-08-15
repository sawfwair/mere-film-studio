import AVFoundation
import AppKit
import FilmStudioCore
import SwiftUI

// MARK: - Status badge

struct StatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(StudioText.status(status))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Studio.raised, in: Capsule())
        .overlay { Capsule().strokeBorder(Studio.stroke) }
    }

    private var color: Color {
        switch status {
        case "completed", "succeeded", "accepted", "approved": Studio.pass
        case "running", "ready": Studio.accent
        case "failed", "revision-required": Studio.fail
        default: .secondary
        }
    }
}

// MARK: - Gate rail

struct GateRail: View {
    let approvals: [String: FilmApproval]

    static let gates = ["brief", "treatment", "production", "picture-lock", "delivery"]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Self.gates, id: \.self) { gate in
                GateRow(name: StudioText.gateName(gate), status: approvals[gate]?.status)
            }
        }
        .animation(.spring(duration: 0.45), value: statuses)
    }

    private var statuses: [String?] {
        Self.gates.map { approvals[$0]?.status }
    }
}

private struct GateRow: View {
    let name: String
    let status: String?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(status == nil ? 0.10 : 0.16))
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption.weight(.semibold))
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    private var statusLabel: String {
        switch status {
        case "approved": "Approved"
        case "pending": "Awaiting you"
        default: "Upcoming"
        }
    }

    private var symbol: String {
        switch status {
        case "approved": "checkmark"
        case "pending": "hand.raised.fill"
        default: "lock.fill"
        }
    }

    private var tint: Color {
        switch status {
        case "approved": Studio.pass
        case "pending": Studio.accent
        default: .secondary
        }
    }
}

// MARK: - Proof dial

struct ProofDial: View {
    let completed: Int
    let total: Int

    init(proof: FilmProof) {
        completed = proof.completedCount
        total = ProofChecklist.rows(proof).count
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 7)
            Circle()
                .trim(from: 0, to: total == 0 ? 0 : Double(completed) / Double(total))
                .stroke(
                    isComplete ? Studio.pass : Studio.accent,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(completed)")
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("of \(total)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 104, height: 104)
        .animation(.spring(duration: 0.7), value: completed)
    }

    private var isComplete: Bool {
        total > 0 && completed >= total
    }
}

// MARK: - Proof checklist

struct ProofChecklist: View {
    let proof: FilmProof

    static func rows(_ proof: FilmProof) -> [(title: String, proved: Bool, symbol: String)] {
        [
            ("Creation canon", proof.creation, "person.crop.rectangle.stack"),
            ("Selected clips", proof.clips, "film.stack"),
            ("Playable assembly", proof.assembly, "play.rectangle"),
            ("Dialogue intelligibility", proof.dialogue, "quote.bubble"),
            ("Sound and loudness", proof.sound, "waveform"),
            ("Caption sidecars", proof.captions, "captions.bubble"),
            ("Visual inspection", proof.inspection, "eye"),
            ("Independent review", proof.review, "person.badge.shield.checkmark"),
            ("Human decision", proof.humanReview, "hand.raised"),
            ("Delivery manifest", proof.delivery, "shippingbox"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proof")
                .panelTitle()
            ForEach(Self.rows(proof), id: \.title) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.proved ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(row.proved ? Studio.pass : Color.secondary.opacity(0.4))
                        .contentTransition(.symbolEffect(.replace))
                    Label(row.title, systemImage: row.symbol)
                        .font(.callout)
                    Spacer()
                    Text(row.proved ? "Proved" : "Pending")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(row.proved ? AnyShapeStyle(Studio.pass) : AnyShapeStyle(.tertiary))
                }
            }
        }
        .animation(.spring(duration: 0.4), value: proof)
        .studioPanel()
    }
}

// MARK: - Metric card

struct MetricCard: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .panelTitle()
            Text(value)
                .font(.system(size: 27, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(duration: 0.5), value: value)
        .studioPanel()
    }
}

// MARK: - Artifact images

/// Off-main decode with downsampling and an in-memory cache, so keyframe
/// grids scroll without hitching on full-resolution renders.
enum ArtifactImageLoader {
    @MainActor private static let cache = NSCache<NSURL, NSImage>()

    private struct DecodedImage: @unchecked Sendable {
        let image: NSImage?
    }

    @MainActor
    static func load(_ url: URL, maxPixels: Int = 1_000) async -> NSImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        let decoded = await Task.detached(priority: .utility) {
            DecodedImage(image: decode(url, maxPixels: maxPixels))
        }.value
        if let image = decoded.image {
            cache.setObject(image, forKey: url as NSURL)
        }
        return decoded.image
    }

    private static func decode(_ url: URL, maxPixels: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}

struct ArtifactImage: View {
    let url: URL?
    @State private var image: NSImage?

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.03))
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                }
            }
            .clipped()
            .animation(.easeOut(duration: 0.22), value: image != nil)
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            image = await ArtifactImageLoader.load(url)
        }
    }
}

// MARK: - Looping clip preview

/// Muted, looping playback for hover previews on shot cards.
struct LoopingClipView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> LoopingClipNSView {
        LoopingClipNSView(url: url)
    }

    func updateNSView(_ view: LoopingClipNSView, context: Context) {
        view.update(url: url)
    }
}

final class LoopingClipNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    init(url: URL) {
        super.init(frame: .zero)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
        update(url: url)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func update(url: URL) {
        guard url != currentURL else { return }
        currentURL = url
        let queue = AVQueuePlayer()
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        player = queue
        playerLayer.player = queue
        queue.play()
    }
}

// MARK: - Empty state

struct EmptyStage: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
    }
}

// MARK: - Text editor with placeholder

struct StudioTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = .body
    var minHeight: CGFloat = 96

    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(font)
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: minHeight)
            .background(Studio.raised, in: RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Studio.radiusMedium, style: .continuous)
                    .strokeBorder(focused ? Studio.accent.opacity(0.55) : Studio.stroke)
            }
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(font)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
            .focused($focused)
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}
