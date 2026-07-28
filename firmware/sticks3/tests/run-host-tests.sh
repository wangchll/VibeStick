#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_BIN="${TMPDIR:-/tmp}/vibestick-power-policy-test"

cc -std=c11 -Wall -Wextra -Werror \
  -I"$ROOT_DIR/include" \
  "$ROOT_DIR/src/vibe_power_policy.c" \
  "$ROOT_DIR/tests/test_vibe_power_policy.c" \
  -o "$TEST_BIN"
"$TEST_BIN"
