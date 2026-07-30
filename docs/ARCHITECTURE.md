# VibeStick Architecture

VibeStick has two active runtime parts:

1. StickS3 firmware.
2. Local Mac bridge service.

The StickS3 does not call cloud AI services directly. It polls and posts to the Mac bridge over HTTP on the local network.

```mermaid
flowchart LR
  Codex["Local Codex sessions"] --> Bridge["VibeStick Bridge"]
  Bridge --> HUD["macOS HUD"]
  Stick["StickS3 firmware"] <--> Bridge
  Stick --> Screen["StickS3 screen"]
  Stick --> Speaker["StickS3 speaker"]
  Stick --> Mic["StickS3 microphone"]
  Bridge --> Paste["macOS paste injection"]
  Bridge --> ASR["Cloud API or local Whisper"]
  Bridge --> WeChat["WeChat Input via BlackHole + held Fn"]
```

## StickS3 Firmware

Firmware lives in `firmware/sticks3/`.

It owns:

- Screen rendering with LVGL.
- Wi-Fi connection.
- Polling `GET /state`.
- Posting button events to `/event`.
- Optional BMI270 spatial gestures: pressing the front and side buttons together arms a single-action window and consumes both button actions. Only then does firmware enable the 100 Hz accelerometer; it powers the sensor down after recognition, timeout, recording start, or feature disable. Inside the window, two taps, three taps, and continuous shaking are recognised from acceleration changes. The Bridge validates the global enable state again before injecting input. The menu-bar settings window owns window length, sensitivity, and per-gesture default, disabled, or validated custom Codex shortcuts.
- Blue front-button controls: long press records push-to-talk audio; for 30 seconds after a successful recording, single click sends Return and double click stops the current Codex turn. Clicks outside that window are ignored by both firmware and Bridge.
- Right-side `KEY2` control: GPIO 12 single/double click switches views and confirms/rejects a pending approval; a 700 ms long press asks the Bridge to clear the latest pasted voice draft.
- Roxy animation selection from the same Codex state used by the dashboard: idle/offline, running, approval, done, and error.
- 16 kHz / 16-bit / mono PCM recording from the StickS3 microphone.
- Uploading PCM to `/recording/audio`.
- Agent status sounds generated as PCM and played through ES8311/I2S speaker output.
- Local battery and USB power display from the StickS3 PMIC.

It does not read account cookies, browser state, API keys, or quota dashboards.

The application firmware is identical for every device. At boot it validates schema v1 from the independent `vibe_cfg` NVS partition and remains in a visible `等待配置` state without starting Wi-Fi when configuration is absent or invalid. ASR credentials remain entirely on the Mac.

## Mac Bridge

Bridge code lives in `bridge/src/vibe_stick/`.

It owns:

- HTTP API for the StickS3.
- Local Codex status and quota observation from `~/.codex/sessions/**/*.jsonl`.
- Recording session state.
- Three menu-bar-selectable voice paths: an OpenAI-compatible cloud API, fully local Whisper, or WeChat Input through a virtual microphone.
- Transcript paste injection into the active macOS app.
- Return-key injection for sending a draft and Codex-targeted Escape injection for stopping the current turn, gated by the 30-second post-recording action window.
- HUD state file updates for recording status.

Bridge state is stored under:

```text
~/Library/Application Support/VibeStick/
```

## Transport

v0.3.11 uses HTTP over Wi-Fi.

BLE is not part of the current mainline transport. USB is used for verified prebuilt flashing and serial logs, not for runtime state transport.

HTTP traffic is not encrypted. The shared token authorizes protected requests but can be captured and replayed by an observer on the same network. The supported deployment boundary is a private, trusted LAN with port `8765` blocked from the internet.

## State Flow

1. The StickS3 polls `GET /state` every 2 seconds while interactive. After the screen turns off during an observed active task, it keeps Wi-Fi modem sleep enabled and polls every 30 seconds.
2. The Bridge builds a local `VibeStickState`.
3. The StickS3 parses Codex status, quota fields, and alert fields.
4. The StickS3 updates both the dashboard widgets and the Roxy animation; `KEY2` chooses which view is visible.
5. Alert sounds are triggered only on relevant alert state changes, not on every poll.
6. While completion watch and screen-off are both active, local PMIC reads run every 30 seconds and standalone power telemetry runs every 5 minutes; waking the screen restores the normal 2-second and 1-minute intervals.

## Recording Flow

1. User long-presses the blue front button.
2. Firmware starts StickS3 microphone recording and posts `/recording/start`.
3. Firmware shows a full-screen listening overlay.
4. Firmware streams offset-addressed PCM chunks while the button remains held; retries are idempotent.
5. User releases the button, firmware sends the final chunk, then posts `/recording/stop`.
6. Cloud/local modes write a WAV, run ASR, and paste the transcript. WeChat mode drains the virtual-microphone queue and tail silence before releasing Fn; WeChat writes directly into the focused field.
7. Recording start and stop do not play agent alert sounds.

## Status And Quota

Codex status is inferred from local Codex process/session activity and recent session event payloads. Quota is inferred from `token_count` events containing `rate_limits`. The display follows the reported window dynamically: a single weekly window is shown as remaining usage plus reset countdown, while legacy dual 5-hour/7-day windows remain supported. This is a local observation strategy, not an official quota API.

Codex observation covers all user-started root conversations visible in local session data. Background subagents are excluded. A completion in any root conversation can publish an alert even while another conversation keeps the aggregate screen status at `RUNNING`.

An explicit `task_started` lifecycle keeps its root conversation active through silent periods for up to two hours. StickS3 latches that active state across temporary network failures, blocks deep sleep until a valid terminal state arrives, and then returns to the normal idle sleep policy after playing the alert.

The StickS3 home screen is dedicated to Codex status and quota.

## v0.3.11 Limits

- Notarization still requires the release operator's Developer ID and notary credentials; source builds fall back to ad-hoc signing.
- No OTA delivery yet, although the fixed partition layout reserves two OTA slots and rollback metadata.
- No general device abstraction beyond StickS3.
- No official Codex API for quota.
- No BLE runtime transport.
