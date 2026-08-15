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
