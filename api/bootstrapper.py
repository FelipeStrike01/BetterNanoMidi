"""Small Qt updater window for the Windows release bootstrapper."""

from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

import requests
from PySide6.QtCore import QThread, QTimer, Qt, Signal
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication, QLabel, QProgressBar, QVBoxLayout, QWidget
from modules.app_info import GITHUB_REPOSITORY


URL = (
    f"https://github.com/{GITHUB_REPOSITORY}/releases/latest/download/Better%20NanoMid.exe"
    if GITHUB_REPOSITORY else ""
)
OUTPUT_PATH = Path.cwd() / "Better NanoMid.exe"


class DownloadThread(QThread):
    progress = Signal(int, float)
    completed = Signal(str)
    failed = Signal(str)

    def run(self) -> None:
        downloaded = 0
        started = time.monotonic()
        try:
            if not URL:
                raise RuntimeError("The Better NanoMidi release repository has not been configured yet.")

            response = requests.get(URL, stream=True, timeout=30)
            response.raise_for_status()
            size = int(response.headers.get("content-length") or 0)
            with OUTPUT_PATH.open("wb") as target:
                for chunk in response.iter_content(chunk_size=64 * 1024):
                    if not chunk:
                        continue
                    target.write(chunk)
                    downloaded += len(chunk)
                    speed = downloaded / max(time.monotonic() - started, 0.1) / 1024
                    percent = int(downloaded * 100 / size) if size else 0
                    self.progress.emit(percent, speed)
            if downloaded == 0:
                raise RuntimeError("The server returned an empty update file.")
            self.completed.emit(str(OUTPUT_PATH))
        except Exception as exc:
            self.failed.emit(str(exc))


class BootstrapperWindow(QWidget):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Better NanoMidi updater")
        self.setWindowIcon(QIcon(str(Path(__file__).resolve().parents[1] / "assets" / "branding" / "better-nanomidi" / "BetterNanoMidi.ico")))
        self.setFixedSize(420, 220)
        self.setStyleSheet("""
            QWidget { background: #0b1016; color: #e8eef1; font-family: Inter, 'Segoe UI', sans-serif; }
            QLabel#brand { color: #eff6f8; font-size: 17px; font-weight: 650; }
            QLabel#status { color: #9aabb5; font-size: 12px; }
            QProgressBar { height: 8px; border: 0; border-radius: 4px; background: #202b34; text-align: center; }
            QProgressBar::chunk { border-radius: 4px; background: #48cbd4; }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(28, 24, 28, 22)
        layout.setSpacing(17)
        brand = QLabel("Better NanoMidi")
        brand.setObjectName("brand")
        brand.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status = QLabel("Downloading the latest version…")
        self.status.setObjectName("status")
        self.status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        layout.addWidget(brand)
        layout.addWidget(self.status)
        layout.addWidget(self.progress_bar)

        self.worker = DownloadThread(self)
        self.worker.progress.connect(self.update_progress)
        self.worker.completed.connect(self.start_update)
        self.worker.failed.connect(self.show_error)
        self.worker.start()

    def update_progress(self, percent: int, speed: float) -> None:
        self.progress_bar.setValue(max(0, min(100, percent)))
        self.status.setText(f"Downloading… {percent}% · {speed:.1f} KB/s")

    def start_update(self, filepath: str) -> None:
        self.progress_bar.setValue(100)
        self.status.setText("Download complete. Starting the app in a moment…")
        QTimer.singleShot(1800, lambda: self.launch(filepath))

    def launch(self, filepath: str) -> None:
        try:
            subprocess.Popen([filepath], creationflags=getattr(subprocess, "CREATE_NEW_CONSOLE", 0))
            QApplication.quit()
        except OSError as exc:
            self.show_error(str(exc))

    def show_error(self, error: str) -> None:
        self.status.setText(f"Update failed: {error}")
        self.progress_bar.setValue(0)


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("Better NanoMidi updater")
    window = BootstrapperWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
