#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
release_root="$repo_root/.build/release"
derived_data="$repo_root/.build/xcode-release"
app_source="$derived_data/Build/Products/Release/Mere Film Studio.app"
app_destination="$release_root/Mere Film Studio.app"
release_version="${RELEASE_VERSION:-0.1.0}"
dmg_destination="${DMG_PATH:-$release_root/Mere-Film-Studio-$release_version.dmg}"
sign_identity="${SIGN_IDENTITY:--}"
notarize="${NOTARIZE:-0}"
release_tools_root="${RELEASE_TOOLS_ROOT:-$repo_root/../mere-run-release-tools}"

sign_target() {
  local target="$1"
  local -a sign_args=(--force --sign "$sign_identity")

  if [[ "$sign_identity" == "-" ]]; then
    sign_args+=(--timestamp=none)
  else
    sign_args+=(--options runtime --timestamp)
  fi

  /usr/bin/codesign "${sign_args[@]}" "$target"
}

notarize_target() {
  local target="$1"
  local kind="$2"
  local notarize_script="$release_tools_root/scripts/notarize.sh"

  if [[ ! -x "$notarize_script" ]]; then
    echo "Notarization script not found or not executable: $notarize_script" >&2
    exit 1
  fi

  NOTARIZE_TARGET_PATH="$target" \
    NOTARIZE_TARGET_KIND="$kind" \
    "$notarize_script"
}

if [[ "$notarize" == "1" && "$sign_identity" == "-" ]]; then
  echo "NOTARIZE=1 requires a Developer ID SIGN_IDENTITY." >&2
  exit 64
fi

if [[ "$sign_identity" != "-" ]]; then
  identity_matches=$(
    /usr/bin/security find-identity -v -p codesigning \
      | { /usr/bin/grep -F -- "$sign_identity" || true; } \
      | /usr/bin/wc -l \
      | /usr/bin/tr -d '[:space:]'
  )
  if [[ "$identity_matches" != "1" ]]; then
    echo "SIGN_IDENTITY must match exactly one valid code-signing identity; found $identity_matches." >&2
    exit 1
  fi
fi

"$script_dir/generate-project.sh"
xcodebuild \
  -project "$repo_root/MereFilmStudio.xcodeproj" \
  -scheme MereFilmStudio \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$release_root"
rm -rf "$app_destination"
/usr/bin/ditto "$app_source" "$app_destination"

if [[ -d "$app_destination/Contents/Frameworks" ]]; then
  while IFS= read -r framework; do
    sign_target "$framework"
  done < <(/usr/bin/find "$app_destination/Contents/Frameworks" -type d -name '*.framework' -prune | /usr/bin/sort)
fi
sign_target "$app_destination"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_destination"

if [[ "$notarize" == "1" ]]; then
  notarize_target "$app_destination" app
fi

staging=$(mktemp -d "${TMPDIR:-/tmp}/mere-film-studio-package.XXXXXX")
trap 'rm -rf "$staging"' EXIT
/usr/bin/ditto "$app_destination" "$staging/Mere Film Studio.app"
/bin/ln -s /Applications "$staging/Applications"
rm -f "$dmg_destination"
/usr/bin/hdiutil create \
  -volname "Mere Film Studio" \
  -srcfolder "$staging" \
  -ov \
  -format UDZO \
  "$dmg_destination"

sign_target "$dmg_destination"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$dmg_destination"

if [[ "$notarize" == "1" ]]; then
  notarize_target "$dmg_destination" dmg
fi

echo "$app_destination"
echo "$dmg_destination"
/usr/bin/shasum -a 256 "$dmg_destination"
