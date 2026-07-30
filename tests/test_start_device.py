from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class StartDeviceScriptTests(unittest.TestCase):
    def test_releases_esp32s3_from_native_usb_download_mode(self) -> None:
        script = (PROJECT_ROOT / "scripts/start-device.sh").read_text(encoding="utf-8")

        self.assertIn('"$root_dir/scripts/release-tool.sh"', script)
        self.assertIn("--before no_reset", script)
        self.assertIn("--after hard_reset", script)
        self.assertIn("--no-stub", script)
        self.assertIn("write_mem 0x6000812c 0x0 0x1", script)
        self.assertNotIn("idf.py", script)
        self.assertNotIn("python", script.lower())


if __name__ == "__main__":
    unittest.main()
