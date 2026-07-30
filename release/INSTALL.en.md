# VibeStick v0.3.11 Installation

## Download

Download `VibeStickSetup-0.3.11-macOS-arm64.zip`. It supports Apple Silicon Macs (M1 or newer) running macOS 14 or later.

The installer includes:

- VibeStick v0.3.11 universal StickS3 firmware, partition table, and bootloader;
- arm64 and x86_64 ESP32-S3 flashing tools;
- arm64 and x86_64 Python 3.12 runtimes;
- prebuilt VibeStick Bridge, HUD, and menu-bar components;
- firmware manifests, SHA-256 checks, and the per-device configuration generator.

Consumer Macs do not need Xcode, Git, Python, or ESP-IDF.

## Requirements

- An Apple Silicon Mac running macOS 14 or later;
- an M5Stack StickS3;
- a USB-C data cable;
- a 2.4 GHz Wi-Fi name and password;
- an optional cloud transcription API key.

## Installation

1. Download the ZIP and its matching `.sha256` file. You may verify it from the download directory with:

   ```sh
   shasum -a 256 -c VibeStickSetup-0.3.11-macOS-arm64.zip.sha256
   ```

2. Extract the ZIP and drag `VibeStickSetup.app` into Applications.
3. On first launch, Control-click the installer and choose Open. If macOS still blocks it, open System Settings → Privacy & Security, verify that the app came from this project, and choose Open Anyway.
4. Enter Wi-Fi details, alert volume, and optional voice-service settings.
5. Connect StickS3 with a USB-C data cable and follow the installer prompt to enter download mode.
6. Confirm installation. The installer verifies its assets, generates private per-device configuration, flashes StickS3, installs the Mac services, and waits for the device to reconnect.
7. When prompted on first use, grant VibeStick Microphone and Accessibility access for speech and physical-button controls.

Do not disconnect the USB cable during installation or flashing. The Mac and StickS3 must use the same trusted LAN.

## Updates and reconfiguration

Run the newer installer again to update Mac components and firmware. It preserves the existing `.env` and device secrets. Use the same installer when changing Wi-Fi, volume, or voice-service settings.

Do not hand-copy Bridge files or use bare `idf.py flash` as a supported update method.

## Signing status

The v0.3.11 download is an ad-hoc signed build from the project's current release machine. It has not been notarized with an Apple Developer ID, so first launch requires manual confirmation. It is not an Apple-notarized DMG; download it only from this project's GitHub Release.

## Troubleshooting

- **Universal firmware verification fails**: download the complete ZIP again, verify SHA-256, and extract a fresh copy. Do not modify files inside the `.app` bundle.
- **StickS3 is not detected**: use a data-capable cable, reconnect it, and follow the download-mode prompt exactly.
- **StickS3 cannot join Wi-Fi**: it supports 2.4 GHz Wi-Fi only and must share a LAN with the Mac.
- **Buttons do not control ChatGPT**: install the same Mac-component version and grant Accessibility access in System Settings.
- **Speech transcribes but does not paste**: grant both Microphone and Accessibility permissions.

Project and issue tracker: <https://github.com/wangchll/VibeStick>
