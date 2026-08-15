import AppKit
import Combine
import Foundation
import GhosttyKit
import SwiftUI

private func decodeUTF8(_ pointer: UnsafePointer<CChar>, count: Int) -> String {
    String(decoding: UnsafeRawBufferPointer(start: pointer, count: count), as: UTF8.self)
}

private enum GhosttyGlobal {
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
    @Published public fileprivate(set) var title = "Pi producer-director"
    @Published public fileprivate(set) var workingDirectory: String?
    @Published public fileprivate(set) var processExited = false
    @Published public fileprivate(set) var rendererHealthy = true

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

    public static func dismantleNSView(_ view: GhosttySurfaceView, coordinator: ()) {
        view.shutdown()
    }
}

@MainActor
public final class GhosttySurfaceView: NSView {
    fileprivate nonisolated(unsafe) var surface: ghostty_surface_t?
    fileprivate let model: GhosttyTerminalModel
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
        model.processExited = false
        model.rendererHealthy = true
        focusRingType = .none

        guard let app = runtime.app else { return }
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
        guard let surface else { return }
        if Thread.isMainThread {
            ghostty_surface_free(surface)
        } else {
            Task.detached { @MainActor in
                ghostty_surface_free(surface)
            }
        }
    }

    public override func layout() {
        super.layout()
        updateSurfaceGeometry()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAppearance()
        updateSurfaceGeometry()
        if let window, let screen = window.screen, let surface {
            ghostty_surface_set_display_id(surface, screen.displayID)
        }
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
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
        let appearance = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        ghostty_surface_set_color_scheme(
            surface,
            appearance == .darkAqua ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT
        )
    }

    fileprivate func childExited() {
        model.processExited = true
    }

    fileprivate func shutdown() {
        guard let surface else { return }
        if isFocused {
            ghostty_surface_set_focus(surface, false)
            isFocused = false
        }
        self.surface = nil
        ghostty_surface_free(surface)

        // libghostty installs an IOSurface-backed layer on this view. SwiftUI
        // may retain a dismantled NSView, so detach that layer immediately
        // instead of waiting for deinitialization.
        layer = nil
        wantsLayer = false
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

private func filmStudioGhosttyWakeup(_ userdata: UnsafeMutableRawPointer?) {
    GhosttyRuntime.runtimeWakeup(userdata)
}

private func filmStudioGhosttyAction(
    _ app: ghostty_app_t?,
    _ target: ghostty_target_s,
    _ action: ghostty_action_s
) -> Bool {
    GhosttyRuntime.runtimeAction(app, target, action)
}

private func filmStudioGhosttyReadClipboard(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ state: UnsafeMutableRawPointer?
) -> Bool {
    GhosttyRuntime.runtimeReadClipboard(userdata, location, state)
}

private func filmStudioGhosttyConfirmReadClipboard(
    _ userdata: UnsafeMutableRawPointer?,
    _ value: UnsafePointer<CChar>?,
    _ state: UnsafeMutableRawPointer?,
    _ request: ghostty_clipboard_request_e
) {
    GhosttyRuntime.runtimeConfirmReadClipboard(userdata, value, state, request)
}

private func filmStudioGhosttyWriteClipboard(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ content: UnsafePointer<ghostty_clipboard_content_s>?,
    _ count: Int,
    _ confirm: Bool
) {
    GhosttyRuntime.runtimeWriteClipboard(userdata, location, content, count, confirm)
}

private func filmStudioGhosttyCloseSurface(_ userdata: UnsafeMutableRawPointer?, _ processAlive: Bool) {
    GhosttyRuntime.runtimeCloseSurface(userdata, processAlive)
}

private final class GhosttyRuntime: @unchecked Sendable {
    @MainActor
    static let shared = GhosttyRuntime()

    fileprivate nonisolated(unsafe) private(set) var app: ghostty_app_t?
    private nonisolated(unsafe) var config: ghostty_config_t?

    @MainActor
    private init() {
        guard GhosttyGlobal.initialized else { return }
        guard let config = ghostty_config_new() else { return }
        self.config = config
        if let path = Bundle.main.url(forResource: "ghostty-studio", withExtension: "conf")?.path {
            path.withCString { ghostty_config_load_file(config, $0) }
        } else {
            ghostty_config_load_default_files(config)
        }
        ghostty_config_finalize(config)

        var runtime = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: false,
            wakeup_cb: filmStudioGhosttyWakeup,
            action_cb: filmStudioGhosttyAction,
            read_clipboard_cb: filmStudioGhosttyReadClipboard,
            confirm_read_clipboard_cb: filmStudioGhosttyConfirmReadClipboard,
            write_clipboard_cb: filmStudioGhosttyWriteClipboard,
            close_surface_cb: filmStudioGhosttyCloseSurface
        )
        app = ghostty_app_new(&runtime, config)
        if let app { ghostty_app_set_focus(app, NSApp.isActive) }
    }

    deinit {
        if let app { ghostty_app_free(app) }
        if let config { ghostty_config_free(config) }
    }

    @MainActor
    private func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    fileprivate static func runtimeWakeup(_ userdata: UnsafeMutableRawPointer?) {
        guard let userdata else { return }
        let runtime = Unmanaged<GhosttyRuntime>.fromOpaque(userdata).takeUnretainedValue()
        DispatchQueue.main.async { runtime.tick() }
    }

    fileprivate static func runtimeAction(
        _ app: ghostty_app_t?,
        _ target: ghostty_target_s,
        _ action: ghostty_action_s
    ) -> Bool {
        _ = app
        return handle(target: target, action: action)
    }

    fileprivate static func runtimeReadClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        _ location: ghostty_clipboard_e,
        _ state: UnsafeMutableRawPointer?
    ) -> Bool {
        _ = location
        return readClipboard(userdata: userdata, state: state)
    }

    fileprivate static func runtimeConfirmReadClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        _ value: UnsafePointer<CChar>?,
        _ state: UnsafeMutableRawPointer?,
        _ request: ghostty_clipboard_request_e
    ) {
        _ = value
        _ = request
        rejectClipboard(userdata: userdata, state: state)
    }

    fileprivate static func runtimeWriteClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        _ location: ghostty_clipboard_e,
        _ content: UnsafePointer<ghostty_clipboard_content_s>?,
        _ count: Int,
        _ confirm: Bool
    ) {
        _ = userdata
        _ = location
        writeClipboard(content: content, count: count, confirm: confirm)
    }

    fileprivate static func runtimeCloseSurface(_ userdata: UnsafeMutableRawPointer?, _ processAlive: Bool) {
        _ = processAlive
        guard let userdata else { return }
        let address = UInt(bitPattern: userdata)
        DispatchQueue.main.async {
            surfaceView(address: address)?.childExited()
        }
    }

    private static func handle(target: ghostty_target_s, action: ghostty_action_s) -> Bool {
        guard target.tag == GHOSTTY_TARGET_SURFACE,
              let surface = target.target.surface,
              let userdata = ghostty_surface_userdata(surface) else {
            return action.tag != GHOSTTY_ACTION_OPEN_URL
        }
        let address = UInt(bitPattern: userdata)

        switch action.tag {
        case GHOSTTY_ACTION_SET_TITLE:
            if let pointer = action.action.set_title.title {
                let title = String(cString: pointer)
                DispatchQueue.main.async {
                    surfaceView(address: address)?.model.title = title
                }
            }
        case GHOSTTY_ACTION_PWD:
            if let pointer = action.action.pwd.pwd {
                let directory = String(cString: pointer)
                DispatchQueue.main.async {
                    surfaceView(address: address)?.model.workingDirectory = directory.removingPercentEncoding ?? directory
                }
            }
        case GHOSTTY_ACTION_RENDERER_HEALTH:
            let healthy = action.action.renderer_health == GHOSTTY_RENDERER_HEALTH_HEALTHY
            DispatchQueue.main.async {
                surfaceView(address: address)?.model.rendererHealthy = healthy
            }
        case GHOSTTY_ACTION_OPEN_URL:
            guard let pointer = action.action.open_url.url else { return false }
            let string = decodeUTF8(pointer, count: Int(action.action.open_url.len))
            guard let url = URL(string: string), ["https", "http"].contains(url.scheme) else {
                return false
            }
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
            DispatchQueue.main.async {
                surfaceView(address: address)?.childExited()
            }
        default:
            break
        }
        return true
    }

    private static func readClipboard(userdata: UnsafeMutableRawPointer?, state: UnsafeMutableRawPointer?) -> Bool {
        _ = userdata
        _ = state
        return false
    }

    private static func rejectClipboard(userdata: UnsafeMutableRawPointer?, state: UnsafeMutableRawPointer?) {
        _ = userdata
        _ = state
    }

    private static func writeClipboard(
        content: UnsafePointer<ghostty_clipboard_content_s>?,
        count: Int,
        confirm: Bool
    ) {
        guard !confirm, let content, count > 0 else { return }
        for index in 0..<count {
            guard let mime = content[index].mime, String(cString: mime) == "text/plain",
                  let data = content[index].data else { continue }
            let value = String(cString: data)
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }
            return
        }
    }

    @MainActor
    private static func surfaceView(address: UInt) -> GhosttySurfaceView? {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return nil }
        return Unmanaged<GhosttySurfaceView>.fromOpaque(pointer).takeUnretainedValue()
    }
}

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
