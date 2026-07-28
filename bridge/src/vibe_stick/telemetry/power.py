from __future__ import annotations

import csv
import io
import json
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from vibe_stick.config.storage import ensure_private_dir, ensure_private_file

MAX_JOURNAL_BYTES = 5 * 1024 * 1024
FIELDS = (
    "received_at", "firmware_version", "uptime_ms", "battery_mv",
    "battery_percent", "charging", "usb_powered", "wifi_rssi",
)


class PowerTelemetryStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        ensure_private_dir(path.parent)
        ensure_private_file(path)

    def record(self, payload: dict[str, Any], firmware_version: str) -> dict[str, Any]:
        sample = {
            "received_at": datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
            "firmware_version": firmware_version[:32],
            "uptime_ms": _bounded_int(payload.get("uptime_ms"), 0, 2**63 - 1),
            "battery_mv": _bounded_int(payload.get("battery_mv"), 2500, 5000),
            "battery_percent": _bounded_int(payload.get("battery_percent"), 0, 100),
            "charging": _required_bool(payload.get("charging")),
            "usb_powered": _required_bool(payload.get("usb_powered")),
            "wifi_rssi": _bounded_int(payload.get("wifi_rssi"), -127, 0),
        }
        with self._lock:
            if self.path.exists() and self.path.stat().st_size >= MAX_JOURNAL_BYTES:
                self.path.replace(self.path.with_suffix(".previous.jsonl"))
            with self.path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(sample, separators=(",", ":")) + "\n")
        return sample

    def latest(self) -> dict[str, Any] | None:
        with self._lock:
            try:
                lines = self.path.read_text(encoding="utf-8").splitlines()
            except OSError:
                return None
        for line in reversed(lines):
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict):
                return value
        return None

    def csv_bytes(self) -> bytes:
        output = io.StringIO(newline="")
        writer = csv.DictWriter(output, fieldnames=FIELDS)
        writer.writeheader()
        with self._lock:
            try:
                lines = self.path.read_text(encoding="utf-8").splitlines()
            except OSError:
                lines = []
        for line in lines:
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict):
                writer.writerow({field: value.get(field, "") for field in FIELDS})
        return output.getvalue().encode("utf-8")


def _bounded_int(value: Any, minimum: int, maximum: int) -> int:
    if isinstance(value, bool):
        raise ValueError("telemetry integer field cannot be boolean")
    number = int(value)
    if number < minimum or number > maximum:
        raise ValueError("telemetry integer field out of range")
    return number


def _required_bool(value: Any) -> bool:
    if not isinstance(value, bool):
        raise ValueError("telemetry boolean field is required")
    return value
