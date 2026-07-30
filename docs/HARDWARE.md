# Hardware

## Supported Device

VibeStick v0.3.11 targets M5Stack StickS3.

The project does not currently claim support for other devices because the UI layout, front button behavior, microphone path, speaker path, PMIC battery reads, and screen size are all written around StickS3.

## Hardware Used

- Screen: LVGL UI on the StickS3 display.
- Blue front button (`KEY1`, GPIO 11): long press records push-to-talk audio until release. With no pending draft, a standby single click raises Codex and focuses its composer. After a successful recording, single click sends the focused draft and double click stops the current Codex turn for up to 30 seconds.
- Large right-side button (`KEY2`, GPIO 12): single click shows Roxy and allows a pending approval; double click shows the dashboard and rejects a pending approval; a 700 ms long press clears the latest pasted voice draft.
- Corner power button: device power and firmware download-mode control; it is not an application input and is distinct from `KEY2`.
- Microphone: StickS3 microphone captured as 16 kHz / 16-bit / mono PCM.
- Speaker: ES8311 / I2S playback for generated agent status tones.
- Wi-Fi: HTTP communication with the Mac bridge on a 2.4 GHz Wi-Fi network. StickS3 / ESP32-S3 does not support 5 GHz Wi-Fi.
- USB-C: flashing and serial monitor.
- Battery / USB power: local PMIC reads for the battery UI.
- IMU: BMI270 direct-motion recognition. Both motion sensors remain disabled outside a recognition window. Pressing the blue front button and large side button together powers the accelerometer at 100 Hz, opens one recognition window, and consumes that chord; recognition, timeout, recording start, or feature disable powers it down again. Inside the window, the supported actions are two firm enclosure taps, three firm enclosure taps, and a fast continuous shake. The gyroscope is not enabled by this feature.

VibeStick reads BMI270 acceleration at 100 Hz and derives tap and shake events from short acceleration changes. This does not depend on a left/right wrist orientation.
- Deep sleep: after five minutes of battery-powered inactivity when no observed Codex task is active; the front button wakes the device through ESP32-S3 GPIO11. USB power, charging, and completion watch block deep sleep.
- Runtime power management: dynamic 40–240 MHz CPU frequency, with automatic light sleep only after the LCD is fully off. During completion watch, the screen remains off, Wi-Fi stays in modem-sleep mode, state and PMIC polling slow to 30 seconds, and standalone power telemetry slows to 5 minutes.

## Firmware Release Configuration

Normal installation uses the universal firmware embedded in `VibeStickSetup.app`. Wi-Fi, Bridge address/token, deployment nonce, and speaker volume are stored at runtime in the dedicated `vibe_cfg` NVS partition. They are not compiled into the application binary. ASR API keys never enter device flash.

The installer keeps its private `vibe_stick_secrets.h` as a local persistence format, converts it to a temporary 24 KB NVS image, flashes that image at `0x610000`, and deletes the temporary CSV/image on every exit. Reconfiguring a device running the identical firmware writes only this configuration partition.

## Firmware Development

Only release developers need ESP-IDF v5.5.x. Follow Espressif's [ESP-IDF v5.5.1 ESP32-S3 guide](https://docs.espressif.com/projects/esp-idf/en/v5.5.1/esp32s3/get-started/index.html), or use:

```sh
mkdir -p ~/esp && cd ~/esp
git clone -b v5.5.1 --recursive https://github.com/espressif/esp-idf.git
cd esp-idf && ./install.sh esp32s3
```

The public 8 MB partition layout uses default NVS at `0x9000`, OTA metadata at `0xd000`, two 3 MB app slots at `0x10000` and `0x310000`, and device configuration at `0x610000`. v0.3.11 still updates over USB, but reserving both app slots avoids another partition migration when signed OTA and rollback are implemented.

The Wi-Fi network must be 2.4 GHz. If the SSID is a combined 2.4/5 GHz network and the StickS3 cannot connect, create or select a dedicated 2.4 GHz SSID.

## Roxy Animation Assets

The firmware uses a 96 x 104 device adaptation of the local Codex custom pet at `~/.codex/pets/roxy-pixel/spritesheet.webp`. It includes idle, running, approval, done, and error animations. Frames use a shared 31-color palette and a small PackBits-style codec, then decode into a 20 KB RGB565 buffer in PSRAM.

To regenerate the checked-in C assets and deterministic QA previews:

```sh
python3 firmware/sticks3/tools/generate_roxy_assets.py --qa-dir /tmp/vibestick-roxy-qa
```

The generator validates the canonical atlas dimensions and SHA-256 before writing `firmware/sticks3/generated/vibe_roxy_assets.c` and `.h`. The original local Codex atlas is not checked into the repository or bundled by the installer.

## Flashing

Developers can load ESP-IDF into a terminal for diagnostics:

```sh
. $HOME/esp/esp-idf/export.sh
```

Adjust the path if ESP-IDF is installed elsewhere. If you see `command not found: idf.py`, this shell has not loaded ESP-IDF yet.

For development diagnostics, from the firmware directory:

```sh
cd firmware/sticks3
idf.py build flash monitor
```

Formal installation and firmware updates must use the current `VibeStickSetup.app`; direct flashing does not count as a delivered installation.

If automatic flashing fails, put the StickS3 into download mode and retry:

1. Plug the StickS3 into the Mac with a USB-C data cable.
2. Long-press the side power button until the blue LED double-blinks and the screen turns off.
3. Run `ls /dev/cu.*` to find the serial port.
4. Retry from VibeStick Setup. A direct `idf.py` flash remains a development diagnostic and does not write the required per-device configuration partition.
5. After flashing, short-press the power button to wake the screen. The blue LED should turn off and the VibeStick home screen should appear.

## Runtime Network

The StickS3 talks to the Mac bridge by HTTP. The Mac bridge should listen on `0.0.0.0:8765` when the device is on the same Wi-Fi network.

Use only a private, trusted LAN. HTTP does not encrypt the shared Bridge token sent with protected requests; do not expose port `8765` to the internet. The universal application binary contains no user credentials, but the separate device configuration partition contains the configured Wi-Fi password and Bridge token. If a device is lost, rotate both credentials and reconfigure it.
