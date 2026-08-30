# Decisions

## 001 — Native macOS product

Mere Film Studio uses SwiftUI and AppKit instead of a cross-platform web shell.
The local media runtime already targets Apple Silicon, and the product depends
on native video, windowing, drag-and-drop, file coordination, and a Metal-backed
terminal surface.

## 002 — Projection, not orchestration

The application projects and controls `mere-film-tools` state. It does not
duplicate phase advancement, approval rules, job scheduling, or recovery.

## 003 — Ghostty behind an adapter

Ghostty provides the preferred embedded Pi terminal. Its embedding API is not
stable, so the dependency is pinned and contained within `GhosttyBridge`. If
the framework or terminal runtime is unavailable, the app fails visibly with
setup guidance instead of silently changing terminal implementations.

## 004 — Explicit Animatic handoff

Publishing to Animatic uses a versioned, checksum-backed handoff contract.
Mere Film Studio never writes into the Animatic source checkout or database
directly. The installed `animatic` CLI owns authenticated import.

## 005 — No app-owned project database

The film directory is authoritative. App preferences may remember recent
project bookmarks, layout, and presentation state, but never canonical creative
or production state.

## 006 — Composed local-agent boundary

The native Pi room composes three owners instead of replacing any one of them:
`mere.run` owns local provider discovery and the model-server lifecycle,
`mere-film-tools` owns the film extension and durable production workflow, and
Pi owns the interactive agent loop. The app resolves the `mere.run` and Pi
executables independently from project data, selects only an installed,
startable model reported by `mere.run agent status`, then forwards the exact
film-harness arguments through `mere.run agent start --inline`. Project
manifests remain authoritative production state but cannot silently replace
either executable used by the room.

## 007 — Tolerant watcher refresh

Watcher-driven project reloads swallow transient decode failures while a
snapshot is already on screen. Production tools rewrite ledger JSON during
long runs, and the file watcher fires mid-write; making those races loud
would interrupt the operator with alerts about healthy projects. Explicit
opens (menu, startup restore) still surface every error.

## 008 — Unbounded advance and review, cancellable instead of timed out

`advance` and `review` intentionally have no wall-clock timeout: legitimate
multi-hour local renders would be killed by any sane limit. They are bounded
by the human instead — the toolbar Cancel button (and ⌘.) terminates the
child process via task cancellation. Auxiliary commands (`plan`, `approve`,
Animatic import, agent status) do carry fixed timeouts because a hang there
has no legitimate explanation. Do not add a default timeout to long-running
commands; extend the timeout table only with evidence.

## 009 — Local handoff verification before Animatic import

Publishing to Animatic builds the handoff manifest in-process through
`AnimaticHandoffBuilder`, which re-hashes every exported artifact against the
ledger before writing it. The app deliberately does not trust the CLI's
export step for verification: the studio's promise is that a manifest reaching
Animatic describes bytes that provably match the accepted takes. Keep this
ordering when touching the publish path.

## 010 — Swift 6 language mode and complete concurrency in FilmStudioCore

`Package.swift` pins `swiftLanguageModes: [.v6]`, and the FilmStudioCore
Xcode target sets `SWIFT_STRICT_CONCURRENCY: complete`. The contracts module
is where shared mutable-state reasoning lives, so it gets the strictest
compiler enforcement available. Every `@unchecked Sendable` opt-out must
carry an adjacent `// JUSTIFIED:` comment explaining the invariant that makes
it safe.
