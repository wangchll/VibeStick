# Changelog

## v0.3.0

- Release configurable BMI270 spatial gestures activated by the front-plus-side button chord: double tap toggles Planning mode, triple tap toggles Fast mode, and shake creates a task.
- Add persistent macOS gesture enable, sensitivity, window-length, and shortcut-mapping controls, including a reliable settings-window presentation path.
- Keep `识别中` visible for the complete recognition window with dedicated activation and recognition sounds.
- Disable both BMI270 motion sensors outside the explicit recognition window and use only the accelerometer for the current gestures.
- Expand the Chinese and English README with setup, mappings, power behaviour, and troubleshooting guidance.

## v0.2.32

- Keep both BMI270 motion sensors disabled while no spatial-gesture window is active.
- Power the 100 Hz accelerometer only after the front-plus-side button chord, wait for its output to settle, and power it down immediately after recognition, timeout, recording start, or gesture disable.
- Retry accelerometer power-down after an I2C failure so a transient bus error cannot leave the sensor running indefinitely.

## v0.2.31

- Restore front-button plus side-button activation for spatial gestures; the chord is consumed and opens one configurable recognition window.
- Recognise double tap, triple tap, or shake only inside that window, with at most one action per activation.
- Keep the StickS3 status text at `识别中` throughout the active window and restore normal state when the window expires.
- Confirm that all three Chinese glyphs used by `识别中` are present in the embedded LVGL font.

## v0.2.30

- Replace the wrist-only BMI270 classifier and button-chord activation with direct two-tap, three-tap, and shake recognition on the StickS3 enclosure.
- Map double tap to this Mac's Codex Planning-mode shortcut (`Control-Shift-1`), triple tap to its Fast-mode shortcut (`Control-Shift-@`), and shake to new task (`Command-N`); all remain editable.
- Restore normal physical-button behavior and make gesture recognition inactive during recording or when disabled.
- Fix intermittent menu-bar settings presentation by opening the persistent settings window after the status menu closes and explicitly bringing the accessory app forward.

## v0.2.29

- Replace the hand-written acceleration and gyroscope threshold classifier with Bosch's official BMI270 Base wrist-gesture feature engine.
- Expose the five native results—arm down, arm up/pivot, shake/jiggle, flick in, and flick out—through the firmware protocol and customizable macOS mappings.
- Keep the front-plus-right button chord and one-action event window, discarding feature events generated before each explicit activation.
- Show the recognized Bosch action on StickS3 and play a separate confirmation tone, making physical gesture testing observable even when a shortcut has no default mapping.
- Map arm down to the Codex model picker and inward/outward wrist flicks to previous/next Codex tabs by default; leave the less deliberate arm-up and shake gestures unassigned.
- Bundle the BSD-licensed Bosch SensorAPI source with the self-contained installer so firmware builds do not depend on a second, conflicting I²C driver.

## v0.2.28

- Update the macOS spatial-gesture settings instructions to describe the front-plus-right button chord and its consumed button actions.
- Remove the remaining obsolete enclosure double-tap instruction from the current hardware documentation.

## v0.2.27

- Replace enclosure double-tap gesture activation with a reliable front-plus-right button chord.
- Consume both buttons for the chord so it cannot also start recording, change views, or submit an approval action.
- Stop BMI270 high-rate sampling outside the armed gesture window to reduce idle power use.

## v0.2.26

- Display `启动手势` with the required Chinese glyphs when the double-tap window opens, replacing unsupported Latin glyph boxes.
- Play a distinct rising two-tone sound when gesture recognition is armed.
- Fix an impossible conservative tilt condition, shorten the stable-tilt confirmation, require transient jerk for push/pull, and detect shake rotation on the dominant gyro axis.
- Document the Bosch BMI270 base wrist actions and the separate Legacy tap feature set used by the official SensorAPI.

## v0.2.25

- Fix StickS3 BMI270 initialization by using the board's official primary I2C address `0x68` instead of the unconnected alternate address `0x69`.
- Align the firmware with the M5Stack StickS3 schematic, official IMU example, and the Espressif BMI270 driver's own example configuration.

