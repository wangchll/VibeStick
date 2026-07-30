#!/usr/bin/env sh
set -eu

root_dir="$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd)"
firmware="$root_dir/release/firmware"
app_bundle=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --app-bundle) shift; app_bundle="${1:-}" ;;
    *) printf '%s\n' "Usage: scripts/verify-release-assets.sh [--app-bundle /path/VibeStickSetup.app]" >&2; exit 2 ;;
  esac
  shift
done
if [ -n "$app_bundle" ]; then
  case "$app_bundle" in /*.app) ;; *) exit 2 ;; esac
  if [ ! -d "$app_bundle" ] || [ -L "$app_bundle" ]; then
    printf '%s\n' "The running installer bundle is unavailable or unsafe." >&2
    exit 1
  fi
  /usr/bin/codesign --verify --deep --strict "$app_bundle"
fi
if [ ! -f "$firmware/manifest.json" ] || [ ! -f "$firmware/manifest.sha256" ]; then
  printf '%s\n' "The installer does not contain a firmware manifest." >&2
  exit 1
fi
(cd "$firmware" && /usr/bin/shasum -a 256 --check manifest.sha256)

manifest="$firmware/manifest.json"
manifest_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$manifest"
}
expect_manifest_value() {
  actual="$(manifest_value "$1")"
  if [ "$actual" != "$2" ]; then
    printf '%s\n' "The firmware manifest has an invalid $1 value." >&2
    exit 1
  fi
}
expect_manifest_value schema 1
expect_manifest_value product VibeStick
expect_manifest_value chip esp32s3
expect_manifest_value flash_size 8MB
expect_manifest_value configuration.offset 0x610000
expect_manifest_value configuration.size 0x6000
expect_manifest_value configuration.schema 1

index=0
for expected in '0x0:bootloader.bin' '0x8000:partition-table.bin' '0x10000:vibestick.bin'; do
  expected_offset="${expected%%:*}"
  expected_path="${expected#*:}"
  expect_manifest_value "files.$index.offset" "$expected_offset"
  expect_manifest_value "files.$index.path" "$expected_path"
  file="$firmware/$expected_path"
  expected_hash="$(manifest_value "files.$index.sha256")"
  expected_size="$(manifest_value "files.$index.size")"
  actual_hash="$(/usr/bin/shasum -a 256 "$file" | /usr/bin/awk '{print $1}')"
  actual_size="$(/usr/bin/stat -f %z "$file")"
  if [ "$expected_hash" != "$actual_hash" ] || [ "$expected_size" != "$actual_size" ]; then
    printf '%s\n' "The firmware manifest does not match $expected_path." >&2
    exit 1
  fi
  index=$((index + 1))
done
if [ -n "$app_bundle" ]; then
  app_version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$app_bundle/Contents/Info.plist")"
  expect_manifest_value version "$app_version"
fi
(cd "$root_dir/release" && /usr/bin/shasum -a 256 --check assets.sha256)
"$root_dir/scripts/release-tool.sh" version >/dev/null
printf '%s\n' "Verified bundled firmware, flasher, and runtimes."
