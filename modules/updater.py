"""Update checks with prompts routed through the live Qt application."""

from __future__ import annotations

import os
import subprocess
import tempfile
import threading
import webbrowser

import requests

from modules.functions import mainFunctions
from modules.app_info import GITHUB_REPOSITORY


VERSION_URL = (
    f"https://raw.githubusercontent.com/{GITHUB_REPOSITORY}/refs/heads/main/api/version.json"
    if GITHUB_REPOSITORY else ""
)
BOOTSTRAPPER_URL = (
    f"https://github.com/{GITHUB_REPOSITORY}/raw/refs/heads/main/api/bootstrapper.exe"
    if GITHUB_REPOSITORY else ""
)
RELEASES_URL = f"https://github.com/{GITHUB_REPOSITORY}/releases/latest" if GITHUB_REPOSITORY else ""


def checkForUpdates(appVersion: str) -> tuple[str, str]:
    if not VERSION_URL:
        return "none", ""

    try:
        response = requests.get(VERSION_URL, timeout=8)
        response.raise_for_status()
        version_info = response.json()
        latest_versions = version_info.get("latest", [])
        avoid_versions = version_info.get("avoid", [])
        alert_message = version_info.get("alertMessage", "")
        if appVersion in avoid_versions:
            return "urgent", alert_message
        if appVersion not in latest_versions:
            return "update", ""
    except requests.RequestException:
        pass
    return "none", ""


def _downloadBootstrapper() -> None:
    if not BOOTSTRAPPER_URL:
        mainFunctions.showMessage(
            "Updater unavailable",
            "The Better NanoMidi release repository has not been configured yet.",
            "warning",
        )
        return

    file_path = os.path.join(tempfile.gettempdir(), "BetterNanoMidi-bootstrapper.exe")
    try:
        mainFunctions.showMessage(
            "Downloading updater",
            "Downloading the updater. If Windows blocks it, check your antivirus quarantine.",
            "info",
        )
        response = requests.get(BOOTSTRAPPER_URL, timeout=30)
        response.raise_for_status()
        with open(file_path, "wb") as file:
            file.write(response.content)
        mainFunctions.showMessage("Download complete", "The updater will start now.", "info")
        subprocess.Popen(file_path, creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))
        os._exit(0)
    except Exception as exc:
        mainFunctions.showMessage("Update failed", f"Couldn't download or start the updater: {exc}", "error")


def downloadBootstrapper() -> None:
    threading.Thread(target=_downloadBootstrapper, name="updater-download", daemon=True).start()


def runUpdater(appVersion: str) -> None:
    update_status, urgent_message = checkForUpdates(appVersion)
    if update_status == "urgent":
        mainFunctions.showMessage("Critical update required", urgent_message, "warning")
        if RELEASES_URL:
            webbrowser.open(RELEASES_URL)
    elif update_status == "update":
        app = mainFunctions.getApp()
        if app and hasattr(app, "confirmRequested"):
            response: list[bool] = []
            finished = threading.Event()

            def resolve(accepted: bool) -> None:
                response.append(bool(accepted))
                finished.set()

            app.confirmRequested.emit(
                "Update available",
                "A new version of nanoMIDIPlayer is available. Would you like to update now?",
                resolve,
            )
            if finished.wait(300) and response and response[0]:
                downloadBootstrapper()
        elif mainFunctions.askYesNo("Update available", "A new version is available. Update now?"):
            downloadBootstrapper()
