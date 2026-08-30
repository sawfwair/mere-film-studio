import AVFoundation
import AppKit
import FilmStudioCore
import SwiftUI

// MARK: - Status badge

struct StatusBadge: View {
    let status: FilmContractStatus

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
        if status.isSettled { return Studio.pass }
        if status.isInFlight { return Studio.accent }
        if status.isFailed { return Studio.fail }
        return .secondary
    }
}

// MARK: - Gate rail

struct GateRail: View {
    let approvals: [String: FilmApproval]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(FilmGate.allCases) { gate in
                GateRow(name: gate.displayName, approval: approvals[gate.rawValue])
            }
        }
        .animation(.spring(duration: 0.45), value: statuses)
    }

    private var statuses: [FilmContractStatus?] {
        FilmGate.allCases.map { approvals[$0.rawValue]?.status }
    }
}

private struct GateRow: View {
    let name: String
    let approval: FilmApproval?

    private var status: FilmContractStatus? { approval?.status }

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
        .help(provenance)
    }

    /// The ledger records who approved what and when; surface it on hover so
    /// the rail is a receipt, not just a status light.
    private var provenance: String {
        guard let approval else { return "\(name) — upcoming" }
        var lines: [String] = []
        if status == .approved, let by = approval.approvedBy {
            lines.append("Approved by \(by)\(approval.approvedAt.map { " · \($0)" } ?? "")")
        }
        if let note = approval.note, !note.isEmpty { lines.append(note) }
        if lines.isEmpty, let summary = approval.summary, !summary.isEmpty { lines.append(summary) }
        return lines.isEmpty ? "\(name) — \(statusLabel.lowercased())" : lines.joined(separator: "\n")
    }

    private var statusLabel: String {
        if status == .approved { return "Approved" }
        if status == .pending { return "Awaiting you" }
        return "Upcoming"
    }

    private var symbol: String {
        if status == .approved { return "checkmark" }
        if status == .pending { return "hand.raised.fill" }
        return "lock.fill"
    }

    private var tint: Color {
        if status == .approved { return Studio.pass }
        if status == .pending { return Studio.accent }
        return .secondary
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
    @MainActor private static let cache = NSCache<NSString, NSImage>()

    private struct DecodedImage: @unchecked Sendable {
        // The wrapper exists only to carry the non-Sendable NSImage across the
        // detached-task boundary without tripping strict concurrency checks;
        // the image is handed to exactly one consumer on the main actor.
        let image: NSImage?
    }

    /// `revision` is the artifact's content hash: rerolls rewrite the same
    /// path, so the path alone would pin the stale frame forever.
    @MainActor
    static func load(_ url: URL, revision: String?, maxPixels: Int = 1_000) async -> NSImage? {
        let key = "\(url.path)|\(revision ?? "")" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let decoded = await Task.detached(priority: .utility) {
            DecodedImage(image: decode(url, maxPixels: maxPixels))
        }.value
        if let image = decoded.image {
            cache.setObject(image, forKey: key)
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
    var revision: String?
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
        .task(id: "\(url?.path ?? "")|\(revision ?? "")") {
            guard let url else {
                image = nil
                return
            }
            image = await ArtifactImageLoader.load(url, revision: revision)
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

    static func dismantleNSView(_ view: LoopingClipNSView, coordinator: ()) {
        // Hover previews come and go constantly; without this, every dismissed
        // preview keeps an AVPlayerLooper decoding video in the background.
        view.pause()
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

    func pause() {
        player?.pause()
        playerLayer.player = nil
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
