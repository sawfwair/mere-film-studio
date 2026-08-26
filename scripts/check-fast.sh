#!/bin/zsh

# Fast agent feedback loop: lint plus unit tests only. No code generation,
# no Xcode build, no bootstrapping — target is well under a minute.
# Use ./scripts/check.sh for the full gate (CI parity) before finishing work.

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --strict --quiet --config "$repo_root/.swiftlint.yml"
fi

swift test --package-path "$repo_root"
