# FilmStudioCore

Typed contracts, project loading, process execution, and Animatic handoff
generation. This is the only module the UI trusts: all CLI stdout crosses a
typed boundary here or not at all.

## Entry points

- `FilmProjectLoader.load(runManifest:)` — reads a film workspace into a
  `FilmWorkspaceSnapshot`. Synchronous by design; callers move off-main.
- `FilmToolClient` — typed client for `mere-film-tools`. Long production
  commands are unbounded-but-cancellable (DECISIONS.md 008); everything else
  carries a fixed timeout.
- `ChildProcessRunner` — owns child processes; cancellation and timeouts
  deliver real SIGTERMs.
- `AnimaticHandoffBuilder` — builds and writes the checksum-verified handoff
  manifest consumed by Animatic.
- `PiExecutableResolver` — locates Pi on PATH or in mere.run-managed installs.

## What not to touch here

- No SwiftUI, AppKit, or UI imports. This module must stay headless so tests
  run fast (`./scripts/check-fast.sh`).
- Wire formats are load-bearing: unknown statuses/kinds decode lossily
  (`FilmVocabulary.swift`) and must round-trip byte-for-byte. Never fail a
  decode because the tools added vocabulary (DECISIONS.md 002, 010).

## Conventions

- Compare domain vocabulary only through `ArtifactKind` /
  `FilmContractStatus` / `FilmGate` cases — raw-string comparisons are lint
  errors.
- New architectural choices get a numbered entry in the repo-root
  `DECISIONS.md`.
