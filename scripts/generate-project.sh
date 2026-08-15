#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

"$script_dir/bootstrap-ghostty.sh"
xcodegen generate --spec "$repo_root/project.yml" --project "$repo_root"
echo "Generated $repo_root/MereFilmStudio.xcodeproj"
