#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --strict --quiet --config "$repo_root/.swiftlint.yml"
fi

swift test --package-path "$repo_root"
"$script_dir/generate-project.sh"
xcodebuild \
  -project "$repo_root/MereFilmStudio.xcodeproj" \
  -scheme MereFilmStudio \
  -configuration Debug \
  -derivedDataPath "$repo_root/.build/xcode-derived" \
  CODE_SIGNING_ALLOWED=NO \
  build
