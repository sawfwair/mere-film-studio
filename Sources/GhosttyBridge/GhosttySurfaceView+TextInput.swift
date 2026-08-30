import AppKit
import GhosttyKit

// MARK: - Input method support

/// Minimal NSTextInputClient so dead keys, CJK composition, dictation, and
/// the character palette work inside the Pi room. Preedit text renders in
/// the terminal cell via ghostty_surface_preedit; the candidate window is
/// anchored with ghostty_surface_ime_point.
extension GhosttySurfaceView: @preconcurrency NSTextInputClient {
    public func insertText(_ string: Any, replacementRange: NSRange) {
        let text: String
        switch string {
        case let attributed as NSAttributedString: text = attributed.string
        case let plain as String: text = plain
        default: return
        }
        unmarkText()
        if keyTextAccumulator != nil {
            keyTextAccumulator?.append(text)
        } else if let surface {
            // Insertion outside a key event: dictation or the character
            // palette. There is no key to pair it with, so send it directly.
            text.withCString { pointer in
                ghostty_surface_text(surface, pointer, UInt(text.utf8.count))
            }
        }
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        switch string {
        case let attributed as NSAttributedString:
            markedText = NSMutableAttributedString(attributedString: attributed)
        case let plain as String:
            markedText = NSMutableAttributedString(string: plain)
        default:
            return
        }
        syncPreedit()
    }

    public func unmarkText() {
        guard markedText.length > 0 else { return }
        markedText = NSMutableAttributedString()
        syncPreedit()
    }

    public func selectedRange() -> NSRange {
        NSRange(location: NSNotFound, length: 0)
    }

    public func markedRange() -> NSRange {
        markedText.length > 0
            ? NSRange(location: 0, length: markedText.length)
            : NSRange(location: NSNotFound, length: 0)
    }

    public func hasMarkedText() -> Bool {
        markedText.length > 0
    }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let window, let surface else { return .zero }
        var x: Double = 0
        var y: Double = 0
        var width: Double = 0
        var height: Double = 0
        ghostty_surface_ime_point(surface, &x, &y, &width, &height)
        // The cursor cell arrives in view-local top-left coordinates; this
        // view is flipped, so it converts straight through to the screen.
        let viewRect = NSRect(x: x, y: y, width: max(width, 1), height: max(height, 1))
        return window.convertToScreen(convert(viewRect, to: nil))
    }

    public func characterIndex(for point: NSPoint) -> Int {
        0
    }

    private func syncPreedit() {
        guard let surface else { return }
        let text = markedText.string
        if text.isEmpty {
            ghostty_surface_preedit(surface, nil, 0)
        } else {
            text.withCString { pointer in
                ghostty_surface_preedit(surface, pointer, UInt(text.utf8.count))
            }
        }
    }
}
