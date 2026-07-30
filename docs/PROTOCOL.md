# Protocol

VibeStick v0.3.11 uses HTTP over Wi-Fi between the StickS3 firmware and the local Mac bridge.

Default bridge URL:

```text
http://<mac-ip>:8765
```

## Firmware Headers

Firmware requests include:

```text
X-Vibe-Stick-Firmware-Name: vibestick
X-Vibe-Stick-Firmware-Version: 0.3.11
X-Vibe-Stick-Firmware-Transport: HTTP
X-Vibe-Stick-Firmware-Build-Date: <compile date>
```

Audio upload requests additionally include:

```text
X-Vibe-Stick-Sample-Rate: 16000
X-Vibe-Stick-Channels: 1
X-Vibe-Stick-Bits-Per-Sample: 16
```

When `VIBE_STICK_BRIDGE_TOKEN` is configured on the bridge and firmware, protected requests also include:

```text
X-Vibe-Stick-Token: <shared-token>
```

Protected endpoints are `GET /state`, `/event`, `/quota/refresh`, `/recording/start`, `/recording/audio`, and `/recording/stop`. If the bridge binds outside loopback, such as `0.0.0.0`, `VIBE_STICK_BRIDGE_TOKEN` is required and placeholder tokens are rejected. If the bridge binds to loopback only, missing tokens are allowed for local development. `GET /health` remains public for installation and diagnostics.

This transport is plain HTTP. The token is sent over the LAN and therefore does not protect against passive capture or replay. Run the bridge only on a private, trusted network, keep port `8765` behind the macOS firewall, and never forward it to the internet. A future authenticated-encryption or nonce/HMAC transport is needed before treating hostile networks as supported.

## GET /state

Returns the current bridge state:

```json
{
  "time": "13:01",
  "wifi": true,
  "ble": false,
  "battery": null,
  "active_provider": "codex",
  "provider": {
    "id": "codex",
    "display_name": "Codex",
    "implemented": true,
    "status": "RUNNING",
    "project": "vibestick",
    "active_conversations": 2,
    "quota_5h_remaining": 53,
    "quota_7d_remaining": 93,
    "quota_remaining": 93,
    "quota_window_minutes": 10080,
    "quota_resets_at": 1785664678,
    "quota_reset_after_seconds": 518400,
    "quota_updated_at": "13:01",
    "quota_stale": false
  },
  "codex": {
    "status": "RUNNING",
    "project": "vibestick",
    "active_conversations": 2,
    "quota_5h_remaining": 53,
    "quota_7d_remaining": 93,
    "quota_remaining": 93,
    "quota_window_minutes": 10080,
    "quota_resets_at": 1785664678,
    "quota_reset_after_seconds": 518400,
    "quota_updated_at": "13:01",
    "quota_stale": false
  },
  "alert": {
    "event_id": "",
    "type": "NONE",
    "message": ""
  },
  "bridge_name": "vibestick-bridge",
  "bridge_version": "0.3.11"
}
```

`battery` is intentionally `null` from the bridge. The StickS3 displays its local PMIC battery reading.

`active_provider` is fixed to `codex`, and the normalized `provider` block mirrors the `codex` block for older firmware. `active_conversations` is the number of running root conversations, clamped to `0` through `99`; Codex subagent sessions are excluded. An explicit `task_started` lifecycle remains active through silent periods for up to two hours or until a matching terminal event. The firmware shows this number only while Codex is `RUNNING`.

`quota_remaining` is the remaining percentage for the single current Codex usage window, `quota_window_minutes` describes that window, `quota_resets_at` is its Unix reset timestamp, and `quota_reset_after_seconds` is a bridge-calculated countdown for devices without a wall clock. With a weekly-only window, firmware renders `WEEK <percent>` and `RESET <days/hours>`; the reset progress bar shows the remaining time as a proportion of the full window. If Codex reports both the legacy 5-hour and 7-day windows, the generic fields are `null` and firmware retains the `5H`/`7D` display. `quota_5h_remaining` and `quota_7d_remaining` remain for backward compatibility. An unknown percentage is rendered as `--%`.

## GET /health

Returns bridge health metadata:

