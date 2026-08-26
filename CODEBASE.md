# Codebase map

- `App/` — SwiftUI application lifecycle and product views. One file per
  screen section (`*Section.swift`), shared components in
  `StudioComponents.swift`, design language in `StudioTheme.swift`. The
  `StudioModel` family owns all state and command execution:
  - `StudioModel.swift` — state, project open/close lifecycle
  - `StudioModel+Commands.swift` — film operations (approve, advance, review…)
  - `StudioModel+PiRoom.swift` — embedded Pi agent setup and terminal wiring
- `Sources/FilmStudioCore/` — typed film contracts, project loading, process
  execution, and Animatic handoff generation (see its README).
- `Sources/GhosttyBridge/` — narrow terminal adapter. Upstream Ghostty details
  must not escape this module (see its README).
- `Tests/FilmStudioCoreTests/` — contract, process-execution, resolution, and
  handoff tests; shared fixture under `Support/`.
- `Vendor/ghostty-version.json` — exact upstream source revision and integrity
  metadata.
- `scripts/` — reproducible project generation, Ghostty bootstrap, checks,
  pre-commit hook setup (`setup-hooks.sh`; fast loop: `check-fast.sh`,
  full CI-parity gate: `check.sh`).

The project directory containing `run.json` and `film-project.json` remains the
single source of truth. UI state is disposable and rehydrates from disk.

## Agent quick start

```bash
./scripts/check-fast.sh   # lint + unit tests (~30s) — run constantly
./scripts/check.sh        # full gate: + coverage report, Xcode build — run before finishing
```

Domain vocabulary (`FilmGate`, `ArtifactKind`, `FilmContractStatus`) lives in
`Sources/FilmStudioCore/FilmVocabulary.swift`; comparing raw strings instead
of these cases is a lint error.
