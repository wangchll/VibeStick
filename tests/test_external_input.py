from __future__ import annotations

import os
import unittest
from unittest import mock

from vibe_stick.audio.external_input import (
    DEFAULT_EXTERNAL_INPUT_TIMEOUT_SECONDS,
    ExternalVoiceInputAdapter,
    _external_input_timeout_seconds,
)
from vibe_stick.command_runner import ShellCommandResult


class ExternalVoiceInputAdapterTests(unittest.TestCase):
    def test_unconfigured_adapter_is_disabled(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            adapter = ExternalVoiceInputAdapter()
            self.assertFalse(adapter.is_configured())
            self.assertFalse(adapter.commit({}).success)

    def test_success_means_input_method_committed_text(self) -> None:
        result = ShellCommandResult(returncode=0, stdout="微信输入完成", stderr="")
        with mock.patch.dict(
            os.environ,
            {"VIBE_STICK_EXTERNAL_INPUT_CMD": "/tmp/wechat-input"},
            clear=True,
        ), mock.patch(
            "vibe_stick.audio.external_input.run_json_command_hook",
            return_value=result,
        ) as runner:
            committed = ExternalVoiceInputAdapter().commit({"audio_file": "/tmp/a.wav"})

        self.assertTrue(committed.success)
        self.assertEqual(committed.source, "external-input")
        self.assertEqual(committed.message, "微信输入完成")
        runner.assert_called_once_with(
            "VIBE_STICK_EXTERNAL_INPUT_CMD",
            {"audio_file": "/tmp/a.wav"},
            timeout=DEFAULT_EXTERNAL_INPUT_TIMEOUT_SECONDS,
        )

    def test_failure_preserves_command_diagnostic(self) -> None:
        result = ShellCommandResult(returncode=7, stdout="", stderr="没有虚拟麦克风")
        with mock.patch.dict(
            os.environ,
            {"VIBE_STICK_EXTERNAL_INPUT_CMD": "/tmp/wechat-input"},
            clear=True,
        ), mock.patch(
            "vibe_stick.audio.external_input.run_json_command_hook",
            return_value=result,
        ):
            committed = ExternalVoiceInputAdapter().commit({})

        self.assertFalse(committed.success)
        self.assertEqual(committed.message, "没有虚拟麦克风")

    def test_timeout_is_bounded(self) -> None:
        with mock.patch.dict(
            os.environ,
            {"VIBE_STICK_EXTERNAL_INPUT_TIMEOUT_SECONDS": "999"},
            clear=True,
        ):
            self.assertEqual(_external_input_timeout_seconds(), 120)


if __name__ == "__main__":
    unittest.main()
