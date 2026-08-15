# Codebase map

- `App/` — SwiftUI application lifecycle and product views.
- `Sources/FilmStudioCore/` — typed film contracts, project loading, command
  execution, and Animatic handoff generation.
- `Sources/GhosttyBridge/` — narrow terminal adapter. Upstream Ghostty details
  must not escape this module.
- `Tests/FilmStudioCoreTests/` — contract, command, and handoff tests.
- `Vendor/ghostty-version.json` — exact upstream source revision and integrity
  metadata.
- `scripts/` — reproducible project generation, Ghostty bootstrap, and checks.

The project directory containing `run.json` and `film-project.json` remains the
single source of truth. UI state is disposable and rehydrates from disk.
