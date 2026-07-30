#!/usr/bin/env python3
"""Create a VibeStick NVS CSV without printing or persisting secret values elsewhere."""

from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path
import re


SCHEMA_VERSION = 1
DEFINE = re.compile(r"^\s*#define\s+([A-Z0-9_]+)\s+(.+?)\s*$")
FIELDS = {
    "VIBE_STICK_WIFI_SSID": ("wifi_ssid", "string"),
    "VIBE_STICK_WIFI_PASSWORD": ("wifi_pass", "string"),
    "VIBE_STICK_BRIDGE_HOST": ("bridge_host", "string"),
    "VIBE_STICK_BRIDGE_PORT": ("bridge_port", "u16"),
    "VIBE_STICK_BRIDGE_TOKEN": ("bridge_token", "string"),
    "VIBE_STICK_DEPLOYMENT_NONCE": ("deploy_nonce", "string"),
    "VIBE_STICK_SPEAKER_VOLUME": ("volume", "u8"),
}


def parse_header(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = DEFINE.match(line)
        if not match or match.group(1) not in FIELDS:
            continue
        key, literal = match.groups()
        if key in values:
            raise ValueError(f"duplicate configuration field: {key}")
        if literal.startswith('"'):
            value = json.loads(literal)
        else:
            value = str(int(literal, 10))
        values[key] = value
    missing = sorted(set(FIELDS) - set(values))
    if missing:
        raise ValueError("missing configuration fields: " + ", ".join(missing))
    validate(values)
    return values


def validate(values: dict[str, str]) -> None:
    ssid = values["VIBE_STICK_WIFI_SSID"]
    password = values["VIBE_STICK_WIFI_PASSWORD"]
    host = values["VIBE_STICK_BRIDGE_HOST"]
    token = values["VIBE_STICK_BRIDGE_TOKEN"]
    nonce = values["VIBE_STICK_DEPLOYMENT_NONCE"]
    port = int(values["VIBE_STICK_BRIDGE_PORT"])
    volume = int(values["VIBE_STICK_SPEAKER_VOLUME"])
    if not ssid or len(ssid.encode()) > 32:
        raise ValueError("Wi-Fi SSID must contain 1-32 UTF-8 bytes")
    password_bytes = password.encode()
    if not (
        8 <= len(password_bytes) <= 63
        or (
            len(password_bytes) == 64
            and all(character in "0123456789abcdefABCDEF" for character in password)
        )
    ):
        raise ValueError("Wi-Fi password must contain 8-63 bytes or be a 64-digit hexadecimal key")
    if not host or len(host.encode()) > 253:
        raise ValueError("Bridge host is invalid")
    if not 1 <= port <= 65535:
        raise ValueError("Bridge port is invalid")
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._~-")
    if not 32 <= len(token) <= 256 or not set(token) <= allowed:
        raise ValueError("Bridge token is invalid")
    if not 32 <= len(nonce) <= 128 or not set(nonce) <= allowed:
        raise ValueError("deployment nonce is invalid")
    if not 0 <= volume <= 100:
        raise ValueError("speaker volume is invalid")


def write_csv(path: Path, values: dict[str, str]) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(("key", "type", "encoding", "value"))
        writer.writerow(("vibe", "namespace", "", ""))
        writer.writerow(("schema", "data", "u16", SCHEMA_VERSION))
        for source, (target, encoding) in FIELDS.items():
            writer.writerow((target, "data", encoding, values[source]))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--header", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    write_csv(args.output, parse_header(args.header))
    print("Prepared private device configuration.")


if __name__ == "__main__":
    main()
