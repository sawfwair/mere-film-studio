import AppKit
import Combine
import Foundation
import GhosttyKit
import SwiftUI

func decodeUTF8(_ pointer: UnsafePointer<CChar>, count: Int) -> String {
    String(decoding: UnsafeRawBufferPointer(start: pointer, count: count), as: UTF8.self)
}

enum GhosttyGlobal {
    static let initialized = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS
}

public enum GhosttyAvailability: Sendable, Equatable {
    case available(version: String)
    case unavailable(reason: String)
}

public enum GhosttyBridge {
    public static var availability: GhosttyAvailability {
        guard GhosttyGlobal.initialized else {
            return .unavailable(reason: "Ghostty failed to initialize.")
        }
        let info = ghostty_info()
        guard let version = info.version else {
            return .unavailable(reason: "Ghostty did not report a version.")
        }
        return .available(version: decodeUTF8(version, count: Int(info.version_len)))
    }
}

@MainActor
public final class GhosttyTerminalModel: ObservableObject {
    // Setters are internal so the runtime callbacks (same module, separate
    // file) can publish updates; the app only reads.
    @Published public private(set) var title = "Pi producer-director"
    @Published public private(set) var workingDirectory: String?
    @Published public private(set) var processExited = false
    @Published public private(set) var rendererHealthy = true

    func setTitle(_ value: String) { title = value }
    func setWorkingDirectory(_ value: String?) { workingDirectory = value }
    func setProcessExited(_ value: Bool) { processExited = value }
    func setRendererHealthy(_ value: Bool) { rendererHealthy = value }

    /// Clears per-session state when a fresh terminal surface starts.
    func resetSessionState() {
        processExited = false
        rendererHealthy = true
    }

    public init() {}
}

public struct GhosttyTerminalView: NSViewRepresentable {
    public let command: String
    public let workingDirectory: URL
    public let environment: [String: String]
    @ObservedObject public var model: GhosttyTerminalModel

    public init(
        command: String,
        workingDirectory: URL,
        environment: [String: String] = [:],
        model: GhosttyTerminalModel
    ) {
        self.command = command
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.model = model
    }

    public func makeNSView(context: Context) -> GhosttySurfaceView {
        GhosttySurfaceView(
            runtime: GhosttyRuntime.shared,
            command: command,
            workingDirectory: workingDirectory,
            environment: environment,
            model: model
        )
    }

    public func updateNSView(_ view: GhosttySurfaceView, context: Context) {
        view.updateAppearance()
    }
}

@MainActor
public final class GhosttySurfaceView: NSView {
    nonisolated(unsafe) var surface: ghostty_surface_t?
    let model: GhosttyTerminalModel
    private var isFocused = false

    public override var acceptsFirstResponder: Bool { true }
    public override var isFlipped: Bool { true }

