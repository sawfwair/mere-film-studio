import AppKit
import Foundation
import GhosttyKit

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

/// JUSTIFIED: @unchecked Sendable — all mutable state is MainActor-confined;
/// the class exists to hold the C callback vtable and app/config handles.
final class GhosttyRuntime: @unchecked Sendable {
    @MainActor
    static let shared = GhosttyRuntime()

    nonisolated(unsafe) private(set) var application: ghostty_app_t?
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
        application = ghostty_app_new(&runtime, config)
        if let application { ghostty_app_set_focus(application, NSApp.isActive) }
    }

    deinit {
        if let app = application { ghostty_app_free(app) }
        if let config { ghostty_config_free(config) }
    }

    @MainActor
    private func tick() {
        guard let app = application else { return }
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
            MainActor.assumeIsolated {
                guard let view = GhosttySurfaceRegistry.shared.liveView(address: address) else { return }
                view.childExited()
            }
        }
    }

    /// Only http(s) links open in the default browser; anything else falls
    /// through unhandled so Ghostty's own defaults decide.
    private static func openURL(action: ghostty_action_s) -> Bool {
        guard action.tag == GHOSTTY_ACTION_OPEN_URL,
              let pointer = action.action.open_url.url else { return false }
        let string = decodeUTF8(pointer, count: Int(action.action.open_url.len))
        guard let url = URL(string: string), ["https", "http"].contains(url.scheme) else {
            return false
        }
        DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        return true
    }

    private static func readClipboard(userdata: UnsafeMutableRawPointer?, state: UnsafeMutableRawPointer?) -> Bool {
        // Clipboard reads are intentionally denied; paste flows through the
        // surface's own paste() bridge instead.
        _ = userdata
        _ = state
        return false
    }

    private static func rejectClipboard(userdata: UnsafeMutableRawPointer?, state: UnsafeMutableRawPointer?) {
        _ = userdata
        _ = state
    }

    /// Runs `update` on the registered surface view (main thread) when a raw
    /// C-string payload is present; silently no-ops otherwise.
    private static func dispatchCString(
        address: UInt,
        payload: UnsafePointer<CChar>?,
        update: @escaping @MainActor (GhosttySurfaceView, String) -> Void
    ) {
        guard let pointer = payload else { return }
        let text = String(cString: pointer)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let view = GhosttySurfaceRegistry.shared.liveView(address: address) else { return }
                update(view, text)
            }
        }
    }

    /// Runs `update` on the registered surface view (main thread) with a
    /// decoded string payload; silently no-ops when absent.
    private static func dispatchString(
        address: UInt,
        payload: String?,
        update: @escaping @MainActor (GhosttySurfaceView, String) -> Void
    ) {
        guard let text = payload else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let view = GhosttySurfaceRegistry.shared.liveView(address: address) else { return }
                update(view, text)
            }
        }
    }

    /// Routes Ghostty surface actions to the app. Returns false only for
    /// actions the studio deliberately does not handle (non-http URLs).
    private static func handle(target: ghostty_target_s, action: ghostty_action_s) -> Bool {
        guard target.tag == GHOSTTY_TARGET_SURFACE,
              let surface = target.target.surface,
              let userdata = ghostty_surface_userdata(surface) else {
            return action.tag != GHOSTTY_ACTION_OPEN_URL
        }
        let address = UInt(bitPattern: userdata)

        switch action.tag {
        case GHOSTTY_ACTION_SET_TITLE:
            dispatchCString(address: address, payload: action.action.set_title.title) { view, text in
                view.model.setTitle(text)
            }
        case GHOSTTY_ACTION_PWD:
            dispatchString(address: address, payload: action.action.pwd.pwd.map { String(cString: $0) }) { view, directory in
                view.model.setWorkingDirectory(directory)
            }
        case GHOSTTY_ACTION_RENDERER_HEALTH:
            let healthy = action.action.renderer_health == GHOSTTY_RENDERER_HEALTH_HEALTHY
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let view = GhosttySurfaceRegistry.shared.liveView(address: address) else { return }
                    view.model.setRendererHealthy(healthy)
                }
            }
        case GHOSTTY_ACTION_OPEN_URL:
            return openURL(action: action)
        case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
            DispatchQueue.main.async {
                guard let view = GhosttySurfaceRegistry.shared.liveView(address: address) else { return }
                view.childExited()
            }
        default:
            break
        }
        return true
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
}
