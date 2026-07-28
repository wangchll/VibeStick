from __future__ import annotations

from pathlib import Path

from vibe_stick.config.storage import ensure_private_dir, ensure_private_file


APP_SUPPORT_DIR = (
    Path.home() / "Library" / "Application Support" / "VibeStick"
)
STATE_PATH = APP_SUPPORT_DIR / "state.json"
QUOTA_PATH = APP_SUPPORT_DIR / "quota.json"
RECORDING_PATH = APP_SUPPORT_DIR / "recording.json"
HUD_STATE_PATH = APP_SUPPORT_DIR / "hud-state.json"
RECORDINGS_DIR = APP_SUPPORT_DIR / "Recordings"
POWER_TELEMETRY_PATH = APP_SUPPORT_DIR / "Telemetry" / "power.jsonl"
# Both helpers are built as proper .app bundles. macOS TCC only honors the
# privacy usage-description keys (NSSpeechRecognitionUsageDescription,
# NSMicrophoneUsageDescription) when they live in a real bundle's
# Contents/Info.plist; a bare Mach-O (even with an embedded __info_plist
# section) is killed with EXC_CRASH / SIGABRT on first privacy access.
MIC_RECORDER_PATH = (
    APP_SUPPORT_DIR / "vibe_stick_mic_recorder.app" / "Contents" / "MacOS" / "vibe_stick_mic_recorder"
)
MIC_RECORDER_STAMP_PATH = APP_SUPPORT_DIR / "vibe_stick_mic_recorder.sha256"
APPLE_ASR_PATH = (
    APP_SUPPORT_DIR / "vibe_stick_asr.app" / "Contents" / "MacOS" / "vibe_stick_asr"
)
APPLE_ASR_STAMP_PATH = APP_SUPPORT_DIR / "vibe_stick_asr.sha256"
WECHAT_INPUT_PATH = (
    APP_SUPPORT_DIR
    / "vibe_stick_wechat_input.app"
    / "Contents"
    / "MacOS"
    / "vibe_stick_wechat_input"
)
WECHAT_INPUT_STAMP_PATH = APP_SUPPORT_DIR / "vibe_stick_wechat_input.sha256"


def ensure_app_support() -> Path:
    ensure_private_dir(APP_SUPPORT_DIR)
    for path in (
        STATE_PATH,
        QUOTA_PATH,
        RECORDING_PATH,
        HUD_STATE_PATH,
    ):
        ensure_private_file(path)
    if RECORDINGS_DIR.exists():
        ensure_private_dir(RECORDINGS_DIR)
        try:
            recording_files = tuple(RECORDINGS_DIR.iterdir())
        except OSError:
            recording_files = ()
        for path in recording_files:
            try:
                if path.is_file():
                    ensure_private_file(path)
            except OSError:
                continue
    ensure_private_file(MIC_RECORDER_PATH, executable=True)
    ensure_private_file(MIC_RECORDER_STAMP_PATH)
    ensure_private_file(APPLE_ASR_PATH, executable=True)
    ensure_private_file(APPLE_ASR_STAMP_PATH)
    ensure_private_file(WECHAT_INPUT_PATH, executable=True)
    ensure_private_file(WECHAT_INPUT_STAMP_PATH)
    return APP_SUPPORT_DIR