```json
{
  "ok": true,
  "bridge_name": "vibestick-bridge",
  "bridge_version": "0.3.11"
}
```

## POST /event

Receives generic firmware or debug events.

Examples:

```json
{"event":"button_short","source":"sticks3"}
```

After a recording finishes successfully, `button_short` injects Return into the focused macOS app and consumes the pending draft after a successful injection. While no draft is pending and Codex is `IDLE` or `UNKNOWN`, the same event raises the Codex desktop app and sends one Escape to focus its composer. `button_double` remains available for 30 seconds after recording and sends the Codex stop-turn Escape sequence. Other states ignore the focus action so a click cannot disturb a running turn, completion alert, error, or approval prompt.

```json
{"event":"button_double","source":"sticks3"}
```

```json
{"event":"test_agent_status","source":"manual_test","status":"DONE","message":"test done"}
```

Manual `DONE`, `ERROR`, and `APPROVAL` statuses produce alert fields for local testing.

The right-side button sends `button_approval_confirm` on a single click and `button_approval_cancel` on a double click. The Bridge acts only while a confirmed approval is pending: confirm activates Codex and sends Return; cancel activates Codex and sends Escape. Without a pending approval, these host actions are ignored while the firmware still changes dashboard/Roxy view.

When spatial gestures are enabled, pressing the front and side buttons together opens one recognition window. The chord is consumed, so it does not trigger either button's normal action. The BMI270 recognises direct device motion only inside that window and ignores activation while voice recording is active:

```json
{"event":"gesture","source":"sticks3","gesture":"double_tap"}
```

Supported values are `double_tap`, `triple_tap`, and `shake`. The Bridge ignores all gesture events while the persisted `gestures_enabled` setting is false. Defaults mirror this Mac's Codex keybindings: double tap switches Planning mode (`Control-Shift-1`), triple tap switches Fast mode (`Control-Shift-3`), and shake creates a new task (`Command-N`). Each mapping remains editable in the menu-bar settings window.

`POST /api/gestures` is the loopback management endpoint used by the menu-bar settings window. It persists the global switch, a 2–8 second recognition window, sensitivity, and mappings:

```json
{
  "enabled": true,
    "window_ms": 4000,
  "sensitivity": "conservative",
  "mappings": {
    "double_tap": "default",
    "triple_tap": "default",
    "shake": "shortcut:command+n"
  }
}
```

Mappings accept only `default`, `disabled`, or a validated `shortcut:` value. Custom shortcuts activate Codex and send one key with any combination of Command, Control, Option, and Shift; they cannot execute scripts or shell commands.

## POST /quota/refresh

Requests a Codex quota refresh from local session events. If no valid local snapshot is available, quota fields remain `null` and the firmware shows `--%`.

```json
{
  "refreshed": true,
  "state": {
    "time": "13:01",
    "wifi": true,
    "battery": null
  }
}
```

## POST /recording/start

Starts a recording session:

```json
{
  "event": "button_long_start",
  "source": "sticks3",
  "audio_source": "sticks3_pcm",
  "session_id": "<firmware-generated-id>"
}
```

## POST /recording/audio

Uploads raw little-endian signed PCM for the active session:

```text
POST /recording/audio?session_id=<id>
Content-Type: application/octet-stream
```

When the `/recording/start` response contains `"streaming": true`, firmware
uploads consecutive chunks while the button remains held:

```text
POST /recording/audio?session_id=<id>&offset=<pcm-byte-offset>
```

Offsets make retries idempotent. A Bridge that does not advertise streaming
continues to receive the original single complete upload after button release.

The bridge writes a local WAV file under:

```text
~/Library/Application Support/VibeStick/Recordings/
```

The bridge rejects audio uploads larger than `VIBE_STICK_MAX_RECORDING_AUDIO_BYTES`. The default is `2000000` bytes.

## POST /recording/stop

Stops the session and runs transcription:

```json
{"event":"button_long_stop","source":"sticks3","paste":true,"session_id":"<firmware-generated-id>"}
```

In cloud/local modes, the Bridge pastes a successful transcript into the focused macOS app. In WeChat mode, WeChat Input writes directly into the field that owned focus when the Fn session began. Recording status does not trigger agent alert sounds.
