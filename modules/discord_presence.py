"""Non-blocking Discord Rich Presence client for Better NanoMidi."""

from __future__ import annotations

import logging
import threading
import time
from typing import Any

from PySide6.QtCore import QObject, Signal

logger = logging.getLogger(__name__)


class DiscordPresenceService(QObject):
    """Own the Discord IPC connection away from Qt's UI thread."""

    statusChanged = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._lock = threading.Lock()
        self._enabled = False
        self._application_id = ""
        self._activity: dict[str, str] | None = None
        self._revision = 0
        self._wake = threading.Event()
        self._stop = threading.Event()
        self._thread = threading.Thread(
            target=self._run,
            name="discord-rich-presence",
            daemon=True,
        )
        self._thread.start()

    def configure(self, enabled: bool, application_id: str) -> None:
        application_id = "".join(ch for ch in str(application_id) if ch.isdigit())[:20]
        with self._lock:
            self._enabled = bool(enabled)
            self._application_id = application_id
            self._revision += 1
        self._wake.set()

    def set_activity(self, details: str, state: str) -> None:
        with self._lock:
            self._activity = {
                "details": str(details)[:128],
                "state": str(state)[:128],
            }
            self._revision += 1
        self._wake.set()

    def shutdown(self, timeout: float = 1.5) -> None:
        self._stop.set()
        self._wake.set()
        if self._thread.is_alive() and threading.current_thread() is not self._thread:
            self._thread.join(timeout=max(0.0, timeout))

    def _snapshot(self) -> tuple[bool, str, dict[str, str] | None, int]:
        with self._lock:
            activity = dict(self._activity) if self._activity is not None else None
            return self._enabled, self._application_id, activity, self._revision

    def _emit_status(self, value: str) -> None:
        self.statusChanged.emit(value)

    @staticmethod
    def _close_rpc(rpc: Any) -> None:
        if rpc is None:
            return
        try:
            rpc.clear()
        except Exception:
            logger.debug("Discord presence could not be cleared", exc_info=True)
        try:
            rpc.close()
        except Exception:
            logger.debug("Discord RPC connection already closed", exc_info=True)

    @staticmethod
    def _publish(rpc: Any, activity: dict[str, str] | None) -> None:
        if activity is None:
            rpc.clear()
            return

        fields = {
            "details": activity["details"],
            "state": activity["state"],
            "large_image": "betternanomidi",
            "large_text": "Better NanoMidi",
        }
        try:
            rpc.update(**fields)
        except Exception:
            # The activity remains useful if the developer-portal image key
            # has not been uploaded for this Discord application yet.
            logger.info("Discord art key unavailable; retrying without custom art")
            rpc.update(details=fields["details"], state=fields["state"])

    @staticmethod
    def _connect_rpc(application_id: str) -> Any:
        from pypresence import Presence

        last_error: Exception | None = None
        # Discord can expose multiple IPC pipes (for example, one logged-out
        # renderer and one active desktop client). pypresence's automatic
        # discovery stops at the first pipe, so probe each supported index.
        for pipe_index in range(10):
            candidate = Presence(application_id, pipe=pipe_index)
            try:
                candidate.connect()
                return candidate
            except Exception as error:
                last_error = error
                try:
                    candidate.close()
                except Exception:
                    logger.debug("Could not close rejected Discord IPC pipe", exc_info=True)

        if last_error is not None:
            raise last_error
        raise RuntimeError("No Discord IPC pipe was available.")

    def _run(self) -> None:
        rpc = None
        connected_application_id = ""
        last_sent_revision = -1
        retry_after = 0.0
        last_status = ""

        def status(value: str) -> None:
            nonlocal last_status
            if value != last_status:
                last_status = value
                self._emit_status(value)

        while not self._stop.is_set():
            self._wake.wait(timeout=0.4)
            self._wake.clear()
            if self._stop.is_set():
                break

            enabled, application_id, activity, revision = self._snapshot()
            if not enabled:
                self._close_rpc(rpc)
                rpc = None
                connected_application_id = ""
                last_sent_revision = -1
                status("Disabled")
                continue

            if not application_id:
                self._close_rpc(rpc)
                rpc = None
                connected_application_id = ""
                last_sent_revision = -1
                status("Enter a Discord Application ID to enable Rich Presence.")
                continue

            if rpc is not None and connected_application_id != application_id:
                self._close_rpc(rpc)
                rpc = None
                connected_application_id = ""
                last_sent_revision = -1

            if rpc is None and time.monotonic() >= retry_after:
                try:
                    candidate = self._connect_rpc(application_id)
                    rpc = candidate
                    connected_application_id = application_id
                    last_sent_revision = -1
                    retry_after = 0.0
                    status("Discord connected; sharing activity.")
                except Exception as error:
                    logger.debug("Discord Rich Presence connection failed", exc_info=True)
                    retry_after = time.monotonic() + 6.0
                    if getattr(error, "code", None) == 1000:
                        status("Sign in to the Discord desktop app and try again.")
                    elif getattr(error, "code", None) == 4000:
                        status("Discord did not recognize the Application ID.")
                    else:
                        status("Open the Discord desktop app and try again.")
                    continue

            if rpc is None:
                continue

            if revision != last_sent_revision:
                try:
                    self._publish(rpc, activity)
                    last_sent_revision = revision
                    status("Discord connected; sharing activity.")
                except Exception:
                    logger.info("Discord RPC connection was lost", exc_info=True)
                    self._close_rpc(rpc)
                    rpc = None
                    connected_application_id = ""
                    last_sent_revision = -1
                    retry_after = time.monotonic() + 6.0
                    status("Reconnecting to Discord…")

        self._close_rpc(rpc)
