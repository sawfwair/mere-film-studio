#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
pin_file="$repo_root/Vendor/ghostty-version.json"
destination="$repo_root/.build/dependencies/GhosttyKit.xcframework"
resource_destination="$repo_root/Generated/GhosttyResources"

commit=$(/usr/bin/plutil -extract commit raw -o - "$pin_file")
version=$(/usr/bin/plutil -extract version raw -o - "$pin_file")
zig_version=$(/usr/bin/plutil -extract zig raw -o - "$pin_file")

if [[ -f "$destination/Info.plist" && -d "$resource_destination/terminfo" && -d "$resource_destination/ghostty" ]]; then
  echo "GhosttyKit $version is already available at $destination"
  exit 0
fi

for command_name in git zig xcodebuild; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

checkout=$(mktemp -d "${TMPDIR:-/tmp}/mere-film-ghostty.XXXXXX")
trap 'rm -rf "$checkout"' EXIT

git -C "$checkout" init --quiet
git -C "$checkout" remote add origin https://github.com/ghostty-org/ghostty.git
git -C "$checkout" fetch --quiet --depth 1 origin "$commit"
git -C "$checkout" checkout --quiet --detach FETCH_HEAD

actual_commit=$(git -C "$checkout" rev-parse HEAD)
if [[ "$actual_commit" != "$commit" ]]; then
  echo "Ghostty checkout mismatch: expected $commit, got $actual_commit" >&2
  exit 1
fi

actual_zig=$(cd "$checkout" && zig version)
if [[ "$actual_zig" != "$zig_version" ]]; then
  echo "Ghostty $version requires Zig $zig_version; found $actual_zig." >&2
  echo "Install anyzig with Homebrew to select the pinned toolchain automatically." >&2
  exit 1
fi

echo "Building GhosttyKit $version ($commit) with Zig $actual_zig..."
(
  cd "$checkout"
  zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Demit-macos-app=false \
    --prefix "$checkout/zig-out" \
    --summary all
)

built="$checkout/macos/GhosttyKit.xcframework"
if [[ ! -f "$built/Info.plist" ]]; then
  echo "Ghostty build did not produce GhosttyKit.xcframework." >&2
  exit 1
fi

mkdir -p "$repo_root/.build/dependencies"
/usr/bin/ditto "$built" "$destination"
/usr/bin/ditto "$checkout/zig-out/share/terminfo" "$resource_destination/terminfo"
/usr/bin/ditto "$checkout/zig-out/share/ghostty" "$resource_destination/ghostty"
echo "Installed GhosttyKit at $destination"