    fileprivate init(
        runtime: GhosttyRuntime,
        command: String,
        workingDirectory: URL,
        environment: [String: String],
        model: GhosttyTerminalModel
    ) {
        self.model = model
        super.init(frame: NSRect(x: 0, y: 0, width: 960, height: 420))
        GhosttySurfaceRegistry.shared.register(self)
        model.resetSessionState()
        focusRingType = .none

        guard let app = runtime.application else { return }
        var config = ghostty_surface_config_new()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(nsview: Unmanaged.passUnretained(self).toOpaque())
        )
        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2)
        config.font_size = 13
        config.wait_after_command = true

        command.withCString { commandPointer in
            workingDirectory.path.withCString { directoryPointer in
                let keys = Array(environment.keys)
                let values = keys.map { environment[$0] ?? "" }
                keys.withCStrings { keyPointers in
                    values.withCStrings { valuePointers in
                        var variables = zip(keyPointers, valuePointers).map {
                            ghostty_env_var_s(key: $0.0, value: $0.1)
                        }
                        let variableCount = variables.count
                        variables.withUnsafeMutableBufferPointer { buffer in
                            config.command = commandPointer
                            config.working_directory = directoryPointer
                            config.env_vars = buffer.baseAddress
                            config.env_var_count = variableCount
                            surface = ghostty_surface_new(app, &config)
                        }
                    }
                }
            }
        }

        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    deinit {
        if let surface { ghostty_surface_free(surface) }
    }

    public override func layout() {
        super.layout()
        updateSurfaceGeometry()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateSurfaceGeometry()
        if let window, let screen = window.screen, let surface {
            ghostty_surface_set_display_id(surface, screen.displayID)
        }
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateSurfaceGeometry()
    }

    public override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { updateFocus(true) }
        return accepted
    }

    public override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { updateFocus(false) }
        return accepted
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let surface else { return }
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, event.ghosttyModifiers)
    }

    public override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, event.ghosttyModifiers)
    }

    public override func mouseMoved(with event: NSEvent) { sendMousePosition(event) }
    public override func mouseDragged(with event: NSEvent) { sendMousePosition(event) }

    public override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, 0)
    }

    public override func keyDown(with event: NSEvent) {
        sendKey(event, action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS)
    }

    public override func keyUp(with event: NSEvent) {
        sendKey(event, action: GHOSTTY_ACTION_RELEASE)
    }

    @objc public func paste(_ sender: Any?) {
        guard let surface, let text = NSPasteboard.general.string(forType: .string) else { return }
        text.withCString { pointer in
            ghostty_surface_text(surface, pointer, UInt(text.utf8.count))
        }
    }

    @objc public func copy(_ sender: Any?) {
        guard let surface, ghostty_surface_has_selection(surface) else { return }
        var text = ghostty_text_s()
        guard ghostty_surface_read_selection(surface, &text), let pointer = text.text else { return }
        defer { ghostty_surface_free_text(surface, &text) }
        let value = decodeUTF8(pointer, count: Int(text.text_len))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    public func updateAppearance() {
        guard let surface else { return }
        // The app pins the whole UI to dark (see MereFilmStudioApp), so the
        // terminal always follows dark rather than tracking the system.
        ghostty_surface_set_color_scheme(surface, GHOSTTY_COLOR_SCHEME_DARK)
    }

    func childExited() {
        model.setProcessExited(true)
    }

    private func updateFocus(_ focused: Bool) {
        guard isFocused != focused, let surface else { return }
        isFocused = focused
        ghostty_surface_set_focus(surface, focused)
    }

    private func updateSurfaceGeometry() {
        guard let surface, bounds.width > 0, bounds.height > 0 else { return }
        let backing = convertToBacking(bounds)
        let xScale = backing.width / bounds.width
        let yScale = backing.height / bounds.height
        ghostty_surface_set_content_scale(surface, xScale, yScale)
        ghostty_surface_set_size(surface, UInt32(backing.width.rounded()), UInt32(backing.height.rounded()))
    }

    private func sendMousePosition(_ event: NSEvent) {
        guard let surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        let backing = convertToBacking(NSRect(origin: point, size: .zero)).origin
        ghostty_surface_mouse_pos(surface, backing.x, backing.y, event.ghosttyModifiers)
    }

    private func sendKey(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }
        var input = ghostty_input_key_s()
        input.action = action
        input.keycode = UInt32(event.keyCode)
        input.mods = event.ghosttyModifiers
        input.consumed_mods = event.ghosttyConsumedModifiers
        input.composing = false
        if let scalar = event.characters(byApplyingModifiers: [])?.unicodeScalars.first {
            input.unshifted_codepoint = scalar.value
        }

        let text = event.ghosttyCharacters
        if let text {
            text.withCString { pointer in
                input.text = pointer
                _ = ghostty_surface_key(surface, input)
            }
        } else {
            _ = ghostty_surface_key(surface, input)
        }
    }
}

/// Maps the raw userdata pointers Ghostty hands back to callbacks onto live
/// views. Entries hold weak references, so a callback that fires after a view
/// deallocates (they arrive asynchronously on the main queue) finds nil
/// instead of dereferencing a dangling pointer. Stale entries are harmless:
/// they are overwritten if an address is ever reused by a new surface view.
private extension Array where Element == String {
    func withCStrings<Result>(_ body: ([UnsafePointer<CChar>]) -> Result) -> Result {
        func descend(_ index: Int, _ pointers: [UnsafePointer<CChar>]) -> Result {
            guard index < count else { return body(pointers) }
            return self[index].withCString { pointer in descend(index + 1, pointers + [pointer]) }
        }
        return descend(0, [])
    }
}

private extension NSEvent {
    var ghosttyModifiers: ghostty_input_mods_e {
        var raw: UInt32 = 0
        if modifierFlags.contains(.shift) { raw |= UInt32(GHOSTTY_MODS_SHIFT.rawValue) }
        if modifierFlags.contains(.control) { raw |= UInt32(GHOSTTY_MODS_CTRL.rawValue) }
        if modifierFlags.contains(.option) { raw |= UInt32(GHOSTTY_MODS_ALT.rawValue) }
        if modifierFlags.contains(.command) { raw |= UInt32(GHOSTTY_MODS_SUPER.rawValue) }
        if modifierFlags.contains(.capsLock) { raw |= UInt32(GHOSTTY_MODS_CAPS.rawValue) }
        return ghostty_input_mods_e(rawValue: raw)
    }

    var ghosttyConsumedModifiers: ghostty_input_mods_e {
        var raw = ghosttyModifiers.rawValue
        raw &= ~GHOSTTY_MODS_CTRL.rawValue
        raw &= ~GHOSTTY_MODS_SUPER.rawValue
        return ghostty_input_mods_e(rawValue: raw)
    }

    var ghosttyCharacters: String? {
        guard let characters else { return nil }
        if characters.count == 1, let scalar = characters.unicodeScalars.first {
            if scalar.value < 0x20 {
                return self.characters(byApplyingModifiers: modifierFlags.subtracting(.control))
            }
            if (0xF700...0xF8FF).contains(scalar.value) { return nil }
        }
        return characters
    }
}

private extension NSScreen {
    var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
