#!/bin/zsh

# One-time activation of the repo's pre-commit hook: lint + unit tests on
# every commit, so broken states never enter history unnoticed.

set -euo pipefail
script_dir=${0:A:h}
repo_root=${script_dir:h}
git -C "$repo_root" config core.hooksPath "$repo_root/.githooks"
echo "Pre-commit hooks activated (core.hooksPath -> .githooks)."
