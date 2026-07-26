from __future__ import annotations

import subprocess
import unittest
from unittest import mock

from vibe_stick.paste.input_injector import MacPasteInjector


class MacInputInjectorTests(unittest.TestCase):
    @mock.patch("vibe_stick.paste.input_injector.platform.system", return_value="Darwin")
    @mock.patch("vibe_stick.paste.input_injector.subprocess.run")
    def test_press_enter_sends_return_key(self, run: mock.Mock, _system: mock.Mock) -> None:
        run.return_value = subprocess.CompletedProcess([], 0, "", "")

        result = MacPasteInjector().press_enter()

        self.assertTrue(result.success)
        args = run.call_args.args[0]
        self.assertIn('tell application "System Events" to key code 36', args)

    @mock.patch("vibe_stick.paste.input_injector.platform.system", return_value="Darwin")
    @mock.patch("vibe_stick.paste.input_injector.subprocess.run")
    def test_pause_targets_codex_and_confirms_stop(self, run: mock.Mock, _system: mock.Mock) -> None:
        run.return_value = subprocess.CompletedProcess([], 0, "", "")

        result = MacPasteInjector().pause_current_codex_task()

        self.assertTrue(result.success)
        args = run.call_args.args[0]
        self.assertIn('tell application id "com.openai.codex" to activate', args)
        self.assertEqual(args.count('tell application "System Events" to key code 53'), 3)

    @mock.patch("vibe_stick.paste.input_injector.platform.system", return_value="Darwin")
    @mock.patch("vibe_stick.paste.input_injector.subprocess.run")
    def test_clear_draft_targets_codex_and_selects_all(self, run: mock.Mock, _system: mock.Mock) -> None:
        run.return_value = subprocess.CompletedProcess([], 0, "", "")

        result = MacPasteInjector().clear_codex_draft()

        self.assertTrue(result.success)
        args = run.call_args.args[0]
        self.assertIn('tell application id "com.openai.codex" to activate', args)
        self.assertIn('tell application "System Events" to keystroke "a" using command down', args)
        self.assertIn('tell application "System Events" to key code 51', args)

    @mock.patch("vibe_stick.paste.input_injector.platform.system", return_value="Darwin")
    @mock.patch("vibe_stick.paste.input_injector.subprocess.run")
    def test_approval_targets_chatgpt_accessibility_process_and_sends_return(
        self, run: mock.Mock, _system: mock.Mock
    ) -> None:
        run.return_value = subprocess.CompletedProcess([], 0, "", "")

        result = MacPasteInjector().approve_codex_task()

        self.assertTrue(result.success)
        args = run.call_args.args[0]
        self.assertIn('  if not (exists process "ChatGPT") then error "Codex accessibility process is not running"', args)
        self.assertIn('  tell process "ChatGPT" to key code 36', args)

    @mock.patch("vibe_stick.paste.input_injector.platform.system", return_value="Darwin")
    @mock.patch("vibe_stick.paste.input_injector.subprocess.run")
    def test_rejection_targets_chatgpt_accessibility_process_and_sends_escape(
        self, run: mock.Mock, _system: mock.Mock
    ) -> None:
        run.return_value = subprocess.CompletedProcess([], 0, "", "")

        result = MacPasteInjector().cancel_codex_task()

        self.assertTrue(result.success)
        args = run.call_args.args[0]
        self.assertIn('  tell process "ChatGPT" to key code 53', args)

    @mock.patch("vibe_stick.paste.input_injector.platform.system", return_value="Linux")
    @mock.patch("vibe_stick.paste.input_injector.subprocess.run")
    def test_keyboard_actions_fail_cleanly_off_macos(self, run: mock.Mock, _system: mock.Mock) -> None:
        result = MacPasteInjector().press_enter()

        self.assertFalse(result.success)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
