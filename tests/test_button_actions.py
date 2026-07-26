from __future__ import annotations

import threading
import unittest
from unittest import mock

from vibe_stick.paste.input_injector import PasteResult
from vibe_stick.protocol.state import AlertState, AlertType, default_state
from vibe_stick.server import app


class ButtonActionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.store = app.BridgeStateStore.__new__(app.BridgeStateStore)
        self.store._lock = threading.RLock()
        self.store._state = default_state()
        self.store._state.alert = AlertState(event_id="done", type=AlertType.DONE, message="done")
        self.store._post_recording_action_until = float("inf")
        self.store._last_session_pasted = False
        self.store._save_state_locked = mock.Mock()
        self.store.refresh_quota_locked = mock.Mock()
        self.store.input_injector = mock.Mock()
        self.store.input_injector.press_enter.return_value = PasteResult(True, "sent")
        self.store.input_injector.pause_current_codex_task.return_value = PasteResult(True, "paused")
        self.store.input_injector.clear_codex_draft.return_value = PasteResult(True, "cleared")
        self.store.input_injector.approve_codex_task.return_value = PasteResult(True, "approved")
        self.store.input_injector.cancel_codex_task.return_value = PasteResult(True, "cancelled")

    def test_short_press_sends_and_clears_alert(self) -> None:
        self.store._last_session_pasted = True

        self.store.update_from_event({"event": "button_short"})

        self.store.input_injector.press_enter.assert_called_once_with()
        self.store.input_injector.pause_current_codex_task.assert_not_called()
        self.assertEqual(self.store._state.alert.type, AlertType.NONE)

    def test_double_click_pauses_without_refreshing_quota(self) -> None:
        self.store.update_from_event({"event": "button_double"})

        self.store.input_injector.pause_current_codex_task.assert_called_once_with()
        self.store.input_injector.press_enter.assert_not_called()
        self.store.refresh_quota_locked.assert_not_called()

    def test_clicks_are_ignored_before_recording_window_opens(self) -> None:
        self.store._post_recording_action_until = 0.0

        self.store.update_from_event({"event": "button_short"})
        self.store.update_from_event({"event": "button_double"})

        self.store.input_injector.press_enter.assert_not_called()
        self.store.input_injector.pause_current_codex_task.assert_not_called()
        self.assertEqual(self.store._state.alert.type, AlertType.DONE)

    def test_clicks_are_ignored_after_recording_window_expires(self) -> None:
        self.store._post_recording_action_until = 30.0

        with mock.patch.object(app.time, "monotonic", return_value=30.1):
            self.store.update_from_event({"event": "button_short"})
            self.store.update_from_event({"event": "button_double"})

        self.store.input_injector.press_enter.assert_not_called()
        self.store.input_injector.pause_current_codex_task.assert_not_called()
        self.assertEqual(self.store._post_recording_action_until, 0.0)

    def test_successful_recording_stop_opens_thirty_second_window(self) -> None:
        session = mock.Mock(status="pasted")
        session.to_public_jsonable.return_value = {"status": "pasted"}
        self.store.recording = mock.Mock()
        self.store.recording.stop.return_value = session
        self.store.get_state = mock.Mock(return_value=default_state())

        with mock.patch.object(app.time, "monotonic", return_value=100.0):
            self.store.stop_recording({"session_id": "recording"})

        self.assertEqual(self.store._post_recording_action_until, 130.0)

    def test_new_recording_closes_existing_window(self) -> None:
        session = mock.Mock()
        session.to_public_jsonable.return_value = {"status": "recording"}
        self.store.recording = mock.Mock()
        self.store.recording.start.return_value = session
        self.store.get_state = mock.Mock(return_value=default_state())

        self.store.start_recording({"session_id": "next-recording"})

        self.assertEqual(self.store._post_recording_action_until, 0.0)

    def test_failed_recording_stop_closes_existing_window(self) -> None:
        session = mock.Mock(status="transcription_failed")
        session.to_public_jsonable.return_value = {"status": "transcription_failed"}
        self.store.recording = mock.Mock()
        self.store.recording.stop.return_value = session
        self.store.get_state = mock.Mock(return_value=default_state())

        self.store.stop_recording({"session_id": "recording"})

        self.assertEqual(self.store._post_recording_action_until, 0.0)

    def test_side_single_click_approves_when_codex_status_is_waiting(self) -> None:
        self.store._state.alert = AlertState(event_id="", type=AlertType.NONE, message="")
        self.store._state.codex.status = app.AgentStatus.APPROVAL

        self.store.update_from_event({"event": "button_approval_confirm"})
        self.store.update_from_event({"event": "button_approval_confirm"})

        self.store.input_injector.approve_codex_task.assert_called_once_with()
        self.store.input_injector.cancel_codex_task.assert_not_called()
        self.assertEqual(self.store._state.codex.status, app.AgentStatus.RUNNING)

    def test_side_double_click_rejects_when_provider_status_is_waiting(self) -> None:
        self.store._state.alert = AlertState(event_id="", type=AlertType.NONE, message="")
        self.store._state.provider.status = app.AgentStatus.APPROVAL

        self.store.update_from_event({"event": "button_approval_cancel"})

        self.store.input_injector.cancel_codex_task.assert_called_once_with()
        self.store.input_injector.approve_codex_task.assert_not_called()

    def test_approval_action_failure_keeps_alert_for_retry(self) -> None:
        self.store._state.alert = AlertState(
            event_id="approval", type=AlertType.APPROVAL, message="waiting"
        )
        self.store.input_injector.approve_codex_task.return_value = PasteResult(False, "failed")

        self.store.update_from_event({"event": "button_approval_confirm"})

        self.assertEqual(self.store._state.alert.type, AlertType.APPROVAL)

    def test_side_clicks_are_ignored_without_pending_approval(self) -> None:
        self.store.update_from_event({"event": "button_approval_confirm"})
        self.store.update_from_event({"event": "button_approval_cancel"})

        self.store.input_injector.approve_codex_task.assert_not_called()
        self.store.input_injector.cancel_codex_task.assert_not_called()

    def test_side_long_press_clears_pasted_voice_draft(self) -> None:
        self.store._last_session_pasted = True

        self.store.update_from_event({"event": "button_clear_draft"})

        self.store.input_injector.clear_codex_draft.assert_called_once_with()
        self.assertFalse(self.store._last_session_pasted)
        self.assertEqual(self.store._post_recording_action_until, 0.0)

    def test_side_long_press_does_not_clear_during_approval(self) -> None:
        self.store._last_session_pasted = True
        self.store._state.codex.status = app.AgentStatus.APPROVAL

        self.store.update_from_event({"event": "button_clear_draft"})

        self.store.input_injector.clear_codex_draft.assert_not_called()
        self.assertTrue(self.store._last_session_pasted)

    def test_side_long_press_failure_keeps_draft_available(self) -> None:
        self.store._last_session_pasted = True
        self.store.input_injector.clear_codex_draft.return_value = PasteResult(False, "failed")

        self.store.update_from_event({"event": "button_clear_draft"})

        self.assertTrue(self.store._last_session_pasted)


if __name__ == "__main__":
    unittest.main()
