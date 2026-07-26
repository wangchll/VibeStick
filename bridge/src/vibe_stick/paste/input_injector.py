from __future__ import annotations

import platform
import subprocess
import time
from dataclasses import dataclass


@dataclass
class PasteResult:
    success: bool
    message: str


class MacPasteInjector:
    def press_enter(self) -> PasteResult:
        return self._run_osascript(
            ['tell application "System Events" to key code 36'],
            success_message="Pressed Return in the focused app",
        )

    def clear_codex_draft(self) -> PasteResult:
        return self._run_osascript(
            [
                'tell application id "com.openai.codex" to activate',
                "delay 0.12",
                'tell application "System Events" to keystroke "a" using command down',
                "delay 0.08",
                'tell application "System Events" to key code 51',
            ],
            success_message="Cleared the Codex draft",
        )

    def pause_current_codex_task(self) -> PasteResult:
        # Codex uses Escape to focus the composer (when needed), show the stop
        # confirmation, and then interrupt the current turn. The final Escape
        # is harmless when the composer was already focused and the turn has
        # stopped after the second one.
        return self._run_osascript(
            [
                'tell application id "com.openai.codex" to activate',
                "delay 0.12",
                'tell application "System Events" to key code 53',
                "delay 0.16",
                'tell application "System Events" to key code 53',
                "delay 0.16",
                'tell application "System Events" to key code 53',
            ],
            success_message="Sent the Codex stop shortcut",
        )

    def approve_codex_task(self) -> PasteResult:
        return self._press_codex_permission_button(
            ["Allow once", "Allow", "Continue", "允许一次", "允许", "继续"],
            success_message="Clicked the Codex approval button",
        )

    def cancel_codex_task(self) -> PasteResult:
        return self._press_codex_permission_button(
            ["Deny", "Don't allow", "Cancel", "拒绝", "不允许", "取消"],
            success_message="Clicked the Codex rejection button",
        )

    def _press_codex_permission_button(
        self,
        labels: list[str],
        *,
        success_message: str,
    ) -> PasteResult:
        # Do not send Return/Escape blindly: when focus is in the composer those
        # keys can submit or stop a task while leaving the permission prompt
        # untouched. Accessibility lets us press only a real, labelled button.
        apple_labels = "{" + ", ".join(f'\"{label}\"' for label in labels) + "}"
        script = [
            'tell application id "com.openai.codex" to activate',
            "delay 0.12",
            f"set targetLabels to {apple_labels}",
            'tell application "System Events"',
            '  if not (exists process "Codex") then error "Codex is not running"',
            '  tell process "Codex"',
            '    if not (exists front window) then error "Codex has no front window"',
            '    repeat with itemRef in entire contents of front window',
            '      try',
            '        if role of itemRef is "AXButton" then',
            '          set buttonLabel to ""',
            '          try',
            '            set buttonLabel to name of itemRef as text',
            '          end try',
            '          if buttonLabel is in targetLabels then',
            '            perform action "AXPress" of itemRef',
            '            return "VIBESTICK_CLICKED:" & buttonLabel',
            '          end if',
            '        end if',
            '      end try',
            '    end repeat',
            '  end tell',
            'end tell',
            'error "No matching Codex permission button is visible"',
        ]
        return self._run_osascript(script, success_message=success_message)

    def paste(self, text: str, press_enter: bool = False) -> PasteResult:
        text = text.strip()
        if not text:
            return PasteResult(False, "No text to paste")
        if platform.system() != "Darwin":
            return PasteResult(False, "Automatic paste is only available on macOS")

        previous_text = self._read_clipboard()
        set_result = self._set_clipboard(text)
        if not set_result.success:
            return set_result

        script = [
            'tell application "System Events" to keystroke "v" using command down',
        ]
        if press_enter:
            script.extend([
                "delay 0.12",
                'tell application "System Events" to key code 36',
            ])

        result = self._run_osascript(script, success_message="Pasted into the focused app")
        time.sleep(0.2)
        if previous_text is not None:
            self._set_clipboard(previous_text)

        return result

    def _run_osascript(self, script: list[str], *, success_message: str) -> PasteResult:
        if platform.system() != "Darwin":
            return PasteResult(False, "macOS keyboard control is only available on macOS")

        args = ["osascript"]
        for line in script:
            args.extend(["-e", line])
        try:
            result = subprocess.run(args, check=False, capture_output=True, text=True, timeout=4)
        except (OSError, subprocess.TimeoutExpired) as exc:
            return PasteResult(False, f"macOS keyboard control failed: {exc}")
        if result.returncode != 0:
            message = (result.stderr or result.stdout or "macOS keyboard control failed").strip()
            return PasteResult(False, message)
        return PasteResult(True, success_message)

    def _read_clipboard(self) -> str | None:
        try:
            result = subprocess.run(
                ["pbpaste"],
                check=False,
                capture_output=True,
                text=True,
                timeout=1,
            )
        except (OSError, subprocess.TimeoutExpired):
            return None
        if result.returncode != 0:
            return None
        return result.stdout

    def _set_clipboard(self, text: str) -> PasteResult:
        try:
            result = subprocess.run(
                ["pbcopy"],
                input=text,
                check=False,
                capture_output=True,
                text=True,
                timeout=1,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return PasteResult(False, f"Clipboard write failed: {exc}")
        if result.returncode != 0:
            message = (result.stderr or "Clipboard write failed").strip()
            return PasteResult(False, message)
        return PasteResult(True, "Clipboard updated")
