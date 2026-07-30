# VibeStick

[中文](README.md)

![VibeStick voice-input flow showing StickS3 recording states and the Mac HUD](assets/brand/voice-input-preview.png)

VibeStick turns an M5Stack StickS3 into a Codex desktop companion with task status, active-conversation count, the current usage window and reset countdown, alerts, speech transcription, and BMI270 spatial gestures for Codex controls.

VibeStick targets M5Stack StickS3 hardware and is not an official M5Stack project.

## Quick install

The macOS installer embeds its Python runtime, universal firmware, ESP32-S3 flasher, prebuilt Mac apps, and LaunchAgent payloads.

You need:

- macOS 14 or newer.
- An M5Stack StickS3 and a USB-C data cable.
- A 2.4 GHz Wi-Fi name and password.
- An optional ASR API key. [SiliconFlow](https://cloud.siliconflow.cn) is recommended; other OpenAI-compatible services are supported.

The current project version is **v0.3.11**. Apple Silicon users can download `VibeStickSetup-0.3.11-macOS-arm64.zip` from the [v0.3.11 GitHub Release](https://github.com/wangchll/VibeStick/releases/tag/v0.3.11); see the [installation guide](release/INSTALL.en.md) for the complete procedure and signing status. The installer embeds universal StickS3 firmware, ESP32-S3 flashing tools, Python runtimes, and prebuilt Mac apps. Consumer Macs do not need Xcode, Git, system Python, or ESP-IDF.

The v0.3.11 download is ad-hoc signed and has not been Apple-notarized, so first launch requires manual confirmation as described in the guide. Download the matching `.sha256` file from the Release to verify archive integrity.

You can also build it from source:

```sh
git clone https://github.com/wangchll/VibeStick.git
cd VibeStick
./script/build_and_run.sh
```

The installer opens automatically and remains at `dist/VibeStickSetup.app`. Only the release machine needs Xcode Command Line Tools and ESP-IDF; the generated installer contains everything required by a consumer Mac.

Setup has three steps:

1. Enter Wi-Fi details, adjust the StickS3 alert volume, and optionally configure and test an ASR API.
2. Connect the StickS3 and follow the prompt to enter install mode.
3. Confirm installation; the app verifies its bundled assets, creates private per-device configuration, flashes firmware, installs Mac services, and verifies connectivity.

Installation no longer downloads about 1 GB of ESP-IDF components. Keep the USB cable connected; only cloud ASR testing requires network access.

## Controls

- Choose cloud API, local Whisper, or WeChat Input from the menu-bar “语音识别模式” menu. All three modes remain available.
- Hold the front blue button to speak; release it to finish the selected input mode. WeChat mode streams from press-down and holds WeChat Input's default Fn shortcut without changing its settings.
- When Codex is idle and no pasted voice draft is pending, single-click the blue button to raise Codex and focus its composer.
- For 30 seconds after a successful recording, single-click the blue button to send the current draft.
- For 30 seconds after a successful recording, double-click the blue button to pause the current Codex task.
- Single-click the large right-side button to show Roxy and allow a real pending Codex approval. Double-click it to return to the dashboard and reject a pending approval.
- After enabling Spatial Gestures in the menu bar, press the front and side buttons together to open a recognition window. StickS3 plays a cue and displays `识别中` until recognition ends.
- Inside that window, tap StickS3 twice to toggle Planning mode, tap three times to toggle Fast mode, or shake it continuously to create a new task. Every mapping can be changed or disabled in Spatial Gesture Settings.
- Alert volume is adjustable from 0–100% and can be updated through the device configuration without rebuilding firmware.
- Reopen the latest installer to change Wi-Fi, alert-volume, or voice settings, or to reflash. The installer is the supported path for both Mac updates and firmware flashing.

Bridge and HUD start automatically at login. The Mac and StickS3 must be on the same LAN.

## Spatial gestures

Spatial gestures are off by default. To prevent accidental triggers while walking or carrying StickS3, the BMI270 does not recognise motion continuously. Pressing the front and side buttons together opens one configurable 3–6 second window, and each window executes at most one action.

| Gesture | Default Codex action | Default macOS shortcut |
| --- | --- | --- |
| Tap StickS3 twice | Toggle Planning mode | `Control+Shift+1` |
| Tap StickS3 three times | Toggle Fast mode | `Control+Shift+3` |
| Shake StickS3 continuously | Create a new task | `Command+N` |

The first two defaults mirror this Mac's `~/.codex/keybindings.json`. The settings window accepts `default`, `disabled`, or a custom macOS shortcut made from Command, Control, Option, and Shift.

For power efficiency, both BMI270 motion sensors remain disabled at idle. The chord enables only the 100 Hz accelerometer; recognition, timeout, recording start, or disabling the feature powers it down again. None of the three current gestures requires the gyroscope.

## Troubleshooting

- **Device not detected**: use a USB-C data cable, reconnect it, and follow the install-mode prompt.
- **Wi-Fi does not connect**: StickS3 supports 2.4 GHz Wi-Fi only.
- **ASR API test fails**: check the API URL, key, model, and network.
- **Transcription works but paste does not**: grant Microphone and Accessibility access in System Settings → Privacy & Security.
- **WeChat Input does not appear**: select WeChat Input as the current input source, keep focus in the destination text field, and install `BlackHole 2ch`; see [WeChat Input](docs/WECHAT_INPUT.md).
- **Spatial gestures do not respond**: enable them in the menu bar, press the front and side buttons together, then perform the gesture only after the cue and `识别中` status appear.
- **Spatial Gesture Settings does not open**: confirm that the menu-bar app came from the latest installer; the current window is presented after the menu closes and brought to the front.
- **Installation was interrupted**: keep the cable connected and run the installer again.

## Uninstall Mac services

```sh
./scripts/uninstall.sh
```

Add `--purge` to also remove configuration, logs, and runtime data from `~/Library/Application Support/VibeStick/`.

## Developer documentation

- [Build, test, and package the macOS installer](app/macos/README.md)
- [Hardware and firmware](docs/HARDWARE.md)
- [Architecture](docs/ARCHITECTURE.md) and [protocol](docs/PROTOCOL.md)
- [WeChat Input streaming](docs/WECHAT_INPUT.md)
- [Environment-variable reference](.env.example)
- [Contributing](CONTRIBUTING.md) and [security reporting](SECURITY.md)

Never commit real API keys, Wi-Fi passwords, local tokens, recordings, or logs.

## Current limits

- M5Stack StickS3 and macOS 14 or newer only.
- The installer is not yet distributed as a notarized DMG.
- StickS3 uses plain HTTP to reach Bridge. Use it only on a trusted LAN and do not expose port `8765` to the internet.
- Codex usage is inferred from local session data, not an official quota API.
- Audio leaves the Mac when cloud transcription is enabled.

## License

VibeStick is released under the [MIT License](LICENSE).

Roxy is a Codex custom pet created for this project. The repository and installer contain only the generated, compressed StickS3 firmware assets, not the original local Codex atlas.
