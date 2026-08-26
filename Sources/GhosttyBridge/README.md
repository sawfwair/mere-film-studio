# GhosttyBridge

Narrow terminal adapter around the pinned GhosttyKit framework. Upstream
Ghostty details must not escape this module (DECISIONS.md 003).

## Layout

- `GhosttyTerminalView.swift` — the SwiftUI surface: `GhosttyTerminalView`
  (NSViewRepresentable), `GhosttySurfaceView` (input, focus, geometry), and
  the published `GhosttyTerminalModel`.
- `GhosttySurfaceRegistry.swift` — maps Ghostty userdata pointers back to
  live views with weak entries, so asynchronous callbacks can never touch a
  deallocated surface view.
- `GhosttyRuntime.swift` — global app/config lifecycle plus the C callback
  shims (wakeup, actions, clipboard, close-surface).

## Rules

- Nothing upstream escapes: other modules see only `GhosttyBridge.availability`
  and the view/model types.
- The framework revision is pinned in `Vendor/ghostty-version.json`; never
  bump it casually (the embedding API is unstable).
- The terminal is dark-only; the app pins its own color scheme.
