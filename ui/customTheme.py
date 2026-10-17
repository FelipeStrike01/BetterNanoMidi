"""Theme data loader shared by the PySide6/QML interface and MIDI services."""

from __future__ import annotations

import json
import os
import sys

from modules import configuration


def resourcePath(relativePath: str) -> str:
    root = getattr(sys, "_MEIPASS", os.path.abspath("."))
    return os.path.join(root, relativePath)


documentsDir = os.path.join(os.path.expanduser("~"), "Documents")
baseDirectory = os.path.join(documentsDir, "nanoMIDIPlayer")
activeThemePath = os.path.join(baseDirectory, "assets", "activeTheme.json")
defaultThemePath = resourcePath("assets/defaultTheme.json")


def _load_json(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as theme_file:
            data = json.load(theme_file)
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def getDefaultTheme() -> dict:
    return _load_json(defaultThemePath)


def saveTheme(data: dict) -> None:
    global activeThemeData
    activeThemeData = data if isinstance(data, dict) else getDefaultTheme()
    os.makedirs(os.path.dirname(activeThemePath), exist_ok=True)
    temporary_path = f"{activeThemePath}.tmp"
    with open(temporary_path, "w", encoding="utf-8") as theme_file:
        json.dump(activeThemeData, theme_file, indent=2)
    os.replace(temporary_path, activeThemePath)


def loadDefaultTheme() -> dict:
    """Return the single bundled Dark theme."""
    fallback = getDefaultTheme() or {"Name": "Dark", "Theme": {}}
    saveTheme(fallback)
    return fallback


def loadTheme() -> dict:
    # Ignore previously selected remote/custom themes so upgrades consistently
    # start with the one supported application theme.
    configuration.configData["appUI"]["forceTheme"] = False
    return loadDefaultTheme()


activeThemeData = loadTheme()
globalFont11 = globalFont12 = globalFont14 = globalFont20 = globalFont40 = "Inter"


def initializeFonts() -> None:
    return None


def fetchThemes() -> list[str]:
    return ["Dark"]


def switchTheme(value: str) -> dict:
    """Keep the application on its only supported theme and refresh QML."""
    global activeThemeData
    configuration.configData["appUI"]["forceTheme"] = False
    data = getDefaultTheme() or {"Name": "Dark", "Theme": {}}
    saveTheme(data)

    try:
        from modules.functions import mainFunctions

        app = mainFunctions.getApp()
        if app and hasattr(app, "refreshTheme"):
            app.refreshTheme(activeThemeData)
    except Exception:
        pass
    return activeThemeData


def reload() -> dict:
    global activeThemeData
    activeThemeData = loadTheme()
    return activeThemeData