## v0.2.24

- Fix double-tap arming by detecting both acceleration impulse and sample-to-sample impact change instead of relying only on deviation from 1 g.
- Relax the pre-tap stability and impact angular-rate gates while retaining a stable hold, a bounded two-tap interval, latch release, and cooldown protections.
- Expand the deliberate double-tap interval to 120–650 ms and tune all three sensitivity levels for taps on the StickS3 enclosure.

## v0.2.23

- Replace gesture defaults with verified macOS Codex shortcuts: push opens the model picker, while left/right tilt changes Codex tabs.
- Keep pull-back and shake disabled by default because they are less reliable during handheld movement, while retaining custom mappings.
- Remove gesture actions already covered by StickS3 buttons, including approval, draft submission/clearing, and stopping a task.
- Show macOS modifier names and key symbols in gesture settings instead of Windows-looking shortcut notation.

## v0.2.22

- Add a native menu-bar gesture settings window with global enable, three sensitivity levels, configurable 3–6 second windows, per-gesture disable, and safe custom Codex keyboard shortcuts.
- Add left/right tilt gestures with default previous/next Codex task shortcuts, plus visible `GESTURE READY` and timeout feedback on StickS3.
- Validate custom mappings as structured modifier/key combinations and reject scripts, unmodified text, unknown keys, and unknown gesture names.
- Add opt-in BMI270 spatial gestures: two deliberate taps arm one four-second gesture window, with stability, recording, cooldown, and Bridge context guards.
- Add a menu-bar switch that persists the gesture setting in Bridge state and synchronizes it to StickS3 without reflashing.
- Add a Chinese quick-start infographic covering installer setup, recognition modes, the manual BlackHole 2ch dependency for WeChat Input, and StickS3 button controls.

## v0.2.19

- Generate an isolated ESP-IDF sdkconfig from committed defaults so stale local configuration cannot silently disable power management.
- Cancel deep sleep unless wake-source and Wi-Fi shutdown preparation succeed, and restart safely if the PMIC power-down sequence fails.
- Require authenticated VibeStick firmware identity before accepting power telemetry.

## v0.2.18

- Enable ESP-IDF dynamic frequency scaling from 240 MHz down to the 40 MHz crystal frequency.
- Enable tickless idle and automatic light sleep after the display is fully off.
- Hold a no-light-sleep lock while the LCD is active and reacquire it before waking the panel.

## v0.2.17

- Discover the installer-managed ESP-IDF 5.5.1 checkout automatically in `scripts/run-idf.sh`.
- Verify the power telemetry and front-button deep-sleep firmware with a complete ESP-IDF build.

## v0.2.16

- Enter deep sleep after five minutes of battery-powered inactivity once the display is off.
- Block deep sleep during USB power, charging, recording, retained recording work, or a held wake button.
- Stop Wi-Fi, disable the speaker and L3B peripheral rail, and wake through the front button.
- Log the ESP32-S3 wake cause during the subsequent boot.

## v0.2.15

- Record one authenticated StickS3 power sample per minute outside active recording.
- Persist bounded power telemetry as a rotating JSONL journal and expose latest-sample and CSV export endpoints.
- Include raw battery voltage, displayed percentage, charge/USB state, RSSI, uptime, firmware version, and Bridge receive time.

## v0.2.14

- Derive the dim timeout from the selected screen-off timeout: half the selected duration, capped at 30 seconds.
- Add an end-to-end `Never` screen-off option that disables both dimming and display shutdown.

## v0.2.13

- Add staged display power saving: dim after 30 seconds and suspend the LCD/LVGL tick after the configured idle timeout.
- Enable Wi-Fi minimum-modem power saving while idle and restore full Wi-Fi performance during recording.
- Stabilize the displayed battery percentage with a five-sample median filter.
- Add host-side tests for the display power policy.

## v0.2.12

