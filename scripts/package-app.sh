#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
release_root="$repo_root/.build/release"
derived_data="$repo_root/.build/xcode-release"
app_source="$derived_data/Build/Products/Release/Mere Film Studio.app"
app_destination="$release_root/Mere Film Studio.app"
dmg_destination="$release_root/Mere-Film-Studio-0.1.0.dmg"

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
/usr/bin/codesign --force --deep --sign - --timestamp=none "$app_destination"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_destination"

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

echo "$app_destination"
echo "$dmg_destination"
