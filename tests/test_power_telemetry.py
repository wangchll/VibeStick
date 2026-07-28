import csv
import io
import tempfile
import unittest
from pathlib import Path

from vibe_stick.telemetry.power import PowerTelemetryStore


class PowerTelemetryTests(unittest.TestCase):
    def test_record_latest_and_csv(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PowerTelemetryStore(Path(directory) / "power.jsonl")
            sample = store.record(
                {
                    "uptime_ms": 1234,
                    "battery_mv": 3890,
                    "battery_percent": 72,
                    "charging": False,
                    "usb_powered": False,
                    "wifi_rssi": -58,
                },
                "0.2.15",
            )
            self.assertEqual(store.latest(), sample)
            rows = list(csv.DictReader(io.StringIO(store.csv_bytes().decode())))
            self.assertEqual(rows[0]["battery_mv"], "3890")
            self.assertEqual(rows[0]["wifi_rssi"], "-58")

    def test_invalid_sample_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = PowerTelemetryStore(Path(directory) / "power.jsonl")
            with self.assertRaises(ValueError):
                store.record(
                    {
                        "uptime_ms": 1,
                        "battery_mv": 9000,
                        "battery_percent": 50,
                        "charging": False,
                        "usb_powered": False,
                        "wifi_rssi": -50,
                    },
                    "test",
                )


if __name__ == "__main__":
    unittest.main()
