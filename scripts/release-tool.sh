#!/usr/bin/env sh
set -eu

root_dir="$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd)"
case "$(uname -m)" in
  arm64) tool="$root_dir/release/tools/esptool/arm64/esptool" ;;
  x86_64) tool="$root_dir/release/tools/esptool/x86_64/esptool" ;;
  *) printf '%s\n' "Unsupported Mac architecture: $(uname -m)" >&2; exit 20 ;;
esac
if [ ! -x "$tool" ] || [ -L "$tool" ]; then
  printf '%s\n' "The bundled ESP32-S3 flashing tool is missing or unsafe." >&2
  exit 20
fi
exec "$tool" "$@"
