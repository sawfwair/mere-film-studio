import Foundation

/// One caption cue, in film time.
public struct CaptionCue: Sendable, Equatable, Identifiable {
    public let id: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let text: String

    public init(id: Int, startSeconds: Double, endSeconds: Double, text: String) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
    }
}

/// Parses the caption sidecars the tools produce: SubRip (.srt) and
/// WebVTT (.vtt). Tolerant by design — malformed blocks are skipped, styling
/// tags are stripped, and an unreadable file yields an empty list rather
/// than an error, because captions are evidence to display, not state.
public enum CaptionParser {
    public static func load(from url: URL) -> [CaptionCue] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return parse(String(decoding: data, as: UTF8.self))
    }

    public static func parse(_ content: String) -> [CaptionCue] {
        let blocks = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
        var cues: [CaptionCue] = []
        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timing = lines[timingIndex].components(separatedBy: "-->")
            guard timing.count == 2,
                  let start = seconds(timing[0]),
                  // VTT cue settings ("align:center") follow the end stamp.
                  let end = seconds(timing[1].components(separatedBy: .whitespaces)
                      .first(where: { !$0.isEmpty }) ?? "") else { continue }
            let text = lines[(timingIndex + 1)...]
                .joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            cues.append(CaptionCue(id: cues.count, startSeconds: start, endSeconds: end, text: text))
        }
        return cues
    }

    /// "00:00:01,500", "00:01.500", or "1:02:03.250" → seconds.
    static func seconds(_ stamp: String) -> Double? {
        let cleaned = stamp.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.split(separator: ":").map(String.init)
        guard (2...3).contains(parts.count) else { return nil }
        var total = 0.0
        for part in parts {
            guard let value = Double(part) else { return nil }
            total = total * 60 + value
        }
        return total
    }
}
