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

# Plain zig answers `zig version`; the anyzig shim needs the version spelled
# out because there is no build.zig at the repo root to infer it from.
zig_cmd=(zig)
if ! actual_zig=$(zig version 2>/dev/null); then
  actual_zig=""
fi
if [[ "$actual_zig" != "$zig_version" ]]; then
  if actual_zig=$(zig "$zig_version" version 2>/dev/null) && [[ "$actual_zig" == "$zig_version" ]]; then
    zig_cmd=(zig "$zig_version")
  else
    echo "Ghostty $version requires Zig $zig_version; found ${actual_zig:-none}." >&2
    echo "Install anyzig with Homebrew to select the pinned toolchain automatically." >&2
    exit 1
  fi
fi

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

echo "Building GhosttyKit $version ($commit) with Zig $actual_zig..."
# Run from inside the checkout: Ghostty's xcframework step emits to a path
# relative to the process working directory, not the build root.
(
  cd "$checkout"
  "${zig_cmd[@]}" build -Doptimize=ReleaseFast -Demit-xcframework=true -Demit-macos-app=false \
    --prefix "$checkout/zig-out" \
    --summary all
)

# The emit location has moved between Ghostty revisions (zig-out/ vs the
# macos/ source tree), so locate it instead of assuming.
built=""
for candidate in "$checkout/zig-out/GhosttyKit.xcframework" "$checkout/macos/GhosttyKit.xcframework"; do
  if [[ -f "$candidate/Info.plist" ]]; then
    built="$candidate"
    break
  fi
done
if [[ -z "$built" ]]; then
  built=$(find "$checkout" -maxdepth 3 -type d -name GhosttyKit.xcframework 2>/dev/null | head -n 1)
fi
if [[ -z "$built" || ! -f "$built/Info.plist" ]]; then
  echo "Ghostty build did not produce GhosttyKit.xcframework." >&2
  exit 1
fi

mkdir -p "$repo_root/.build/dependencies"
/usr/bin/ditto "$built" "$destination"
/usr/bin/ditto "$checkout/zig-out/share/terminfo" "$resource_destination/terminfo"
/usr/bin/ditto "$checkout/zig-out/share/ghostty" "$resource_destination/ghostty"
echo "Installed GhosttyKit at $destination"
