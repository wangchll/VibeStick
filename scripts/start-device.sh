#!/usr/bin/env sh
set -eu

root_dir="$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd)"
port=""
while [ "$#" -gt 0 ]; do
  case "$1" in --port) shift; port="${1:-}" ;; *) exit 2 ;; esac
  shift
done
case "$port" in /dev/cu.*|/dev/tty.*) ;; *) exit 2 ;; esac
if [ ! -c "$port" ] || [ -L "$port" ]; then exit 1; fi

# Clear ESP32-S3's USB-Serial/JTAG force-download latch, then let esptool
# perform a normal reset with GPIO0 released.
"$root_dir/scripts/release-tool.sh" --chip esp32s3 --port "$port" \
  --before no_reset --after hard_reset --no-stub write_mem 0x6000812c 0x0 0x1
