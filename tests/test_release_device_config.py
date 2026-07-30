from __future__ import annotations

import csv
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "prepare-device-config.py"


def load_generator():
    spec = importlib.util.spec_from_file_location("prepare_device_config", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ReleaseDeviceConfigTests(unittest.TestCase):
    def test_private_header_becomes_versioned_nvs_image(self) -> None:
        generator = load_generator()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            header = root / "secrets.h"
            csv_path = root / "config.csv"
            image = root / "config.bin"
            header.write_text(
                "\n".join(
                    [
                        '#define VIBE_STICK_WIFI_SSID "Home WiFi"',
                        '#define VIBE_STICK_WIFI_PASSWORD "correct-horse"',
                        '#define VIBE_STICK_BRIDGE_HOST "192.168.1.20"',
                        '#define VIBE_STICK_BRIDGE_PORT 8765',
                        '#define VIBE_STICK_BRIDGE_TOKEN "' + "t" * 64 + '"',
                        '#define VIBE_STICK_DEPLOYMENT_NONCE "' + "n" * 36 + '"',
                        '#define VIBE_STICK_SPEAKER_VOLUME 65',
                    ]
                ),
                encoding="utf-8",
            )

            generator.write_csv(csv_path, generator.parse_header(header))
            with csv_path.open(encoding="utf-8") as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(rows[0], {"key": "vibe", "type": "namespace", "encoding": "", "value": ""})
            self.assertEqual(rows[1]["key"], "schema")
            self.assertEqual(rows[1]["value"], "1")
            self.assertEqual({row["key"] for row in rows[2:]}, {
                "wifi_ssid", "wifi_pass", "bridge_host", "bridge_port",
                "bridge_token", "deploy_nonce", "volume",
            })
            self.assertEqual(csv_path.stat().st_mode & 0o777, 0o600)

            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "esp_idf_nvs_partition_gen",
                    "generate",
                    str(csv_path),
                    str(image),
                    "0x6000",
                ],
                cwd=ROOT,
                env={"PYTHONPATH": str(ROOT / "tools" / "nvs")},
                text=True,
                capture_output=True,
                check=True,
            )
            self.assertEqual(image.stat().st_size, 0x6000)
            self.assertNotIn("correct-horse", result.stdout + result.stderr)

    def test_invalid_token_does_not_create_output(self) -> None:
        generator = load_generator()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            header = root / "secrets.h"
            output = root / "config.csv"
            header.write_text(
                '#define VIBE_STICK_WIFI_SSID "Home"\n'
                '#define VIBE_STICK_WIFI_PASSWORD "password"\n'
                '#define VIBE_STICK_BRIDGE_HOST "192.168.1.20"\n'
                '#define VIBE_STICK_BRIDGE_PORT 8765\n'
                '#define VIBE_STICK_BRIDGE_TOKEN "short"\n'
                '#define VIBE_STICK_DEPLOYMENT_NONCE "' + "n" * 36 + '"\n'
                '#define VIBE_STICK_SPEAKER_VOLUME 85\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "Bridge token"):
                generator.write_csv(output, generator.parse_header(header))
            self.assertFalse(output.exists())

    def test_non_hexadecimal_64_byte_wifi_password_does_not_create_output(self) -> None:
        generator = load_generator()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            header = root / "secrets.h"
            output = root / "config.csv"
            header.write_text(
                '#define VIBE_STICK_WIFI_SSID "Home"\n'
                '#define VIBE_STICK_WIFI_PASSWORD "' + "z" * 64 + '"\n'
                '#define VIBE_STICK_BRIDGE_HOST "192.168.1.20"\n'
                '#define VIBE_STICK_BRIDGE_PORT 8765\n'
                '#define VIBE_STICK_BRIDGE_TOKEN "' + "t" * 64 + '"\n'
                '#define VIBE_STICK_DEPLOYMENT_NONCE "' + "n" * 36 + '"\n'
                '#define VIBE_STICK_SPEAKER_VOLUME 85\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "Wi-Fi password"):
                generator.write_csv(output, generator.parse_header(header))
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
