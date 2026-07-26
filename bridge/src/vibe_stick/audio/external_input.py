from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

from vibe_stick.command_runner import run_json_command_hook

DEFAULT_EXTERNAL_INPUT_TIMEOUT_SECONDS = 30
MAX_EXTERNAL_INPUT_TIMEOUT_SECONDS = 120


@dataclass(frozen=True)
class ExternalInputResult:
    success: bool
    message: str
    source: str = "external-input"


class ExternalVoiceInputAdapter:
    """Hand recorded audio to an input method that commits text itself.

    Unlike an ASR adapter, an external input method does not return transcript
    text to the Bridge. The configured command receives the recording session
    JSON on stdin and exits successfully only after it has committed text into
    the currently focused field.
    """

    def is_configured(self) -> bool:
        return bool(os.environ.get("VIBE_STICK_EXTERNAL_INPUT_CMD", "").strip())

    def commit(self, session_payload: dict[str, Any]) -> ExternalInputResult:
        result = run_json_command_hook(
            "VIBE_STICK_EXTERNAL_INPUT_CMD",
            session_payload,
            timeout=_external_input_timeout_seconds(),
        )
        if result is None:
            return ExternalInputResult(False, "No external voice input command configured")
        if result.error:
            return ExternalInputResult(
                False,
                f"External voice input failed: {result.error}",
            )
        if result.returncode != 0:
            message = (
                result.stderr
                or result.stdout
                or "External voice input command failed"
            ).strip()
            return ExternalInputResult(False, message)
        return ExternalInputResult(
            True,
            result.stdout.strip() or "External input method committed the recording",
        )


def _external_input_timeout_seconds() -> int:
    raw = os.environ.get(
        "VIBE_STICK_EXTERNAL_INPUT_TIMEOUT_SECONDS",
        str(DEFAULT_EXTERNAL_INPUT_TIMEOUT_SECONDS),
    )
    try:
        value = int(raw)
    except ValueError:
        return DEFAULT_EXTERNAL_INPUT_TIMEOUT_SECONDS
    return max(5, min(MAX_EXTERNAL_INPUT_TIMEOUT_SECONDS, value))
