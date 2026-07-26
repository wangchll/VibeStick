"""Local, fully-offline speech transcription via a local Whisper model.

This adapter backs the ``apple-on-device`` ASR provider (the "本机离线识别"
toggle in the menu bar). It deliberately does NOT use Apple's
``SFSpeechRecognizer``:

* On current macOS, ``SFSpeechRecognizer`` is gated by TCC, which requires a
  non-ad-hoc code signature **and** an interactive consent dialog. A background
  helper spawned by the bridge has neither, so the Speech framework kills the
  process with ``EXC_CRASH`` / ``SIGABRT`` the moment it is touched -- there is
  no way to make it work from the bridge's subprocess.

* A locally-run Whisper model (faster-whisper) performs inference entirely on
  the recorded WAV with no privacy framework involved. It works head-less,
  offline, and needs no code signature or consent dialog.

The Whisper model is downloaded once on first use (network required that one
time only) and cached; every subsequent run is fully offline. The model size
can be overridden with ``VIBE_STICK_WHISPER_MODEL`` (e.g. ``tiny``, ``base``,
``small``, ``medium``); ``small`` is the default -- ``base`` mangles
English words embedded in Chinese speech (code-switching), while ``small``
and up keep them intact.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Optional

from vibe_stick.audio.transcriber import TranscriptionResult

DEFAULT_MODEL = "small"
SOURCE = "whisper-local"

# Guides Whisper to keep embedded English words spelled out instead of
# transliterating them into Chinese characters (the base model ignores this,
# but small/medium/large honor it and it is harmless otherwise).
_INITIAL_PROMPT = (
    "以下是中英文混合的语音识别。中文正常转写；其中的英文单词保持英文原文拼写，"
    "不要音译成中文，也不要用《》、<>或括号包裹英文单词。"
)

# Module-level model cache so repeated recordings in one bridge session do not
# reload the (large) model every time.
_CACHE: dict[str, object] = {"size": None, "model": None}


def _model_size() -> str:
    raw = os.environ.get("VIBE_STICK_WHISPER_MODEL", DEFAULT_MODEL).strip().lower()
    return raw or DEFAULT_MODEL


def _strip_foreign_wrappers(text: str) -> str:
    """Remove 《》, <>, and 「」 wrappers around embedded English words.

    Whisper (especially small/base) tends to wrap foreign words it treats as
    titles with book-title brackets. For voice-to-text we just want the bare
    English spelling, so we strip the brackets while keeping the inner text.
    Only wrappers whose inner content starts with a Latin letter are touched,
    so genuine Chinese book titles are left alone.
    """
    text = re.sub(r"《([A-Za-z][^》\n]*?)》", r"\1", text)
    text = re.sub(r"〈([A-Za-z][^〉\n]*?)〉", r"\1", text)
    text = re.sub(r"<([A-Za-z][^>\n]*?)>", r"\1", text)
    text = re.sub(r"「([A-Za-z][^」\n]*?)」", r"\1", text)
    return text


def _language() -> Optional[str]:
    """Return the forced language code, or ``None`` to let Whisper auto-detect.

    Whisper's built-in language detection handles mixed Chinese/English input
    well, so the default is ``None`` (auto). Pin a language with
    ``VIBE_STICK_ASR_LANGUAGE`` (e.g. ``en`` or ``zh``) if you always speak one
    language -- this avoids mismatches when the clip is very short.
    """
    lang = os.environ.get("VIBE_STICK_ASR_LANGUAGE", "").strip().lower()
    if not lang:
        return None
    if lang in {"zh", "zh-cn", "zh_cn", "chinese"}:
        return "zh"
    if lang in {"en", "en-us", "en_us", "english"}:
        return "en"
    return lang


def _get_model():
    from faster_whisper import WhisperModel

    size = _model_size()
    if _CACHE["model"] is None or _CACHE["size"] != size:
        _CACHE["model"] = WhisperModel(size, device="cpu", compute_type="int8")
        _CACHE["size"] = size
    return _CACHE["model"]


class AppleOnDeviceTranscriber:
    """Transcribe a local audio file with an offline Whisper model."""

    SOURCE = SOURCE

    def transcribe(self, audio_file: Path) -> TranscriptionResult:
        audio_file = Path(audio_file)
        if not audio_file.is_file():
            return TranscriptionResult(
                success=False,
                message="No audio file available for local transcription",
                source=self.SOURCE,
            )
        try:
            model = _get_model()
        except Exception as exc:  # model download / load failure
            detail = str(exc)
            if "Connection" in detail or "network" in detail.lower() or "HTTP" in detail:
                hint = " (the Whisper model downloads on first use -- check your network, then retry)"
            else:
                hint = ""
            return TranscriptionResult(
                success=False,
                message=f"Could not load local Whisper model{hint}: {detail}",
                source=self.SOURCE,
            )

        try:
            segments, _info = model.transcribe(
                str(audio_file),
                language=_language(),
                beam_size=5,
                vad_filter=True,
                initial_prompt=_INITIAL_PROMPT,
            )
            text = "".join(getattr(seg, "text", "") or "" for seg in segments).strip()
            # Whisper sometimes wraps embedded English words in 《》 or <> as if
            # they were titles; strip only the wrapper punctuation, keep the
            # English spelling. (e.g. 《Bedside》 -> Bedside)
            text = _strip_foreign_wrappers(text)
        except Exception as exc:
            return TranscriptionResult(
                success=False,
                message=f"Local Whisper transcription failed: {exc}",
                source=self.SOURCE,
            )

        if not text:
            return TranscriptionResult(
                success=False,
                message="Local Whisper returned no transcript (the audio may be silent or too short)",
                source=self.SOURCE,
            )
        return TranscriptionResult(
            text=text,
            success=True,
            message="Transcript from local Whisper model",
            source=self.SOURCE,
        )
