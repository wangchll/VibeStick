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
    _KEY_CODES = {
        "return": 36, "enter": 36, "escape": 53, "esc": 53, "space": 49,
        "tab": 48, "delete": 51, "backspace": 51, "left": 123, "right": 124,
        "down": 125, "up": 126, "home": 115, "end": 119,
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
        "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46,
        "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
        "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
        "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
    }
    _MODIFIERS = {
        "cmd": "command down", "command": "command down",
        "ctrl": "control down", "control": "control down",
        "option": "option down", "alt": "option down", "shift": "shift down",
    }

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
        return self._send_codex_permission_key(
            36,
            success_message="Sent Return to the Codex permission prompt",
        )

    def cancel_codex_task(self) -> PasteResult:
        return self._send_codex_permission_key(
            53,
            success_message="Sent Escape to the Codex permission prompt",
        )

    def send_codex_shortcut(self, shortcut: str) -> PasteResult:
        try:
            key, modifiers = self._parse_shortcut(shortcut)
        except ValueError as exc:
            return PasteResult(False, str(exc))
        using = ""
        if modifiers:
            using = " using {" + ", ".join(modifiers) + "}"
        physical_key = "2" if key == "@" else key
        if physical_key in self._KEY_CODES:
            command = f'key code {self._KEY_CODES[physical_key]}{using}'
        else:
            escaped = key.replace("\\", "\\\\").replace('"', '\\"')
            command = f'keystroke "{escaped}"{using}'
        return self._run_osascript(
            [
                'tell application id "com.openai.codex" to activate',
                'tell application "System Events"',
                '  set codexProcesses to every application process whose bundle identifier is "com.openai.codex"',
                '  if (count of codexProcesses) is 0 then error "Codex accessibility process is not running"',
                '  set codexProcess to first item of codexProcesses',
                '  tell codexProcess',
                '    set frontmost to true',
                '    if (count of windows) > 0 then perform action "AXRaise" of front window',
                '  end tell',
                '  repeat 20 times',
                '    if frontmost of codexProcess then exit repeat',
                '    delay 0.05',
                '  end repeat',
                '  if not (frontmost of codexProcess) then error "Codex did not become frontmost"',
                '  delay 0.25',
                f'  {command}',
                'end tell',
            ],
            success_message=f"Sent Codex shortcut {shortcut}",
        )

    def new_codex_task(self) -> PasteResult:
        """Open a new Codex task through its native menu command.

        The default shake action should not depend on which renderer control
        currently owns keyboard focus.  Selecting the application's own menu
        item invokes the same command as Command-N while remaining reliable
        when an overlay or side panel is focused.
        """
        return self._run_osascript(
            [
                'tell application id "com.openai.codex" to activate',
                'tell application "System Events"',
                '  set codexProcesses to every application process whose bundle identifier is "com.openai.codex"',
                '  if (count of codexProcesses) is 0 then error "Codex accessibility process is not running"',
                '  set codexProcess to first item of codexProcesses',
                '  tell codexProcess',
                '    set frontmost to true',
                '    if (count of windows) > 0 then perform action "AXRaise" of front window',
                '    set newTaskItem to missing value',
                '    repeat with topItem in menu bar items of menu bar 1',
                '      try',
                '        repeat with candidate in menu items of menu 1 of topItem',
                '          if value of attribute "AXMenuItemCmdChar" of candidate is "N" and value of attribute "AXMenuItemCmdModifiers" of candidate is 0 then',
                '            set newTaskItem to candidate',
                '            exit repeat',
                '          end if',
                '        end repeat',
                '      end try',
                '      if newTaskItem is not missing value then exit repeat',
                '    end repeat',
                '    if newTaskItem is missing value then error "Codex New Chat menu item was not found"',
                '    click newTaskItem',
                '  end tell',
                'end tell',
            ],
            success_message="Opened a new Codex task",
        )

    @classmethod
    def validate_shortcut(cls, shortcut: str) -> str:
        key, modifiers = cls._parse_shortcut(shortcut)
        canonical_modifiers = []
        reverse = {
            "command down": "command", "control down": "control",
            "option down": "option", "shift down": "shift",
        }
        for modifier in modifiers:
            canonical_modifiers.append(reverse[modifier])
        return "+".join([*canonical_modifiers, key])

    @classmethod
    def _parse_shortcut(cls, shortcut: str) -> tuple[str, list[str]]:
        parts = [part.strip().lower() for part in shortcut.split("+") if part.strip()]
        if not parts:
            raise ValueError("Shortcut cannot be empty")
        key = parts[-1]
        if key not in cls._KEY_CODES and not (len(key) == 1 and key.isprintable() and key.isascii()):
            raise ValueError("Unsupported shortcut key")
        modifiers: list[str] = []
        for part in parts[:-1]:
            modifier = cls._MODIFIERS.get(part)
            if modifier is None:
                raise ValueError("Unsupported shortcut modifier")
            if modifier not in modifiers:
                modifiers.append(modifier)
        if not modifiers and len(key) == 1:
            raise ValueError("Single-character shortcuts require a modifier")
        return key, modifiers

    def _send_codex_permission_key(
        self,
        key_code: int,
        *,
        success_message: str,
    ) -> PasteResult:
        # The app bundle is com.openai.codex, but its Accessibility process is
        # named "ChatGPT". Targeting the old process name "Codex" made every
        # side-button action fail before a key was sent. Return accepts the
        # focused permission prompt and Escape rejects it.
        script = [
            'tell application id "com.openai.codex" to activate',
            "delay 0.12",
            'tell application "System Events"',
            '  if not (exists process "ChatGPT") then error "Codex accessibility process is not running"',
            f'  tell process "ChatGPT" to key code {key_code}',
            'end tell',
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
