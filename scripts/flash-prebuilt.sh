#!/usr/bin/env sh
set -eu
umask 077

root_dir="$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd)"
port=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) shift; port="${1:-}" ;;
    *) printf '%s\n' "Usage: scripts/flash-prebuilt.sh --port /dev/cu.usbmodem..." >&2; exit 2 ;;
  esac
  shift
done
case "$port" in /dev/cu.*) ;; *) printf '%s\n' "A macOS callout serial port is required." >&2; exit 2 ;; esac
if [ ! -c "$port" ] || [ -L "$port" ]; then
  printf '%s\n' "The selected serial device is unavailable or unsafe." >&2
  exit 2
fi

firmware="$root_dir/release/firmware"
bootloader="$firmware/bootloader.bin"
partition="$firmware/partition-table.bin"
app="$firmware/vibestick.bin"
checksums="$firmware/manifest.sha256"
header="$root_dir/firmware/sticks3/include/vibe_stick_secrets.h"
for required in "$bootloader" "$partition" "$app" "$checksums" "$header"; do
  if [ ! -f "$required" ] || [ -L "$required" ]; then
    printf '%s\n' "A required signed release resource is missing or unsafe." >&2
    exit 1
  fi
done
(cd "$firmware" && /usr/bin/shasum -a 256 --check "$(basename "$checksums")")

case "$(uname -m)" in arm64) python_arch=aarch64 ;; x86_64) python_arch=x86_64 ;; *) exit 1 ;; esac
python="$HOME/.local/share/vibestick/python/cpython-3.12-macos-$python_arch-none/bin/python3.12"
if [ ! -x "$python" ]; then
  printf '%s\n' "The bundled VibeStick Python runtime is not installed." >&2
  exit 1
fi

temporary="$(mktemp -d "${TMPDIR:-/tmp}/vibestick-device-config.XXXXXX")"
cleanup() { rm -rf "$temporary"; }
trap cleanup EXIT HUP INT TERM
chmod 700 "$temporary"
csv="$temporary/config.csv"
image="$temporary/vibe-config.bin"
"$python" "$root_dir/scripts/prepare-device-config.py" --header "$header" --output "$csv"
PYTHONPATH="$root_dir/tools/nvs" "$python" -m esp_idf_nvs_partition_gen generate "$csv" "$image" 0x6000
chmod 600 "$image"

tool="$root_dir/scripts/release-tool.sh"
current_app="$temporary/current-app.bin"
current_partition="$temporary/current-partition.bin"
app_size="$(stat -f %z "$app")"
partition_size="$(stat -f %z "$partition")"
configuration_only=0
if "$tool" --chip esp32s3 --port "$port" --before no_reset --after no_reset --no-stub read_flash 0x10000 "$app_size" "$current_app" >/dev/null 2>&1 \
   && "$tool" --chip esp32s3 --port "$port" --before no_reset --after no_reset --no-stub read_flash 0x8000 "$partition_size" "$current_partition" >/dev/null 2>&1 \
   && [ "$(shasum -a 256 "$current_app" | awk '{print $1}')" = "$(shasum -a 256 "$app" | awk '{print $1}')" ] \
   && [ "$(shasum -a 256 "$current_partition" | awk '{print $1}')" = "$(shasum -a 256 "$partition" | awk '{print $1}')" ]; then
  configuration_only=1
fi

if [ "$configuration_only" -eq 1 ]; then
  printf '%s\n' "Firmware is current; writing device configuration only."
  "$tool" --chip esp32s3 --port "$port" --before no_reset --after no_reset \
    write_flash --flash_mode dio --flash_size 8MB --flash_freq 80m 0x610000 "$image"
else
  printf '%s\n' "Writing verified universal VibeStick firmware and private configuration."
  "$tool" --chip esp32s3 --port "$port" --before no_reset --after no_reset --no-stub erase_region 0xd000 0x2000
  "$tool" --chip esp32s3 --port "$port" --before no_reset --after no_reset \
    write_flash --flash_mode dio --flash_size 8MB --flash_freq 80m \
    0x0 "$bootloader" 0x8000 "$partition" 0x10000 "$app" 0x610000 "$image"
fi
