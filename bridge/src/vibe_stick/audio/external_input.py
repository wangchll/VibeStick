from __future__ import annotations

import hashlib
import json
import os
import platform
import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from vibe_stick.command_runner import run_json_command_hook, run_shell_command
from vibe_stick.config.paths import APP_SUPPORT_DIR, WECHAT_INPUT_PATH, WECHAT_INPUT_STAMP_PATH
from vibe_stick.config.storage import atomic_write_text, ensure_private_dir, ensure_private_file

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

    def __init__(self) -> None:
        self._stream_process: subprocess.Popen[str] | None = None

    def start_stream(self) -> bool:
        if _external_input_provider() != "wechat-input":
            return False
        binary = _ensure_wechat_helper_binary()
        if binary is None:
            return False
        try:
            self._stream_process = subprocess.Popen(
                [str(binary), "--stream"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=False,
            )
        except OSError:
            self._stream_process = None
            return False
        return True

    def write_stream(self, pcm: bytes) -> bool:
        process = self._stream_process
        if process is None or process.stdin is None or process.poll() is not None:
            return False
        try:
            process.stdin.write(pcm)
            process.stdin.flush()
            return True
        except (BrokenPipeError, OSError):
            return False

    def finish_stream(self) -> ExternalInputResult | None:
        process = self._stream_process
        self._stream_process = None
        if process is None:
            return None
        try:
            stdout, stderr = process.communicate(timeout=_external_input_timeout_seconds())
        except subprocess.TimeoutExpired:
            process.kill()
            stdout, stderr = process.communicate()
            return ExternalInputResult(False, "WeChat Input stream timed out", "wechat-input")
        if process.returncode != 0:
            message = (stderr or stdout or b"WeChat Input stream failed").decode(
                "utf-8", errors="replace"
            ).strip()
            return ExternalInputResult(False, message, "wechat-input")
        return ExternalInputResult(
            True,
            (stdout or b"").decode("utf-8", errors="replace").strip()
            or "WeChat Input consumed the live StickS3 stream",
            "wechat-input",
        )

    def abort_stream(self) -> None:
        process = self._stream_process
        self._stream_process = None
        if process is not None and process.poll() is None:
            process.kill()

    def is_configured(self) -> bool:
        return (
            _external_input_provider() == "wechat-input"
            or bool(os.environ.get("VIBE_STICK_EXTERNAL_INPUT_CMD", "").strip())
        )

    def commit(self, session_payload: dict[str, Any]) -> ExternalInputResult:
        if _external_input_provider() == "wechat-input":
            return self._commit_wechat(session_payload)
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

    def _commit_wechat(self, session_payload: dict[str, Any]) -> ExternalInputResult:
        binary = _ensure_wechat_helper_binary()
        if binary is None:
            return ExternalInputResult(False, "Could not build the WeChat Input helper", "wechat-input")
        try:
            input_text = json.dumps(session_payload)
        except (RecursionError, TypeError, ValueError):
            return ExternalInputResult(False, "Recording session could not be serialized", "wechat-input")
        result = run_shell_command(
            shlex.quote(str(binary)),
            input_text=input_text,
            timeout=_external_input_timeout_seconds(),
        )
        if result.error or result.returncode != 0:
            message = (
                result.error
                or result.stderr
                or result.stdout
                or "WeChat Input helper failed"
            ).strip()
            return ExternalInputResult(False, message, "wechat-input")
        return ExternalInputResult(
            True,
            result.stdout.strip() or "WeChat Input committed the recording",
            "wechat-input",
        )


def _external_input_provider() -> str:
    value = os.environ.get("VIBE_STICK_EXTERNAL_INPUT_PROVIDER", "").strip().lower()
    return value if value == "wechat-input" else ""


def _ensure_wechat_helper_binary() -> Path | None:
    source = Path(__file__).resolve().parents[3] / "tools" / "vibe_stick_wechat_input.swift"
    plist = source.parent / "vibe_stick_wechat_input_Info.plist"
    binary = WECHAT_INPUT_PATH
    app_bundle = binary.parents[2]
    if not source.is_file() or not plist.is_file():
        return None
    try:
        digest = hashlib.sha256(source.read_bytes() + plist.read_bytes()).hexdigest()
        installed_digest = WECHAT_INPUT_STAMP_PATH.read_text().strip()
    except (FileNotFoundError, OSError):
        installed_digest = ""
        try:
            digest = hashlib.sha256(source.read_bytes() + plist.read_bytes()).hexdigest()
        except OSError:
            return None
    if binary.is_file() and installed_digest == digest:
        ensure_private_file(binary, executable=True)
        return binary

    ensure_private_dir(binary.parent)
    module_cache = APP_SUPPORT_DIR / ".swift-module-cache"
    ensure_private_dir(module_cache)
    temporary = app_bundle.parent / f".{binary.name}.{os.getpid()}.tmp"
    target_arch = "x86_64" if platform.machine() == "x86_64" else "arm64"
    try:
        result = subprocess.run(
            [
                "swiftc",
                "-target",
                f"{target_arch}-apple-macosx14.0",
                "-module-cache-path",
                str(module_cache),
                str(source),
                "-o",
                str(temporary),
                "-framework",
                "AVFoundation",
                "-framework",
                "AudioToolbox",
                "-framework",
                "ApplicationServices",
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        temporary.unlink(missing_ok=True)
        return None
    if result.returncode != 0:
        temporary.unlink(missing_ok=True)
        print(
            "wechat input helper build failed: "
            + (result.stderr or result.stdout or "swiftc failed").strip(),
            flush=True,
        )
        return None
    try:
        os.replace(temporary, binary)
        atomic_write_text(
            app_bundle / "Contents" / "Info.plist",
            plist.read_text(encoding="utf-8"),
            skip_if_unchanged=True,
        )
        ensure_private_file(binary, executable=True)
        signed = subprocess.run(
            ["codesign", "--force", "--sign", "-", str(app_bundle)],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if signed.returncode != 0:
            return None
        atomic_write_text(
            WECHAT_INPUT_STAMP_PATH,
            digest + "\n",
            skip_if_unchanged=True,
        )
    except OSError:
        temporary.unlink(missing_ok=True)
        return None
    return binary


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
