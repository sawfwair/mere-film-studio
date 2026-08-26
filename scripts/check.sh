#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --strict --quiet --config "$repo_root/.swiftlint.yml"
fi

# Coverage is measured on every run so regressions are visible immediately;
# thresholds come later, once the baseline stabilizes.
swift test --package-path "$repo_root" --enable-code-coverage
print_core_coverage() {
  local profdata="$repo_root/.build/debug/codecov/default.profdata"
  local binary="$repo_root/.build/debug/MereFilmStudioPackageTests.xctest/Contents/MacOS/MereFilmStudioPackageTests"
  if [[ -f "$profdata" && -f "$binary" ]] && command -v xcrun >/dev/null 2>&1; then
    xcrun llvm-cov report "$binary" -instr-profile "$profdata" 2>/dev/null \
      | awk '/Sources\/FilmStudioCore\/.*\.swift$|^TOTAL/ {printf "%-60s %s lines\n", $1, $10}'
  fi
}
print_core_coverage

"$script_dir/generate-project.sh"
xcodebuild \
  -project "$repo_root/MereFilmStudio.xcodeproj" \
  -scheme MereFilmStudio \
  -configuration Debug \
  -derivedDataPath "$repo_root/.build/xcode-derived" \
  CODE_SIGNING_ALLOWED=NO \
  build
