"""Qt/QML application bridge for MIDI features and persistent settings."""

from __future__ import annotations

import copy
import datetime
import json
import logging
import math
import os
import platform
import sys
import threading
import unicodedata
import uuid
import webbrowser
from pathlib import Path
from typing import Any

import markdown
from PySide6.QtCore import QObject, Property, QStandardPaths, QThread, QTimer, Qt, Signal, Slot
from PySide6.QtQml import QQmlPropertyMap
from PySide6.QtWidgets import QFileDialog, QMessageBox

from modules import configuration
from modules.app_info import APP_VERSION
from ui import customTheme
from ui.qt_compat import widgetProxy, widgetGroups
from ui.translations import translate as translate_text

logger = logging.getLogger(__name__)
DEFAULT_DISCORD_APPLICATION_ID = "1561063229206302750"


class MidiMetadataWorker(QThread):
    loaded = Signal(str, float, int)
    failed = Signal(str, str, int)

    def __init__(self, path: str, generation: int, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.path = path
        self.generation = generation

    def run(self) -> None:
        try:
            from mido import MidiFile

            midi = MidiFile(self.path, clip=True)
            duration = float(midi.length)
            if not math.isfinite(duration) or duration < 0:
                raise ValueError("The MIDI file has an invalid duration.")
            self.loaded.emit(self.path, duration, self.generation)
        except Exception as error:
            self.failed.emit(self.path, str(error), self.generation)


class AppController(QObject):
    pageChanged = Signal()
    settingsChanged = Signal()
    runningChanged = Signal()
    midiLoadingChanged = Signal()
    midiLibraryChanged = Signal()
    playlistChanged = Signal()
    midiPlaylistPlaybackFinished = Signal()
    playbackSpeedChanged = Signal()
    consoleChanged = Signal()
    hubChanged = Signal()
    startupChanged = Signal()
    themeChanged = Signal()
    infoChanged = Signal()
    languageChanged = Signal()
    discordPresenceChanged = Signal()
    dialogRequested = Signal(str, str, str)
    confirmRequested = Signal(str, str, object)
    consoleRequested = Signal(int, str, bool)
    clearConsoleRequested = Signal(int)
    hubStateRequested = Signal(object)
    downloadedMidiRequested = Signal(str)
    _infoRequested = Signal(str)

    PAGE_IDS = {
        "midi": 0,
        "drums": 1,
        "hub": 2,
        "miditoqwerty": 3,
        "playlists": 7,
        "settings": 4,
        "info": 5,
        "darwinpermission": 6,
    }
    PAGE_NAMES = {value: key for key, value in PAGE_IDS.items()}
    PAGE_LABELS = {
        "midi": "MIDI Player",
        "drums": "Drums Player",
        "hub": "MIDI Hub",
        "miditoqwerty": "MIDI to QWERTY",
        "playlists": "Playlists",
        "settings": "Settings",
        "info": "About Better NanoMidi",
        "darwinpermission": "Permissions",
    }

    def __init__(self) -> None:
        super().__init__()
        self._window: QObject | None = None
        self._current_page = 0
        self._is_running = False
        self._playback_speed = 100
        self._config: dict[str, Any] = {}
        configured_language = str(configuration.configData.get("appUI", {}).get("language", "en")).lower()
        if configured_language not in {"en", "pt"}:
            configured_language = "en"
            configuration.configData["appUI"]["language"] = configured_language
        self._language = configured_language
        presence_settings = configuration.configData.get("discordPresence")
        if not isinstance(presence_settings, dict):
            configuration.configData["discordPresence"] = {
                "enabled": False,
                "applicationId": DEFAULT_DISCORD_APPLICATION_ID,
            }
        else:
            if "enabled" not in presence_settings:
                presence_settings["enabled"] = False
            if str(presence_settings.get("applicationId") or "").strip() != DEFAULT_DISCORD_APPLICATION_ID:
                presence_settings["applicationId"] = DEFAULT_DISCORD_APPLICATION_ID
        self._theme_palette = self._buildThemePalette(customTheme.activeThemeData)
        self._theme_names = customTheme.fetchThemes()
        self._current_theme = "Dark"
        self._hub_results: list[dict] = []
        self._playlist_cover_cache: dict[str, str] = {}
        self._hub_download_states: dict[str, str] = {}
        self._hub_loading = False
        self._hub_error = ""
        self._hub_notice = ""
        self._hub_catalog_requested = False
        self._startup_progress = 0
        self._startup_status = "Preparing MIDI Hub…"
        self._startup_ready = False
        self._hub_page = 1
        self._hub_total_pages = 1
        self._hub_result_count = 0
        self._control_timers: dict[str, QTimer] = {}
        self._pending_control_values: dict[str, Any] = {}
        self._midi_dialog: QFileDialog | None = None
        self._midi_workers: dict[int, MidiMetadataWorker] = {}
        self._midi_show_errors: dict[int, bool] = {}
        self._midi_library: list[dict[str, Any]] = []
        midi_settings = configuration.configData.get("midiPlayer", {})
        self._playlists = self._normalizePlaylists(midi_settings.get("playlists", []))
        legacy_playlist = self._normalizePlaylist(midi_settings.get("playlist", []))
        migrated_legacy_playlist = not self._playlists and bool(legacy_playlist)
        if migrated_legacy_playlist:
            self._playlists = [{
                "id": uuid.uuid4().hex,
                "name": "Playlist",
                "tracks": legacy_playlist,
            }]
        configured_playlist_id = str(midi_settings.get("activePlaylistId", "") or "")
        valid_playlist_ids = {playlist["id"] for playlist in self._playlists}
        self._active_playlist_id = (
            configured_playlist_id
            if configured_playlist_id in valid_playlist_ids
            else self._playlists[0]["id"] if self._playlists else ""
        )
        active_playlist = self._activePlaylistRecord()
        self._midi_playlist = active_playlist["tracks"] if active_playlist else []
        self._playlist_current_index = 0 if self._midi_playlist else -1
        self._playlist_playing_index = -1
        self._playlist_active = False
        self._pending_playlist_path = ""
        self._pending_playlist_index = -1
        if migrated_legacy_playlist or configured_playlist_id != self._active_playlist_id:
            self._saveMidiPlaylist()
        self._midi_load_generation = 0
        self._midi_loading = False
        self._midi_duration_seconds = 0.0
        self._discord_presence_status = "Disabled"
        self._presence_mode = "idle"
        self._presence_source = "midi"
        self._presence_file = ""
        self._presence_path = ""
        self._console_lines: dict[str, list[str]] = {name: [] for name in self.PAGE_IDS}
        self._info_html = "<h2>Loading information</h2><p>Fetching the latest project information…</p>"
        self._log_labels: list[Any] = []
        self.maxMidiPlayerConsoleLog = 8
        self.maxDrumPlayerConsoleLog = 14
        self.maxMidiToQWERTYLog = 13

        from modules.discord_presence import DiscordPresenceService

        self._discord_presence = DiscordPresenceService(self)
        self._discord_presence.statusChanged.connect(self._setDiscordPresenceStatus)

        from modules.functions import mainFunctions

        mainFunctions.registerApp(self)
        self.consoleRequested.connect(self._appendConsole, Qt.ConnectionType.QueuedConnection)
        self.clearConsoleRequested.connect(self._clearConsole, Qt.ConnectionType.QueuedConnection)
        self.dialogRequested.connect(self._showDialog, Qt.ConnectionType.QueuedConnection)
        self.confirmRequested.connect(self._confirm, Qt.ConnectionType.QueuedConnection)
        self.hubStateRequested.connect(self._applyHubState, Qt.ConnectionType.QueuedConnection)
        self.downloadedMidiRequested.connect(self._scheduleDownloadedMidiOpen, Qt.ConnectionType.QueuedConnection)
        self.midiPlaylistPlaybackFinished.connect(
            self._advanceMidiPlaylist, Qt.ConnectionType.QueuedConnection
        )
        self._infoRequested.connect(self._applyInfo, Qt.ConnectionType.QueuedConnection)

        # Import after registering the controller: legacy playback services
        # capture getApp() at import time, while their widgets are QML proxies.
        from modules.functions import (
            drumsMacroFunctions,
            midiHubFunctions,
            midiPlayerFunctions,
            midiToQWERTYFunctions,
            settingsFunctions,
        )

        self.midiPlayer = midiPlayerFunctions
        self.drums = drumsMacroFunctions
        self.midiToQwerty = midiToQWERTYFunctions
        self.hub = midiHubFunctions
        self.settingsFunctions = settingsFunctions

        self._prepareProxies()
        settingsFunctions.initControlSets()
        settingsFunctions.midiCustomHoldLengthStatus()
        settingsFunctions.drumsCustomHoldLengthStatus()
        settingsFunctions.midiRandomFailStatus()
        settingsFunctions.drumsRandomFailStatus()
        midiToQWERTYFunctions.customHoldLengthStatus()
        self._ui = self._buildUiMap()

        self.midiPlayer.loadSavedFile()
        self.drums.loadSavedFile()
        self._refreshMidiLibrary()
        saved_midi = str(widgetProxy("midiPlayer", "filePathEntry").get() or "")
        if saved_midi and os.path.isfile(saved_midi):
            self._queueMidiLoad(saved_midi, show_error=False)
        self.midiPlayer.switchUseMIDIvar.set(
            "on" if configuration.configData.get("midiPlayer", {}).get("useMIDIOutput", False) else "off"
        )
        self._refreshSnapshot()
        self._syncDiscordPresenceConfiguration()
        self.refreshDevices()
        mainFunctions.tabBind(0)
        self.loadInfo()

        if configuration.configData.get("appUI", {}).get("checkForUpdates", False) and platform.system() == "Windows":
            from modules import updater

            threading.Thread(target=updater.runUpdater, args=(APP_VERSION,), name="update-check", daemon=True).start()

    def _prepareProxies(self) -> None:
        names = {
            "midiPlayer": [
                "filePathEntry", "outputDeviceDropdown", "midiToggleSwitch", "playButton", "pauseButton",
                "stopButton", "timelineIndicator", "speedSlider", "speedValueEntry", "fingerLimitValueLabel",
                "playHotkeyButton", "pauseHotkeyButton", "stopHotkeyButton", "speedUpHotkeyButton",
                "slowHotkeyButton", "consoleFrame", "sustainToggle", "noDoublesToggle", "velocityToggle",
                "use88KeysToggle", "pitchDropdown", "keyTransposeDropdown",
            ],
            "drums": [
                "midiPathDropdown", "playButton", "stopButton", "timelineIndicator", "speedSlider",
                "speedValueEntry", "fingerLimitValueLabel", "playHotkeyButton", "pauseHotkeyButton",
                "stopHotkeyButton", "speedUpHotkeyButton", "slowHotkeyButton", "consoleFrame",
            ],
            "midiToQwerty": [
                "inputDeviceDropdown", "toggleListener", "consoleFrame", "customHoldLengthSlider",
                "customHoldLengthEntry", "sustainCutoffSlider", "sustainCutoffEntry", "moduleSelector",
                "resetCustomHoldLength",
            ],
            "hub": ["searchEntry", "sortComboBox", "searchButton", "mainScrollFrame", "loadingFrame"],
            "settings": [
                "playHotkeyButton", "pauseHotkeyButton", "stopHotkeyButton", "speedUpHotkeyButton",
                "slowHotkeyButton", "midiNoteLengthSlider", "midiNoteLengthEntry", "midiNoteLengthLabel",
                "midiResetNoteLength", "midiSpeedFailSlider", "midiSpeedFailEntry", "midiSpeedFailLabel",
                "midiResetSpeedFailButton", "midiTransposeFailSlider", "midiTransposeFailEntry",
                "midiTransposeFailLabel", "midiResetTransposeFailButton", "midiDecreaseSizeSlider",
                "midiDecreaseSizeEntry", "drumsNoteLengthSlider", "drumsNoteLengthEntry",
                "drumsNoteLengthLabel", "drumsResetNoteLength", "drumsSpeedFailSlider",
                "drumsSpeedFailEntry", "drumsSpeedFailLabel", "drumsResetSpeedFailButton",
                "drumsDecreaseSizeSlider", "drumsDecreaseSizeEntry", "themeSelector",
            ],
        }
        for page, attributes in names.items():
            for attribute in attributes:
                widgetProxy(page, attribute)
        hotkeys = configuration.configData.get("hotkeys", {})
        button_names = {
            "play": "playHotkeyButton",
            "pause": "pauseHotkeyButton",
            "stop": "stopHotkeyButton",
            "speedup": "speedUpHotkeyButton",
            "slowdown": "slowHotkeyButton",
        }
        for page in ("midiPlayer", "drums", "settings"):
            for key, button in button_names.items():
                widgetProxy(page, button).configure(text=str(hotkeys.get(key, "")).upper())

    def _buildUiMap(self) -> QQmlPropertyMap:
        groups = QQmlPropertyMap(self)
        for page, widgets in widgetGroups().items():
            group = QQmlPropertyMap(groups)
            for name, widget in widgets.items():
                group.insert(name, widget)
            groups.insert(page, group)
        return groups

    def attachWindow(self, window: QObject) -> None:
        self._window = window
        if self._config.get("appUI", {}).get("topmost"):
            from PySide6.QtCore import Qt

            window.setFlag(Qt.WindowType.WindowStaysOnTopHint, True)

    @Slot()
    def activateMainWindow(self) -> None:
        """Show and foreground the main window when the startup splash ends."""
        window = self._window
        if not window:
            return

        try:
            window.setVisible(True)
            window.raise_()
            window.requestActivate()

            if sys.platform != "win32":
                return

            import ctypes
            from ctypes import wintypes

            user32 = ctypes.WinDLL("user32", use_last_error=True)
            hwnd = wintypes.HWND(int(window.winId()))
            user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
            user32.ShowWindow.restype = wintypes.BOOL
            user32.SetWindowPos.argtypes = [
                wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int,
                ctypes.c_int, ctypes.c_int, wintypes.UINT,
            ]
            user32.SetWindowPos.restype = wintypes.BOOL
            user32.BringWindowToTop.argtypes = [wintypes.HWND]
            user32.BringWindowToTop.restype = wintypes.BOOL
            user32.SetForegroundWindow.argtypes = [wintypes.HWND]
            user32.SetForegroundWindow.restype = wintypes.BOOL

            position_flags = 0x0001 | 0x0002 | 0x0010 | 0x0040  # no size/move/activate; show
            topmost = ctypes.c_void_p(-1)
            not_topmost = ctypes.c_void_p(-2)
            user32.ShowWindow(hwnd, 9)  # SW_RESTORE
            user32.SetWindowPos(hwnd, topmost, 0, 0, 0, 0, position_flags)
            user32.BringWindowToTop(hwnd)
            foregrounded = bool(user32.SetForegroundWindow(hwnd))

            if foregrounded:
                user32.SetWindowPos(hwnd, not_topmost, 0, 0, 0, 0, position_flags)
            else:
                # Keep the just-opened window above other apps briefly if
                # Windows declines activation, then restore normal z-order.
                QTimer.singleShot(
                    1200,
                    lambda: user32.SetWindowPos(
                        hwnd, not_topmost, 0, 0, 0, 0, position_flags
                    ),
                )
        except Exception:
            logger.exception("Could not bring the main window to the foreground")

    def _refreshSnapshot(self) -> None:
        try:
            self._config = configuration.configData.to_dict()
        except Exception:
            self._config = {}
        self.settingsChanged.emit()
        self.consoleChanged.emit()
        self.themeChanged.emit()

    def _buildThemePalette(self, data: dict[str, Any]) -> dict[str, str]:
        theme = data.get("Theme", {}) if isinstance(data, dict) else {}
        brand = theme.get("Brand", {})
        theme_name = str(data.get("Name", "")).strip().lower() if isinstance(data, dict) else ""
        is_default_dark = theme_name in ("dark", "dark (default)")
        navigation = theme.get("Navigation", {})
        midi = theme.get("MidiPlayer", {})
        settings = theme.get("Settings", {})
        hub = theme.get("MIDIHub", {})
        default = {
            "background": "#141210", "surface": "#1D1A17", "raised": "#25211D",
            "text": "#E9E1D8", "muted": "#A89D91", "line": "#382F29",
            "accent": "#B76B4D", "accentHover": "#CC825F",
            "danger": "#B3655C", "success": "#8AAB86",
        }
        if not is_default_dark:
            default.update({
                "background": navigation.get("BackColor", default["background"]),
                "surface": midi.get("BackgroundColor", default["surface"]),
                "text": midi.get("TextColor", default["text"]),
                "muted": settings.get("TextColorDisabled", default["muted"]),
                "accent": hub.get("SearchButtonColor", midi.get("PlayColor", default["accent"])),
                "accentHover": hub.get("SearchButtonHoverColor", midi.get("PlayColorHover", default["accentHover"])),
            })
        return {
            "background": brand.get("Background", default["background"]),
            "surface": brand.get("Surface", default["surface"]),
            "raised": brand.get("Raised", default["raised"]),
            "text": brand.get("Text", default["text"]),
            "muted": brand.get("Muted", default["muted"]),
            "line": brand.get("Line", default["line"]),
            "accent": brand.get("Accent", brand.get("AccentCyan", default["accent"])),
            "accentHover": brand.get("AccentHover", default["accentHover"]),
            "danger": brand.get("Danger", default["danger"]),
            "success": brand.get("Success", default["success"]),
        }

    @Property(QObject, constant=True)
    def ui(self) -> QObject:
        return self._ui

    @Property("QVariantMap", notify=settingsChanged)
    def settings(self) -> dict[str, Any]:
        return copy.deepcopy(self._config)

    @Property(int, notify=pageChanged)
    def currentPage(self) -> int:
        return self._current_page

    @currentPage.setter
    def currentPage(self, value: int) -> None:
        value = max(0, min(7, int(value)))
        if self._current_page != value:
            self._current_page = value
            self.pageChanged.emit()
            self.consoleChanged.emit()

    @Property(str, notify=pageChanged)
    def pageName(self) -> str:
        return self.PAGE_NAMES.get(self._current_page, "midi")

    @Property(str, notify=pageChanged)
    def pageTitle(self) -> str:
        return self.translateText(self.PAGE_LABELS.get(self.pageName, "Better NanoMidi"))

    @Property(str, notify=languageChanged)
    def language(self) -> str:
        return self._language

    @Slot(str, result=str)
    def translateText(self, source: str) -> str:
        return translate_text(source, self._language)

    @Slot(str)
    def setLanguage(self, language: str) -> None:
        language = str(language or "en").lower()
        if language not in {"en", "pt"}:
            language = "en"
        if language == self._language:
            return
        self._language = language
        self._setConfigPath("appUI.language", language)
        self.languageChanged.emit()
        self._refreshSnapshot()
        self.pageChanged.emit()
        self.discordPresenceChanged.emit()
        self.consoleChanged.emit()
        self.hubChanged.emit()
        self.startupChanged.emit()
        self.loadInfo()
        self._publishDiscordPresence()

    @Property(str, notify=discordPresenceChanged)
    def discordPresenceStatus(self) -> str:
        return self.translateText(self._discord_presence_status)

    def _setDiscordPresenceStatus(self, value: str) -> None:
        value = str(value)
        if self._discord_presence_status != value:
            self._discord_presence_status = value
            self.discordPresenceChanged.emit()

    def _syncDiscordPresenceConfiguration(self) -> None:
        settings = configuration.configData.get("discordPresence", {})
        self._discord_presence.configure(
            bool(settings.get("enabled", False)),
            str(settings.get("applicationId", "") or ""),
        )
        self._publishDiscordPresence()

    def _publishDiscordPresence(self) -> None:
        cover_url = ""
        cover_text = ""
        if self._presence_mode == "playing":
            details = "Using the Drums Player" if self._presence_source == "drums" else "Playing MIDI"
            state = self._presence_file or "MIDI file"
        elif self._presence_mode == "paused":
            details = "Drums Player paused" if self._presence_source == "drums" else "MIDI paused"
            state = self._presence_file or "MIDI file"
        else:
            idle_copy = {
                "midi": ("Ready to play", "Select a MIDI to get started"),
                "drums": ("Using the Drums Player", "Ready to play drums"),
                "hub": ("Exploring the MIDI Hub", "Searching community scores"),
                "miditoqwerty": ("Using MIDI to QWERTY", "Converting MIDI to keyboard input"),
                "settings": ("Adjusting preferences", "Better NanoMidi settings"),
                "info": ("Learning about Better NanoMidi", "About the application"),
                "darwinpermission": ("Adjusting permissions", "Better NanoMidi"),
            }
            details, state = idle_copy.get(self.pageName, idle_copy["midi"])

        if self._presence_mode in {"playing", "paused"} and self._presence_source == "midi":
            cover_url, cover_text = self._discordPresenceArtwork(self._presence_path)
        self._discord_presence.set_activity(
            self.translateText(details),
            self.translateText(state),
            cover_url,
            cover_text,
        )

    def _discordPresenceArtwork(self, path: str) -> tuple[str, str]:
        if not path:
            return "", ""

        from modules.functions import midiHubFunctions

        filename = Path(path).name
        filename_key = self._playlistCoverKey(filename)
        stem_key = self._playlistCoverKey(Path(filename).stem)
        if not filename_key and not stem_key:
            return "", ""

        exact_filename = []
        exact_title = []
        for item in list(midiHubFunctions.allMidiData) + list(self._hub_results):
            if not isinstance(item, dict) or str(item.get("source") or "nanomidi") != "nanomidi":
                continue
            midi_filename = str(item.get("midiFilename") or "")
            candidate_filename = self._playlistCoverKey(Path(midi_filename).name)
            candidate_stem = self._playlistCoverKey(Path(midi_filename).stem)
            title_key = self._playlistCoverKey(str(item.get("name") or ""))
            if filename_key and filename_key == candidate_filename or stem_key and stem_key == candidate_stem:
                exact_filename.append(item)
            elif stem_key and stem_key == title_key:
                exact_title.append(item)

        for candidate in exact_filename + exact_title:
            cover_url = midiHubFunctions.fetchPublicImage(candidate)
            if not cover_url:
                continue
            title = str(candidate.get("name") or Path(filename).stem)
            artist = str(candidate.get("artists") or "").strip()
            tooltip = f"{title} · {artist}" if artist else title
            return cover_url, tooltip[:128]
        return "", ""

    @Slot(str, str, str)
    def setPlaybackPresence(self, mode: str, filepath: str, source: str) -> None:
        mode = str(mode).lower()
        self._presence_source = str(source)
        if mode in ("playing", "paused"):
            self._presence_mode = mode
            self._presence_path = str(filepath).strip()
            self._presence_file = os.path.basename(self._presence_path)[:128]
        else:
            self._presence_mode = "idle"
            self._presence_file = ""
            self._presence_path = ""
        self._publishDiscordPresence()

    @Slot(str)
    def setDiscordApplicationId(self, application_id: str) -> None:
        normalized = "".join(ch for ch in str(application_id) if ch.isdigit())[:20]
        self._setConfigPath("discordPresence.applicationId", normalized)
        self._syncDiscordPresenceConfiguration()
        self._refreshSnapshot()

    @Property(bool, notify=runningChanged)
    def isRunning(self) -> bool:
        return self._is_running

    @isRunning.setter
    def isRunning(self, value: bool) -> None:
        value = bool(value)
        if self._is_running != value:
            self._is_running = value
            self.runningChanged.emit()

    @Property(bool, notify=midiLoadingChanged)
    def midiLoading(self) -> bool:
        return self._midi_loading

    @Property("QVariantList", notify=midiLibraryChanged)
    def midiLibrary(self) -> list[dict[str, Any]]:
        return [dict(entry) for entry in self._midi_library]

    @Property("QVariantList", notify=playlistChanged)
    def midiPlaylist(self) -> list[dict[str, Any]]:
        return [
            {
                "path": path,
                "name": Path(path).name or path,
                "coverUrl": self._playlistCoverForPath(path),
                "available": os.path.isfile(path),
                "selected": index == self._playlist_current_index,
                "playing": self._playlist_active and index == self._playlist_playing_index,
            }
            for index, path in enumerate(self._midi_playlist)
        ]

    @Property("QVariantList", notify=playlistChanged)
    def midiPlaylists(self) -> list[dict[str, Any]]:
        playlists = []
        for playlist in self._playlists:
            cover_urls = list(dict.fromkeys(
                cover_url
                for cover_url in (self._playlistCoverForPath(path) for path in playlist["tracks"])
                if cover_url
            ))
            playlists.append({
                "id": playlist["id"],
                "name": playlist["name"],
                "trackCount": len(playlist["tracks"]),
                "missingCount": sum(not os.path.isfile(path) for path in playlist["tracks"]),
                "coverUrl": cover_urls[0] if cover_urls else "",
                "coverUrls": cover_urls[:4],
                "selected": playlist["id"] == self._active_playlist_id,
            })
        return playlists

    @staticmethod
    def _playlistCoverKey(value: str) -> str:
        normalized = unicodedata.normalize("NFKD", str(value or "").casefold())
        return "".join(character for character in normalized if character.isalnum())

    def _playlistCoverForPath(self, path: str) -> str:
        cache_key = os.path.normcase(os.path.abspath(path))
        if cache_key in self._playlist_cover_cache:
            return self._playlist_cover_cache[cache_key]

        from modules.functions import midiHubFunctions

        filename = Path(path).name
        stem_key = self._playlistCoverKey(Path(filename).stem)
        filename_key = self._playlistCoverKey(filename)
        if not stem_key and not filename_key:
            self._playlist_cover_cache[cache_key] = ""
            return ""

        catalog = list(midiHubFunctions.allMidiData) + list(self._hub_results)
        exact_filename = []
        exact_title = []
        for item in catalog:
            if not isinstance(item, dict):
                continue
            midi_filename = str(item.get("midiFilename") or "")
            candidate_filename = self._playlistCoverKey(Path(midi_filename).name)
            candidate_stem = self._playlistCoverKey(Path(midi_filename).stem)
            title_key = self._playlistCoverKey(str(item.get("name") or ""))
            if filename_key and filename_key == candidate_filename or stem_key and stem_key == candidate_stem:
                exact_filename.append(item)
            elif stem_key and stem_key == title_key:
                exact_title.append(item)

        cover_url = ""
        for candidate in exact_filename + exact_title:
            cover_url = str(candidate.get("imageUrl") or midiHubFunctions.fetchImage(candidate) or "")
            if cover_url:
                break
        self._playlist_cover_cache[cache_key] = cover_url
        return cover_url

    @Property(str, notify=playlistChanged)
    def activePlaylistId(self) -> str:
        return self._active_playlist_id

    @Property(str, notify=playlistChanged)
    def activePlaylistName(self) -> str:
        playlist = self._activePlaylistRecord()
        return playlist["name"] if playlist else ""

    @Property(int, notify=playlistChanged)
    def activePlaylistIndex(self) -> int:
        return next(
            (index for index, playlist in enumerate(self._playlists)
             if playlist["id"] == self._active_playlist_id),
            -1,
        )

    @Property(int, notify=playlistChanged)
    def playlistCurrentIndex(self) -> int:
        return self._playlist_current_index

    @Property(bool, notify=playlistChanged)
    def playlistActive(self) -> bool:
        return self._playlist_active

    @Property(int, notify=playbackSpeedChanged)
    def playbackSpeed(self) -> int:
        return self._playback_speed

    @playbackSpeed.setter
    def playbackSpeed(self, value: int) -> None:
        value = int(value)
        if self._playback_speed != value:
            self._playback_speed = value
            self.playbackSpeedChanged.emit()

    @Property("QStringList", notify=consoleChanged)
    def consoleLines(self) -> list[str]:
        return [self.translateText(line) for line in self._console_lines.get(self.pageName, [])]

    @Property(str, notify=consoleChanged)
    def consoleText(self) -> str:
        lines = self._console_lines.get(self.pageName, [])
        return "\n".join(self.translateText(line) for line in lines) if lines else self.translateText("No activity yet. Playback and device events will appear here.")

    @Property("QVariantList", notify=hubChanged)
    def hubResults(self) -> list[dict]:
        return list(self._hub_results)

    @Property("QVariantMap", notify=hubChanged)
    def hubDownloadStates(self) -> dict[str, str]:
        return dict(self._hub_download_states)

    @Property(bool, notify=hubChanged)
    def hubLoading(self) -> bool:
        return self._hub_loading

    @Property(str, notify=hubChanged)
    def hubError(self) -> str:
        return self.translateText(self._hub_error)

    @Property(str, notify=hubChanged)
    def hubNotice(self) -> str:
        return self.translateText(self._hub_notice)

    @Property(int, notify=hubChanged)
    def hubPage(self) -> int:
        return self._hub_page

    @Property(int, notify=hubChanged)
    def hubTotalPages(self) -> int:
        return self._hub_total_pages

    @Property(int, notify=hubChanged)
    def hubResultCount(self) -> int:
        return self._hub_result_count

    @Property(int, notify=startupChanged)
    def startupProgress(self) -> int:
        return self._startup_progress

    @Property(str, notify=startupChanged)
    def startupStatus(self) -> str:
        return self.translateText(self._startup_status)

    @Property(bool, notify=startupChanged)
    def startupReady(self) -> bool:
        return self._startup_ready

    @Property("QStringList", constant=True)
    def themeNames(self) -> list[str]:
        return list(self._theme_names)

    @Property(str, notify=themeChanged)
    def currentTheme(self) -> str:
        return self._current_theme

    @Property("QVariantMap", notify=themeChanged)
    def themePalette(self) -> dict[str, str]:
        return dict(self._theme_palette)

    @Property(str, notify=infoChanged)
    def infoHtml(self) -> str:
        return self._info_html

    @Property(str, constant=True)
    def platformName(self) -> str:
        return platform.system()

    @Property(str, constant=True)
    def appVersion(self) -> str:
        return APP_VERSION

    @Slot(str)
    def navigate(self, page: str) -> None:
        if str(page).lower() == "hub" and not self._hub_catalog_requested:
            self._hub_catalog_requested = True
            self.hub.loadMidiData()
        self.showFrame(page)

    @Slot()
    def beginStartupWarmup(self) -> None:
        if self._hub_catalog_requested:
            return
        self._hub_catalog_requested = True
        self.hub.preloadMidiHubForStartup()

    def showFrame(self, name: str) -> None:
        page = str(name).lower()
        if page not in self.PAGE_IDS:
            page = "midi"
        self.currentPage = self.PAGE_IDS[page]
        from modules.functions import mainFunctions

        mainFunctions.tabBind(self._current_page)
        self._refreshSnapshot()
        if self._presence_mode == "idle":
            self._publishDiscordPresence()

    @Slot()
    def refreshDevices(self) -> None:
        from modules.functions import mainFunctions

        mainFunctions.refreshOutputDevices()
        mainFunctions.refreshInputDevices()

    @Slot(str)
    def selectMidiFile(self, path: str = "") -> None:
        if path:
            self._queueMidiLoad(str(path))
        else:
            self._openMidiPicker()

    @Slot()
    def refreshMidiLibrary(self) -> None:
        self._refreshMidiLibrary()

    def _refreshMidiLibrary(self) -> None:
        midi_settings = configuration.configData.get("midiPlayer", {})
        candidates = list(midi_settings.get("midiList", []) or [])
        candidates.append(midi_settings.get("currentFile", ""))
        candidates.extend(
            path
            for playlist in self._playlists
            for path in playlist["tracks"]
        )

        download_locations = {Path(configuration.baseDirectory) / "Midis"}
        standard_downloads = QStandardPaths.writableLocation(
            QStandardPaths.StandardLocation.DownloadLocation
        )
        if standard_downloads:
            download_locations.add(Path(standard_downloads))
        else:
            download_locations.add(Path.home() / "Downloads")

        for directory in download_locations:
            try:
                candidates.extend(
                    entry for entry in directory.iterdir()
                    if entry.is_file() and entry.suffix.lower() in {".mid", ".midi"}
                )
            except OSError:
                logger.debug("Could not scan MIDI library directory %s", directory, exc_info=True)

        entries_by_path: dict[str, dict[str, Any]] = {}
        for candidate in candidates:
            raw_path = str(candidate or "").strip()
            if not raw_path:
                continue
            path = Path(os.path.abspath(os.path.expanduser(raw_path)))
            if path.suffix.lower() not in {".mid", ".midi"}:
                continue
            try:
                stat = path.stat()
                if not path.is_file():
                    continue
            except OSError:
                continue

            absolute_path = str(path)
            entries_by_path[os.path.normcase(absolute_path)] = {
                "path": absolute_path,
                "name": path.name,
                "folder": str(path.parent),
                "modified": stat.st_mtime,
            }

        entries = sorted(
            entries_by_path.values(),
            key=lambda entry: (-entry["modified"], entry["name"].casefold(), entry["path"].casefold()),
        )
        if entries != self._midi_library:
            self._midi_library = entries
            self.midiLibraryChanged.emit()

    def _openMidiPicker(self) -> None:
        if self._midi_dialog is not None:
            self._midi_dialog.raise_()
            self._midi_dialog.activateWindow()
            return

        dialog = QFileDialog()
        dialog.setWindowTitle(self.translateText("Select MIDI file"))
        dialog.setNameFilter(self.translateText("MIDI files (*.mid *.midi)"))
        dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        dialog.setAcceptMode(QFileDialog.AcceptMode.AcceptOpen)
        current_path = str(widgetProxy("midiPlayer", "filePathEntry").get() or "")
        start_directory = os.path.dirname(current_path) if os.path.isfile(current_path) else ""
        if start_directory:
            dialog.setDirectory(start_directory)
        dialog.fileSelected.connect(self._queueMidiLoad)
        dialog.finished.connect(lambda _result, current=dialog: self._clearMidiDialog(current))
        self._midi_dialog = dialog
        dialog.open()

    def _clearMidiDialog(self, dialog: QFileDialog) -> None:
        if self._midi_dialog is dialog:
            self._midi_dialog = None
        dialog.deleteLater()

    def _normalizePlaylist(self, paths: Any) -> list[str]:
        if not isinstance(paths, (list, tuple)):
            return []
        normalized: list[str] = []
        seen: set[str] = set()
        for value in paths:
            path = str(value or "").strip()
            if not path or Path(path).suffix.lower() not in {".mid", ".midi"}:
                continue
            path = os.path.abspath(os.path.expanduser(path))
            key = os.path.normcase(path)
            if key not in seen:
                normalized.append(path)
                seen.add(key)
        return normalized

    def _normalizePlaylists(self, values: Any) -> list[dict[str, Any]]:
        if not isinstance(values, (list, tuple)):
            return []
        playlists: list[dict[str, Any]] = []
        seen_ids: set[str] = set()
        for value in values:
            if not isinstance(value, dict):
                continue
            playlist_id = str(value.get("id") or uuid.uuid4().hex).strip()
            if not playlist_id or playlist_id in seen_ids:
                playlist_id = uuid.uuid4().hex
            seen_ids.add(playlist_id)
            name = str(value.get("name") or "Playlist").strip() or "Playlist"
            playlists.append({
                "id": playlist_id,
                "name": name,
                "tracks": self._normalizePlaylist(value.get("tracks", [])),
            })
        return playlists

    def _activePlaylistRecord(self) -> dict[str, Any] | None:
        return next(
            (playlist for playlist in getattr(self, "_playlists", [])
             if playlist["id"] == getattr(self, "_active_playlist_id", "")),
            None,
        )

    def _saveMidiPlaylist(self) -> None:
        midi_settings = configuration.configData["midiPlayer"]
        active_playlist = self._activePlaylistRecord()
        if active_playlist is not None:
            active_playlist["tracks"] = self._midi_playlist
        midi_settings["playlists"] = [
            {
                "id": playlist["id"],
                "name": playlist["name"],
                "tracks": list(playlist["tracks"]),
            }
            for playlist in self._playlists
        ]
        midi_settings["activePlaylistId"] = self._active_playlist_id
        midi_settings["playlist"] = list(self._midi_playlist)
        configuration.configData.save()

    @Slot()
    def createPlaylist(self) -> None:
        base_name = "Playlist"
        existing_names = {playlist["name"].casefold() for playlist in self._playlists}
        name = base_name
        suffix = 2
        while name.casefold() in existing_names:
            name = f"{base_name} {suffix}"
            suffix += 1

        self.cancelMidiPlaylist()
        playlist = {"id": uuid.uuid4().hex, "name": name, "tracks": []}
        self._playlists.append(playlist)
        self._active_playlist_id = playlist["id"]
        self._midi_playlist = playlist["tracks"]
        self._playlist_current_index = -1
        self._saveMidiPlaylist()
        self.playlistChanged.emit()

    @Slot(int)
    def selectPlaylist(self, index: int) -> None:
        index = int(index)
        if not 0 <= index < len(self._playlists):
            return
        playlist = self._playlists[index]
        if playlist["id"] == self._active_playlist_id:
            return
        self.cancelMidiPlaylist()
        self._active_playlist_id = playlist["id"]
        self._midi_playlist = playlist["tracks"]
        self._playlist_current_index = 0 if self._midi_playlist else -1
        self._saveMidiPlaylist()
        self.playlistChanged.emit()

    @Slot(int, str)
    def renamePlaylist(self, index: int, name: str) -> None:
        index = int(index)
        name = str(name or "").strip()
        if not name or not 0 <= index < len(self._playlists):
            return
        if self._playlists[index]["name"] == name:
            return
        self._playlists[index]["name"] = name
        self._saveMidiPlaylist()
        self.playlistChanged.emit()

    @Slot(int)
    def deletePlaylist(self, index: int) -> None:
        index = int(index)
        if not 0 <= index < len(self._playlists):
            return
        deleting_active = self._playlists[index]["id"] == self._active_playlist_id
        del self._playlists[index]
        if deleting_active:
            self.cancelMidiPlaylist()
            next_playlist = self._playlists[min(index, len(self._playlists) - 1)] if self._playlists else None
            self._active_playlist_id = next_playlist["id"] if next_playlist else ""
            self._midi_playlist = next_playlist["tracks"] if next_playlist else []
            self._playlist_current_index = 0 if self._midi_playlist else -1
        self._saveMidiPlaylist()
        self._refreshMidiLibrary()
        self.playlistChanged.emit()

    def _openPlaylistPicker(self) -> None:
        if getattr(self, "_playlist_dialog", None) is not None:
            self._playlist_dialog.raise_()
            self._playlist_dialog.activateWindow()
            return

        dialog = QFileDialog()
        dialog.setWindowTitle(self.translateText("Add MIDI files to playlist"))
        dialog.setNameFilter(self.translateText("MIDI files (*.mid *.midi)"))
        dialog.setFileMode(QFileDialog.FileMode.ExistingFiles)
        dialog.setAcceptMode(QFileDialog.AcceptMode.AcceptOpen)
        current_path = str(widgetProxy("midiPlayer", "filePathEntry").get() or "")
        start_directory = os.path.dirname(current_path) if os.path.isfile(current_path) else ""
        if start_directory:
            dialog.setDirectory(start_directory)
        dialog.filesSelected.connect(self._appendPlaylistPaths)
        dialog.finished.connect(lambda _result, current=dialog: self._clearPlaylistDialog(current))
        self._playlist_dialog = dialog
        dialog.open()

    def _clearPlaylistDialog(self, dialog: QFileDialog) -> None:
        if getattr(self, "_playlist_dialog", None) is dialog:
            self._playlist_dialog = None
        dialog.deleteLater()

    def _appendPlaylistPaths(self, paths: list[str]) -> None:
        changed = False
        selection_changed = False
        first_added = -1
        known_paths = {os.path.normcase(path) for path in self._midi_playlist}
        for value in paths:
            path = os.path.abspath(os.path.expanduser(str(value or "").strip()))
            if Path(path).suffix.lower() not in {".mid", ".midi"} or not os.path.isfile(path):
                continue
            key = os.path.normcase(path)
            if key in known_paths:
                selected = next(
                    index for index, queued in enumerate(self._midi_playlist)
                    if os.path.normcase(queued) == key
                )
                selection_changed = selection_changed or selected != self._playlist_current_index
                self._playlist_current_index = selected
                continue
            if key not in known_paths:
                if first_added < 0:
                    first_added = len(self._midi_playlist)
                self._midi_playlist.append(path)
                known_paths.add(key)
                changed = True

        if not changed and first_added < 0:
            if not selection_changed:
                return
        if self._playlist_current_index < 0 and first_added >= 0:
            self._playlist_current_index = first_added
            selection_changed = True
        if changed:
            self._saveMidiPlaylist()
            self._refreshMidiLibrary()
        self.playlistChanged.emit()

    @Slot()
    def addMidiFilesToPlaylist(self) -> None:
        self._openPlaylistPicker()

    @Slot()
    def addCurrentMidiToPlaylist(self) -> None:
        path = str(widgetProxy("midiPlayer", "filePathEntry").get() or "").strip()
        if os.path.isfile(path):
            self._appendPlaylistPaths([path])
        else:
            self._openPlaylistPicker()

    @Slot(int)
    def selectPlaylistTrack(self, index: int) -> None:
        index = int(index)
        if not 0 <= index < len(self._midi_playlist):
            return
        if self._playlist_current_index != index:
            self._playlist_current_index = index
            self.playlistChanged.emit()

    @Slot(int)
    def playPlaylistTrack(self, index: int) -> None:
        self._startPlaylistIndex(int(index))

    @Slot()
    def playPlaylist(self) -> None:
        index = self._playlist_current_index
        self._startPlaylistIndex(index if index >= 0 else 0)

    def _startPlaylistIndex(self, index: int) -> None:
        if not 0 <= index < len(self._midi_playlist):
            return

        while index < len(self._midi_playlist):
            path = self._midi_playlist[index]
            if os.path.isfile(path):
                break
            self.consoleRequested.emit(0, f"Playlist skipped missing MIDI: {Path(path).name}", False)
            index += 1
        else:
            self.cancelMidiPlaylist()
            return

        self._playlist_current_index = index
        self._playlist_playing_index = index
        self._playlist_active = True
        self._pending_playlist_path = path
        self._pending_playlist_index = index
        self.playlistChanged.emit()

        current_path = str(widgetProxy("midiPlayer", "filePathEntry").get() or "")
        if (
            os.path.normcase(os.path.abspath(current_path)) == os.path.normcase(path)
            and self._midi_duration_seconds > 0
        ):
            self._pending_playlist_path = ""
            self._pending_playlist_index = -1
            self.midiPlayer.startPlayback()
        else:
            self._queueMidiLoad(path, show_error=False)

    def _advanceMidiPlaylist(self) -> None:
        if not self._playlist_active:
            return
        next_index = self._playlist_playing_index + 1
        if next_index < len(self._midi_playlist):
            self._startPlaylistIndex(next_index)
            return

        self._playlist_active = False
        self._playlist_playing_index = -1
        self.playlistChanged.emit()
        self.consoleRequested.emit(0, "Playlist finished.", False)

    def cancelMidiPlaylist(self) -> None:
        changed = self._playlist_active or self._playlist_playing_index >= 0 or bool(self._pending_playlist_path)
        self._playlist_active = False
        self._playlist_playing_index = -1
        self._pending_playlist_path = ""
        self._pending_playlist_index = -1
        if changed:
            self.playlistChanged.emit()

    @Slot(int)
    def removePlaylistTrack(self, index: int) -> None:
        if not 0 <= index < len(self._midi_playlist):
            return
        del self._midi_playlist[index]
        if self._playlist_playing_index == index:
            self._playlist_active = False
            self._playlist_playing_index = -1
        elif self._playlist_playing_index > index:
            self._playlist_playing_index -= 1
        if self._pending_playlist_index == index:
            self._pending_playlist_path = ""
            self._pending_playlist_index = -1
            self._playlist_active = False
            self._playlist_playing_index = -1
        elif self._pending_playlist_index > index:
            self._pending_playlist_index -= 1
        if self._playlist_current_index == index:
            self._playlist_current_index = min(index, len(self._midi_playlist) - 1)
        elif self._playlist_current_index > index:
            self._playlist_current_index -= 1
        self._saveMidiPlaylist()
        self._refreshMidiLibrary()
        self.playlistChanged.emit()

    @Slot(int, int)
    def movePlaylistTrack(self, index: int, offset: int) -> None:
        index = int(index)
        target = index + int(offset)
        if not 0 <= index < len(self._midi_playlist) or not 0 <= target < len(self._midi_playlist):
            return
        self._midi_playlist[index], self._midi_playlist[target] = (
            self._midi_playlist[target], self._midi_playlist[index]
        )
        for attribute in (
            "_playlist_current_index",
            "_playlist_playing_index",
            "_pending_playlist_index",
        ):
            current = getattr(self, attribute)
            if current == index:
                setattr(self, attribute, target)
            elif current == target:
                setattr(self, attribute, index)
        self._saveMidiPlaylist()
        self.playlistChanged.emit()

    @Slot()
    def clearMidiPlaylist(self) -> None:
        self._midi_playlist.clear()
        self._playlist_current_index = -1
        self.cancelMidiPlaylist()
        self._saveMidiPlaylist()
        self._refreshMidiLibrary()
        self.playlistChanged.emit()

    def prepareMidiPlaylistPlayback(self, path: str) -> None:
        normalized = os.path.normcase(os.path.abspath(os.path.expanduser(str(path or "").strip())))
        index = next(
            (i for i, queued in enumerate(self._midi_playlist) if os.path.normcase(queued) == normalized),
            -1,
        )
        if index < 0:
            self.cancelMidiPlaylist()
            return
        self._playlist_current_index = index
        self._playlist_playing_index = index
        self._playlist_active = True
        self.playlistChanged.emit()

    def _queueMidiLoad(self, path: str, show_error: bool = True) -> None:
        path = os.path.abspath(os.path.expanduser(str(path).strip()))
        if not os.path.isfile(path):
            if show_error:
                self.dialogRequested.emit("MIDI file not found", path, "error")
            return

        playlist_load = bool(self._pending_playlist_path) and (
            os.path.normcase(self._pending_playlist_path) == os.path.normcase(path)
        )
        if not playlist_load:
            self.cancelMidiPlaylist()

        self._midi_load_generation += 1
        generation = self._midi_load_generation
        self._midi_show_errors[generation] = show_error
        self._setMidiLoading(True)
        widgetProxy("midiPlayer", "timelineIndicator").configure(text="Loading MIDI…")

        worker = MidiMetadataWorker(path, generation, self)
        worker.loaded.connect(self._onMidiLoaded)
        worker.failed.connect(self._onMidiLoadFailed)
        worker.finished.connect(lambda g=generation, w=worker: self._releaseMidiWorker(g, w))
        self._midi_workers[generation] = worker
        worker.start()

    def _setMidiLoading(self, loading: bool) -> None:
        loading = bool(loading)
        if self._midi_loading != loading:
            self._midi_loading = loading
            self.midiLoadingChanged.emit()

    def _formatMidiTimeline(self, duration: float) -> str:
        duration_text = str(datetime.timedelta(seconds=max(0, int(duration))))
        if configuration.configData.get("appUI", {}).get("timestamp", True):
            return f"0:00:00 / {duration_text}"
        return f"X:XX:XX / {duration_text}"

    @Slot(str, float, int)
    def _onMidiLoaded(self, path: str, duration: float, generation: int) -> None:
        if generation != self._midi_load_generation:
            return

        normalized_path = os.path.normcase(os.path.abspath(path))
        playlist_request = bool(self._pending_playlist_path) and (
            os.path.normcase(self._pending_playlist_path) == normalized_path
        )
        pending_index = self._pending_playlist_index
        if self.isRunning:
            self.midiPlayer.stopPlayback(cancelPlaylist=not playlist_request)

        if playlist_request:
            self._playlist_active = True
            self._playlist_current_index = pending_index
            self._playlist_playing_index = pending_index
            self._pending_playlist_path = ""
            self._pending_playlist_index = -1
        else:
            self._playlist_active = False
            self._playlist_playing_index = -1
            self._pending_playlist_path = ""
            self._pending_playlist_index = -1
            self._playlist_current_index = next(
                (index for index, queued in enumerate(self._midi_playlist)
                 if os.path.normcase(queued) == normalized_path),
                -1,
            )

        self._selectFileProxy("midiPlayer", "filePathEntry", path)
        midi_config = configuration.configData["midiPlayer"]
        midi_config["currentFile"] = path
        midi_list = list(midi_config.get("midiList", []) or [])
        if path not in midi_list:
            midi_list.append(path)
        midi_config["midiList"] = midi_list
        configuration.configData.save()
        self._refreshMidiLibrary()

        self._midi_duration_seconds = duration
        self.midiPlayer.setMidiDuration(duration)
        widgetProxy("midiPlayer", "timelineIndicator").configure(
            text=self._formatMidiTimeline(duration)
        )
        self.midiPlayer.bindControls()
        self._setMidiLoading(False)
        self._refreshSnapshot()
        self.playlistChanged.emit()
        if playlist_request:
            QTimer.singleShot(0, self.midiPlayer.startPlayback)

    @Slot(str, str, int)
    def _onMidiLoadFailed(self, path: str, error: str, generation: int) -> None:
        if generation != self._midi_load_generation:
            return

        normalized_path = os.path.normcase(os.path.abspath(path))
        failed_playlist_index = self._pending_playlist_index
        playlist_request = bool(self._pending_playlist_path) and (
            os.path.normcase(self._pending_playlist_path) == normalized_path
        )
        if playlist_request:
            self._pending_playlist_path = ""
            self._pending_playlist_index = -1

        previous_path = str(configuration.configData.get("midiPlayer", {}).get("currentFile", "") or "")
        if previous_path and os.path.isfile(previous_path):
            self._selectFileProxy("midiPlayer", "filePathEntry", previous_path)
        else:
            widgetProxy("midiPlayer", "filePathEntry").set("")
        widgetProxy("midiPlayer", "timelineIndicator").configure(
            text=self._formatMidiTimeline(self._midi_duration_seconds)
        )
        self._setMidiLoading(False)
        logger.error("Could not load MIDI file %s: %s", path, error)
        self.consoleRequested.emit(0, f"Could not load MIDI: {error}", False)
        if self._midi_show_errors.pop(generation, True):
            self.dialogRequested.emit("MIDI file could not be loaded", error, "error")
        self._refreshSnapshot()
        if playlist_request and self._playlist_active:
            self.consoleRequested.emit(0, f"Playlist skipped unreadable MIDI: {Path(path).name}", False)
            QTimer.singleShot(0, lambda: self._startPlaylistIndex(failed_playlist_index + 1))

    def _releaseMidiWorker(self, generation: int, worker: MidiMetadataWorker) -> None:
        self._midi_workers.pop(generation, None)
        self._midi_show_errors.pop(generation, None)
        worker.deleteLater()

    @Slot(str)
    def selectDrumFile(self, path: str = "") -> None:
        if path:
            self._selectFileProxy("drums", "midiPathDropdown", path)
            self.drums.switchMidiEvent()
        else:
            self.drums.selectFile()
        self._refreshSnapshot()

    def _selectFileProxy(self, page: str, field: str, path: str) -> None:
        proxy = widgetProxy(page, field)
        values = proxy.cget("values")
        if path not in values:
            values.append(path)
            proxy.configure(values=values)
        proxy.set(path)

    @Slot()
    def playMidi(self) -> None:
        self.midiPlayer.startPlayback()
        self._refreshSnapshot()

    @Slot()
    def pauseMidi(self) -> None:
        self.midiPlayer.pausePlayback()
        self._refreshSnapshot()

    @Slot()
    def stopMidi(self) -> None:
        self.midiPlayer.stopPlayback()
        self._refreshSnapshot()

    @Slot()
    def playDrums(self) -> None:
        self.drums.startPlayback()
        self._refreshSnapshot()

    @Slot()
    def pauseDrums(self) -> None:
        self.drums.pausePlayback()
        self._refreshSnapshot()

    @Slot()
    def stopDrums(self) -> None:
        self.drums.stopPlayback()
        self._refreshSnapshot()

    @Slot()
    def toggleInputListener(self) -> None:
        self.midiToQwerty.playButton()
        self._refreshSnapshot()

    @Slot(str, str, bool)
    def toggleFeature(self, section: str, key: str, enabled: bool) -> None:
        from modules.functions import settingsFunctions

        player_map = {
            "useMIDIOutput": (self.midiPlayer.switchUseMIDIvar, self.midiPlayer.switchUseMIDI),
            "sustain": (self.midiPlayer.switchSustainvar, self.midiPlayer.switchSustain),
            "noDoubles": (self.midiPlayer.switchNoDoublesvar, self.midiPlayer.switchNoDoubles),
            "velocity": (self.midiPlayer.switchVelocityvar, self.midiPlayer.switchVelocity),
            "88Keys": (self.midiPlayer.switch88Keysvar, self.midiPlayer.switch88Keys),
            "customHoldLength": (settingsFunctions.switchMidiCustomHoldLengthvar, settingsFunctions.switchMidiCustomHoldLength),
            "randomFail": (settingsFunctions.switchMidiRandomFailvar, settingsFunctions.switchMidiRandomFail),
            "loopSong": (settingsFunctions.switchMidiLoopSongvar, settingsFunctions.switchMidiLoopSong),
            "releaseOnPause": (settingsFunctions.switchMidiReleaseOnPausevar, settingsFunctions.switchMidiReleaseOnPause),
        }
        drums_map = {
            "customHoldLength": (settingsFunctions.switchDrumsCustomHoldLengthvar, settingsFunctions.switchDrumsCustomHoldLength),
            "randomFail": (settingsFunctions.switchDrumsRandomFailvar, settingsFunctions.switchDrumsRandomFail),
            "loopSong": (settingsFunctions.switchDrumsLoopSongvar, settingsFunctions.switchDrumsLoopSong),
            "releaseOnPause": (settingsFunctions.switchDrumsReleaseOnPausevar, settingsFunctions.switchDrumsReleaseOnPause),
        }
        qwerty_map = {
            "sustain": (self.midiToQwerty.switchSustainvar, self.midiToQwerty.switchSustain),
            "noDoubles": (self.midiToQwerty.switchNoDoublesvar, self.midiToQwerty.switchNoDoubles),
            "velocity": (self.midiToQwerty.switchVelocityvar, self.midiToQwerty.switchVelocity),
            "88Keys": (self.midiToQwerty.switch88Keysvar, self.midiToQwerty.switch88Keys),
            "customHoldLength": (self.midiToQwerty.switchCustomHoldLengthvar, self.midiToQwerty.switchCustomHoldLength),
        }
        app_map = {
            "topmost": (settingsFunctions.switchTopMostvar, settingsFunctions.switchTopMost),
            "console": (settingsFunctions.switchConsolevar, settingsFunctions.switchConsole),
            "tooltip": (settingsFunctions.switchToolTipvar, settingsFunctions.switchToolTip),
            "timestamp": (settingsFunctions.switchTimestampvar, settingsFunctions.switchTimestamp),
            "checkForUpdates": (settingsFunctions.switchCheckForUpdatesvar, settingsFunctions.switchCheckForUpdates),
        }
        selected = {
            "midiPlayer": player_map,
            "drumsMacro": drums_map,
            "midiToQwerty": qwerty_map,
            "appUI": app_map,
        }.get(section, {}).get(key)
        if selected:
            variable, action = selected
            variable.set("on" if enabled else "off")
            if section == "appUI" and key == "topmost":
                self._setConfigPath("appUI.topmost", enabled)
            else:
                action()
        else:
            self._setConfigPath(f"{section}.{key}", enabled)
        if section == "discordPresence":
            self._syncDiscordPresenceConfiguration()
        if section == "appUI" and key == "topmost" and self._window:
            self._window.setFlag(Qt.WindowType.WindowStaysOnTopHint, bool(enabled))
        self._refreshSnapshot()

    @Slot(str, "QVariant")
    def setControl(self, name: str, value: Any) -> None:
        control_name = str(name)
        timer = self._control_timers.get(control_name)
        if timer:
            timer.stop()
        self._pending_control_values.pop(control_name, None)
        self._applyControl(control_name, value, refresh=True)

    @Slot(str, "QVariant")
    def previewControl(self, name: str, value: Any) -> None:
        """Coalesce slider drags so disk writes and QML snapshots don't run per frame."""
        control_name = str(name)
        self._pending_control_values[control_name] = value
        timer = self._control_timers.get(control_name)
        if timer is None:
            timer = QTimer(self)
            timer.setSingleShot(True)
            timer.timeout.connect(lambda control_name=control_name: self._applyPendingControl(control_name))
            self._control_timers[control_name] = timer
        if not timer.isActive():
            timer.start(45)

    def _applyPendingControl(self, name: str) -> None:
        if name not in self._pending_control_values:
            return
        value = self._pending_control_values.pop(name)
        self._applyControl(name, value, refresh=False)

    def _applyControl(self, control_name: str, value: Any, refresh: bool) -> None:
        if control_name == "midiFingerLimit":
            self.settingsFunctions.changePianoFingerLimit(value)
        elif control_name == "drumsFingerLimit":
            self.settingsFunctions.changeDrumsFingerLimit(value)
        else:
            self.settingsFunctions.updateFromSlider(control_name, value)
        if control_name in ("midiSpeedController", "drumsSpeedController"):
            self._playback_speed = max(1, int(value))
            self.playbackSpeedChanged.emit()
        if refresh:
            self._refreshSnapshot()

    @Slot(str)
    def resetControl(self, name: str) -> None:
        self.settingsFunctions.resetControl(str(name))
        self._refreshSnapshot()

    @Slot(str, str)
    def setPitch(self, value: str, kind: str) -> None:
        if kind == "transpose":
            self.midiPlayer.changeTranspose(value)
        else:
            self.midiPlayer.changePitch(value)
        self._refreshSnapshot()

    @Slot(str, str, "QVariant")
    def setConfigValue(self, section: str, key: str, value: Any) -> None:
        route = {
            ("midiPlayer", "inputModule"): self.settingsFunctions.midiModuleSelect,
            ("drumsMacro", "inputModule"): self.settingsFunctions.drumsModuleSelect,
            ("midiToQwerty", "inputModule"): self.midiToQwerty.onModuleSelect,
        }
        action = route.get((section, key))
        if section == "discordPresence" and key == "applicationId":
            self.setDiscordApplicationId(str(value))
            return
        if action:
            action(str(value))
        else:
            self._setConfigPath(f"{section}.{key}", value)
        if section == "discordPresence":
            self._syncDiscordPresenceConfiguration()
        self._refreshSnapshot()

    def _setConfigPath(self, path: str, value: Any) -> None:
        parts = path.split(".")
        node = configuration.configData
        for part in parts[:-1]:
            node = node[part]
        node[parts[-1]] = value
        configuration.configData.save()

    @Slot(str)
    def setOutputDevice(self, value: str) -> None:
        widgetProxy("midiPlayer", "outputDeviceDropdown").set(value)

    @Slot(str)
    def setInputDevice(self, value: str) -> None:
        widgetProxy("midiToQwerty", "inputDeviceDropdown").set(value)

    @Slot(str)
    def setMidiFileValue(self, value: str) -> None:
        path = str(value).strip()
        if path and os.path.isfile(path):
            normalized = os.path.normcase(os.path.abspath(os.path.expanduser(path)))
            self._playlist_current_index = next(
                (index for index, queued in enumerate(self._midi_playlist)
                 if os.path.normcase(queued) == normalized),
                -1,
            )
            self.playlistChanged.emit()
            self._queueMidiLoad(path)
        elif path:
            self.dialogRequested.emit("MIDI file not found", path, "error")

    @Slot(str)
    def setDrumFileValue(self, value: str) -> None:
        widgetProxy("drums", "midiPathDropdown").set(value)
        if value and os.path.isfile(value):
            self.drums.switchMidiEvent()
        self._refreshSnapshot()

    @Slot(str)
    def setHotkey(self, key_type: str) -> None:
        from modules.functions import mainFunctions

        mainFunctions.setHotkey(str(key_type))

    @Slot()
    def refreshHotkeys(self) -> None:
        from modules.functions import mainFunctions

        if self.currentPage == 0:
            self.midiPlayer.bindControls()
        elif self.currentPage == 1:
            self.drums.bindControls()
        mainFunctions.clearConsole()
        self._refreshSnapshot()

    @Slot(str)
    def searchHub(self, query: str) -> None:
        widgetProxy("hub", "searchEntry").set(query)
        self.hub.filteredMidiData(query)

    @Slot(str)
    def sortHub(self, value: str) -> None:
        widgetProxy("hub", "sortComboBox").set(value)
        self.hub.sortComboCommand(value)

    @Slot()
    def reloadHub(self) -> None:
        self.hub.loadMidiData()

    @Slot()
    def previousHubPage(self) -> None:
        self.hub.prevPage()

    @Slot()
    def nextHubPage(self) -> None:
        self.hub.nextPage()

    @Slot(str)
    def downloadMidi(self, url: str) -> None:
        url = str(url or "")
        if not url or self._hub_download_states.get(url) == "downloading":
            return
        self._hub_download_states[url] = "downloading"
        self.hubChanged.emit()
        self.hub.downloadMidi(url)

    @Slot()
    def clearMidiList(self) -> None:
        self.settingsFunctions.midiClearMidiList()
        self._refreshSnapshot()

    @Slot()
    def clearDrumList(self) -> None:
        self.settingsFunctions.drumsClearMidiList()
        self._refreshSnapshot()

    @Slot()
    def openConsole(self) -> None:
        self.settingsFunctions.openConsole()

    @Slot()
    def closeConsole(self) -> None:
        self.settingsFunctions.closeConsole()

    @Slot(str)
    def setTheme(self, value: str) -> None:
        widgetProxy("settings", "themeSelector").set("Dark")
        theme = customTheme.switchTheme("Dark")
        self._current_theme = "Dark"
        self._theme_palette = self._buildThemePalette(theme)
        self.themeChanged.emit()
        self._refreshSnapshot()

    @Slot()
    def clearActivity(self) -> None:
        from modules.functions import mainFunctions

        mainFunctions.clearConsole()

    def refreshTheme(self, data: dict[str, Any]) -> None:
        self._theme_palette = self._buildThemePalette(data)
        self.themeChanged.emit()

    @Slot(str, str)
    def requestMessage(self, title: str, message: str) -> None:
        self.dialogRequested.emit(title, message, "info")

    @Slot(str, result=bool)
    def askYesNo(self, title: str, message: str) -> bool:
        # This is only used as a synchronous fallback. The updater normally
        # asks from its worker via confirmRequested and resolves asynchronously.
        if QThread.currentThread() != self.thread():
            return False
        box = QMessageBox(
            QMessageBox.Icon.Question,
            self.translateText(title),
            self.translateText(message),
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            self._window,
        )
        box.button(QMessageBox.StandardButton.Yes).setText(self.translateText("Yes"))
        box.button(QMessageBox.StandardButton.No).setText(self.translateText("No"))
        box.setDefaultButton(QMessageBox.StandardButton.No)
        return box.exec() == QMessageBox.StandardButton.Yes

    def focus_set(self) -> None:
        if self._window:
            self._window.requestActivate()

    def wm_attributes(self, attribute: str, value: Any) -> None:
        if attribute == "-topmost" and self._window:
            self._window.setFlag(Qt.WindowType.WindowStaysOnTopHint, bool(value))

    @Slot(int, str, bool)
    def _appendConsole(self, page: int, message: str, _ignore_console_check: bool = False) -> None:
        page_name = self.PAGE_NAMES.get(int(page), "midi")
        lines = self._console_lines.setdefault(page_name, [])
        lines.append(str(message))
        limits = {"midi": 8, "drums": 14, "miditoqwerty": 13}
        del lines[:-limits.get(page_name, 14)]
        self.consoleChanged.emit()

    @Slot(int)
    def _clearConsole(self, page: int) -> None:
        page_name = self.PAGE_NAMES.get(int(page), "midi")
        self._console_lines[page_name] = []
        self.consoleChanged.emit()

    @Slot(str, str, str)
    def _showDialog(self, title: str, message: str, kind: str) -> None:
        icon = {
            "warning": QMessageBox.Icon.Warning,
            "error": QMessageBox.Icon.Critical,
            "question": QMessageBox.Icon.Question,
        }.get(kind, QMessageBox.Icon.Information)
        box = QMessageBox(icon, self.translateText(title), self.translateText(message), QMessageBox.StandardButton.Ok, self._window)
        box.button(QMessageBox.StandardButton.Ok).setText(self.translateText("OK"))
        box.exec()

    @Slot(str, str, object)
    def _confirm(self, title: str, message: str, callback: Any) -> None:
        box = QMessageBox(
            QMessageBox.Icon.Question,
            self.translateText(title),
            self.translateText(message),
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            self._window,
        )
        yes_button = box.button(QMessageBox.StandardButton.Yes)
        no_button = box.button(QMessageBox.StandardButton.No)
        yes_button.setText(self.translateText("Yes"))
        no_button.setText(self.translateText("No"))
        box.setDefaultButton(QMessageBox.StandardButton.No)
        answer = box.exec()
        if callable(callback):
            callback(answer == QMessageBox.StandardButton.Yes)

    @Slot(object)
    def _applyHubState(self, data: dict[str, Any]) -> None:
        startup_state_changed = False
        if "results" in data:
            self._hub_results = list(data.get("results") or [])
            if self._presence_mode in {"playing", "paused"} and self._presence_source == "midi":
                self._publishDiscordPresence()
            self._playlist_cover_cache.clear()
            self.playlistChanged.emit()
        if "downloads" in data:
            for url, state in dict(data.get("downloads") or {}).items():
                url = str(url)
                state = str(state)
                if state not in {"downloading", "complete", "error"}:
                    continue
                self._hub_download_states[url] = state
                if state != "downloading":
                    QTimer.singleShot(1600, lambda key=url, expected=state: self._clearHubDownloadState(key, expected))
        if "loading" in data:
            self._hub_loading = bool(data["loading"])
        if "error" in data:
            self._hub_error = str(data.get("error") or "")
        if "notice" in data:
            self._hub_notice = str(data.get("notice") or "")
        if "page" in data:
            self._hub_page = int(data.get("page") or 1)
        if "totalPages" in data:
            self._hub_total_pages = max(1, int(data.get("totalPages") or 1))
        if "resultCount" in data:
            self._hub_result_count = int(data.get("resultCount") or 0)
        if "startupProgress" in data:
            self._startup_progress = max(0, min(100, int(data.get("startupProgress") or 0)))
            startup_state_changed = True
        if "startupStatus" in data:
            self._startup_status = str(data.get("startupStatus") or "Preparing MIDI Hub…")
            startup_state_changed = True
        if "startupReady" in data:
            self._startup_ready = bool(data.get("startupReady"))
            startup_state_changed = True
        self.hubChanged.emit()
        if startup_state_changed:
            self.startupChanged.emit()

    def _clearHubDownloadState(self, url: str, expected_state: str) -> None:
        if self._hub_download_states.get(url) == expected_state:
            del self._hub_download_states[url]
            self.hubChanged.emit()

    @Slot(str)
    def _scheduleDownloadedMidiOpen(self, filepath: str) -> None:
        QTimer.singleShot(520, lambda path=str(filepath): self._openDownloadedMidi(path))

    @Slot(str)
    def _openDownloadedMidi(self, filepath: str) -> None:
        self._queueMidiLoad(filepath)
        self.showFrame("midi")

    @Slot()
    def loadInfo(self) -> None:
        try:
            about_name = "ABOUT.pt.md" if self._language == "pt" else "ABOUT.md"
            content = Path(customTheme.resourcePath(f"assets/{about_name}")).read_text(encoding="utf-8")
            html_text = markdown.markdown(content, extensions=["extra", "toc", "tables", "fenced_code"])
        except Exception:
            logger.exception("Couldn't load Better NanoMidi About content")
            html_text = (
                "<h2>Better NanoMidi</h2>"
                "<p>Um fork independente do nanoMIDIPlayer, de NotHammer043 e seus colaboradores.</p>"
                "<p>Distribuído sob a licença GNU GPL v3. Consulte o arquivo LICENSE para ver os termos completos.</p>"
                if self._language == "pt" else
                "<h2>Better NanoMidi</h2>"
                "<p>An independent fork of nanoMIDIPlayer by NotHammer043 and its contributors.</p>"
                "<p>Licensed under GNU GPL v3. See the bundled LICENSE for the full terms.</p>"
            )
        self._infoRequested.emit(html_text)

    @Slot(str)
    def openExternalLink(self, url: str) -> None:
        webbrowser.open(str(url))

    @Slot()
    def openAccessibilitySettings(self) -> None:
        if platform.system() == "Darwin":
            from ui.darwinPermission import openAccessibilitySettings

            openAccessibilitySettings()

    @Slot()
    def openInputMonitoringSettings(self) -> None:
        if platform.system() == "Darwin":
            from ui.darwinPermission import openInputMonitoringSettings

            openInputMonitoringSettings()

    @Slot(str)
    def _applyInfo(self, content: str) -> None:
        self._info_html = str(content)
        self.infoChanged.emit()

    @Slot()
    def quit(self) -> None:
        from PySide6.QtWidgets import QApplication

        self.shutdownDiscordPresence()
        QApplication.quit()

    @Slot()
    def shutdownDiscordPresence(self) -> None:
        self._discord_presence.shutdown()