- Keep three selectable voice-input modes in the macOS menu bar: cloud API, fully local Whisper, and WeChat Input.
- Stream StickS3 PCM into `BlackHole 2ch` while holding WeChat Input's default Fn shortcut, drain the complete audio queue plus tail silence, and restore the original microphone without sending audio to the speakers.
- Let the StickS3 right-side button allow a real Codex approval with a single click and reject it with a double click, targeting the actual Codex accessibility process with Return/Escape.
- Confirm approval state before sounding or displaying it, suppress automatic-review false positives, and clear stale pending state from Codex Desktop approval decisions.
- Expand the ESP32-S3 application partition to 3 MB, leaving roughly 53% free for the current firmware.
- Harden release delivery: synchronize version numbers, embed every Mac/firmware update in the self-contained installer, preserve user secrets during template refresh, and build the installer in release mode by default.
- Refresh user, architecture, protocol, hardware, sound, installer, and contribution documentation for the current behavior.

The WeChat Input integration, local Whisper mode, approval controls, and approval-state lifecycle were validated on the development setup before this tag.

## v0.1.7

- Add a 0–100% StickS3 alert-volume control to the macOS Setup App, persist it in the generated firmware configuration, and apply it to completion, approval, and error tones.
- Enlarge the Wi-Fi and battery readouts, refine the battery outline and charging/non-charging fill geometry, and align a full battery fill evenly inside the icon.
- Move the Codex identity and status group slightly left for better visual balance.
- Center the Roxy status text and tune the spacing between its status dot and label.
- Bundle the updated Setup App, Bridge, firmware, and documentation in the universal macOS release.

## v0.1.6

- Add a Roxy pet view whose animation follows Codex idle, running, approval, done, and error states; use the StickS3 right-side button to switch between Roxy and the dashboard.
- Limit blue-button single-click send and double-click pause actions to the 30 seconds after a successful recording, enforced independently by both firmware and Bridge.
- Keep device state labels in Chinese and remove the Roxy title and button-hint labels for a cleaner pet screen.
- Increase the LVGL task stack to prevent display flicker and repeated firmware resets after adding the animated view.
- Bundle the updated Bridge, firmware, and generated Roxy assets in the universal macOS Setup App.

## v0.1.5

- Add a three-step native macOS installer that prepares Python and ESP-IDF, configures Wi-Fi and ASR, flashes StickS3, installs Bridge/HUD LaunchAgents, and verifies the device end to end.
- Make the device and Bridge Codex-only, remove the unused secondary-provider integration, and simplify the bilingual documentation with Chinese as the default README.
- Show the active Codex conversation count, Wi-Fi state, battery level, and quota more reliably on StickS3.
- Support voice input plus blue-button send and pause controls from the device.
- Notify for completed root Codex conversations without subagent noise.
- Cache Codex session summaries so the two-second device poll no longer reparses large JSONL logs.
- Make recording ownership thread-safe and idempotent, persist stop recovery, validate uploaded PCM, and bound synchronous ASR/external-hook work to the device timeout.
- Harden the Bridge API with authenticated state reads, bounded request bodies, strict HTTP failures, private atomic persistence, and transcript-safe device responses.
- Fix StickS3 audio task shutdown, HTTP status propagation, and deferred alerts during recording.
- Harden install, diagnostics, permissions, documentation, and CI coverage.

## v0.1.4

Initial public release of VibeStick — a tiny desktop companion for coding agents on M5Stack StickS3.

- Home screen shows Codex with live status (running / idle / done / approval / error / offline) and 5-hour / 7-day usage bars.
- Push-to-talk voice input: record on the StickS3, transcribe via any OpenAI-compatible ASR (e.g. SiliconFlow), and paste into the focused app; a local-command / fully-offline path is also supported.
- Codex alerts (done / approval / error) play on the StickS3 speaker.
- First-run helpers (`scripts/setup.sh`, `scripts/doctor.sh`), bridge token authentication, and a bilingual README (English + 中文) with clearly-marked physical steps.

Licensed under MIT.
