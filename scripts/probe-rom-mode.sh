#!/usr/bin/env sh
set -eu

# Stable result codes consumed by the macOS installer:
#   0  ESP32-S3 ROM downloader is ready
#   10 device is running normal firmware / did not answer ROM sync
#   11 connected ROM is not an ESP32-S3
#   13 serial port is busy or permission was denied
#   14 device disappeared or its USB identity changed
#   15 secure-download mode is enabled
#   20 invalid invocation or unexpected probe failure

serial_port=""
expected_serial=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) shift; serial_port="${1:-}" ;;
    --serial) shift; expected_serial="${1:-}" ;;
    *) printf '%s\n' "Usage: scripts/probe-rom-mode.sh --port /dev/cu.usbmodem... --serial USB_SERIAL" >&2; exit 20 ;;
  esac
  shift
done
case "$serial_port" in /dev/cu.*) ;; *) exit 14 ;; esac
if [ ! -c "$serial_port" ] || [ -L "$serial_port" ]; then exit 14; fi
if [ -z "$expected_serial" ]; then exit 20; fi

root_dir="$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd)"
output="$(mktemp "${TMPDIR:-/tmp}/vibestick-rom-probe.XXXXXX")"
trap 'rm -f "$output"' EXIT HUP INT TERM
set +e
"$root_dir/scripts/release-tool.sh" --chip esp32s3 --port "$serial_port" \
  --before no_reset --after no_reset --no-stub chip_id >"$output" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ] && grep -q "ESP32-S3" "$output"; then exit 0; fi
if grep -qi "secure download" "$output"; then exit 15; fi
if grep -Eqi "resource busy|permission denied|access is denied" "$output"; then exit 13; fi
if grep -Eqi "no such file|doesn't exist|disconnected" "$output"; then exit 14; fi
if grep -Eqi "wrong chip|not ESP32-S3" "$output"; then exit 11; fi
if grep -Eqi "failed to connect|no serial data received|packet header" "$output"; then exit 10; fi
exit 20
