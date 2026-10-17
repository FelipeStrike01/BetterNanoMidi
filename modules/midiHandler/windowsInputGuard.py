"""Avoid sending synthetic piano keys into the NanoMIDI controls themselves."""

import ctypes
import os
from ctypes import wintypes

from modules.functions import mainFunctions


_user32 = ctypes.WinDLL("user32", use_last_error=True)
_user32.GetForegroundWindow.restype = wintypes.HWND
_user32.GetWindowThreadProcessId.argtypes = [
    wintypes.HWND,
    ctypes.POINTER(wintypes.DWORD),
]
_user32.GetWindowThreadProcessId.restype = wintypes.DWORD
_warning_logged = False


def keyboardOutputAllowed() -> bool:
    """Return false while this app owns focus, preventing stray UI shortcuts."""
    global _warning_logged

    try:
        window = _user32.GetForegroundWindow()
        process_id = wintypes.DWORD()
        if window:
            _user32.GetWindowThreadProcessId(window, ctypes.byref(process_id))
        app_is_foreground = bool(window) and process_id.value == os.getpid()
    except Exception:
        app_is_foreground = False

    if app_is_foreground:
        if not _warning_logged:
            mainFunctions.log("Keyboard notes are waiting: focus the piano app to send them.")
            _warning_logged = True
        return False

    _warning_logged = False
    return True
