# AGENTS.md

Mere Film Studio is a macOS-native SwiftUI cockpit for the Pi-powered
`mere-film-tools` film engine.

## Boundaries

- The local film project directory is authoritative. Do not introduce a second
  mutable project database.
- Pi owns creative conversation and agent delegation.
- `mere-film-tools` owns gates, locking, jobs, resumability, hashes, and proof.
- The app may invoke only documented `mere-film-tools` and `animatic` commands.
- Keep stdout decoding typed and surface stderr as diagnostics.
- Never read or store Pi credentials.
- Never mutate another repository as part of an app build.

## Validation

```bash
./scripts/check.sh
```

This runs SwiftLint when available, executes Swift package tests, bootstraps the
exact pinned GhosttyKit build when necessary, generates the Xcode project, and
builds the native application.
