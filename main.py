"""nanoMIDIPlayer desktop entry point (PySide6 + Qt Quick)."""

from __future__ import annotations

import argparse
import datetime
import errno
import logging
import os
import signal
import sys
import time
from pathlib import Path
from modules.app_info import APP_VERSION


# A one-file PyInstaller bundle extracts Qt and Shiboken DLLs beside the
# packaged Python modules. Register their directories before importing Qt so
# Windows cannot resolve QtCore dependencies from another installation.
_dll_directory_handles = []
if sys.platform == "win32" and getattr(sys, "frozen", False):
    _bundle_root = Path(sys._MEIPASS)
    for _dll_directory in (_bundle_root, _bundle_root / "PySide6", _bundle_root / "shiboken6"):
        if _dll_directory.is_dir():
            _dll_directory_handles.append(os.add_dll_directory(os.fspath(_dll_directory)))

# Keep the Basic Controls appearance without importing the optional
# PySide6.QtQuickControls2 Python binding into the portable build.
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

from PySide6.QtCore import QUrl
from PySide6.QtGui import QColor, QFont, QFontDatabase, QIcon, QPalette
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication


APP_DIR = Path(__file__).resolve().parent
logger = logging.getLogger("nanoMIDIPlayer")


class FlushFileHandler(logging.FileHandler):
    def emit(self, record: logging.LogRecord) -> None:
        super().emit(record)
        self.flush()


def _safe_delete(filepath: Path, retries: int = 3, delay: float = 0.1) -> bool:
    for attempt in range(retries):
        try:
            filepath.unlink(missing_ok=True)
            return True
        except PermissionError:
            if attempt < retries - 1:
                time.sleep(delay)
        except OSError as exc:
            if exc.errno == errno.ENOENT:
                return True
            if attempt < retries - 1:
                time.sleep(delay)
    return False


def init_logging() -> Path:
    log_dir = Path.home() / "Documents" / "nanoMIDIPlayer" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    old_logs = sorted(
        (path for path in log_dir.glob("nanoMIDIPlayer_*.log") if path.is_file()),
        key=lambda path: path.stat().st_mtime,
    )
    for path in old_logs[:-9]:
        _safe_delete(path)

    log_file = log_dir / f"nanoMIDIPlayer_{datetime.datetime.now():%Y-%m-%d_%H-%M-%S}.log"
    handlers: list[logging.Handler] = [FlushFileHandler(log_file, encoding="utf-8")]
    if sys.stdout:
        handlers.append(logging.StreamHandler(sys.stdout))
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=handlers,
        force=True,
    )
    logging.getLogger("nanoMIDIPlayer").info("Logging initialized: %s", log_file)
    return log_file


def main() -> int:
    os.chdir(APP_DIR)
    parser = argparse.ArgumentParser(description="nanoMIDIPlayer")
    parser.add_argument("--debug", action="store_true", help="open the in-app activity console")
    args = parser.parse_args()

    log_file = init_logging()
    logger.info("Starting %s from %s", APP_VERSION, APP_DIR)

    # Import after QApplication exists: Qt widgets such as native file dialogs
    # need an active GUI application before any MIDI service can request them.
    qt_app = QApplication(sys.argv)
    qt_app.setApplicationName("nanoMIDIPlayer")
    qt_app.setApplicationVersion(APP_VERSION)
    qt_app.setOrganizationName("nanoMIDIPlayer")
    qt_app.setStyle("Fusion")
    font_id = QFontDatabase.addApplicationFont(str(APP_DIR / "assets" / "fonts" / "Inter-Variable.ttf"))
    if font_id >= 0:
        font_families = QFontDatabase.applicationFontFamilies(font_id)
        if font_families:
            qt_app.setFont(QFont(font_families[0], 10))
    palette = qt_app.palette()
    for role, color in {
        QPalette.ColorRole.Window: "#141210",
        QPalette.ColorRole.WindowText: "#e9e1d8",
        QPalette.ColorRole.Base: "#141210",
        QPalette.ColorRole.AlternateBase: "#1d1a17",
        QPalette.ColorRole.ToolTipBase: "#25211d",
        QPalette.ColorRole.ToolTipText: "#e9e1d8",
        QPalette.ColorRole.Text: "#d9cfc4",
        QPalette.ColorRole.Button: "#25211d",
        QPalette.ColorRole.ButtonText: "#e9e1d8",
        QPalette.ColorRole.Highlight: "#b76b4d",
        QPalette.ColorRole.HighlightedText: "#ffffff",
    }.items():
        palette.setColor(role, QColor(color))
    qt_app.setPalette(palette)
    qt_app.setWindowIcon(QIcon(str(APP_DIR / "assets" / "branding" / "better-nanomidi" / "BetterNanoMidi.ico")))

    from modules import configuration
    from ui.controller import AppController

    controller = AppController()
    qt_app.aboutToQuit.connect(controller.shutdownDiscordPresence)
    if args.debug:
        controller.openConsole()
        controller.requestMessage("Activity console", f"Logs are written to {log_file}")

    if sys.platform == "darwin":
        from modules.functions import mainFunctions

        mainFunctions.startGlobalListener()

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(APP_DIR / "ui" / "qml"))
    engine.rootContext().setContextProperty("controller", controller)
    qml_file = APP_DIR / "ui" / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))
    if not engine.rootObjects():
        logger.critical("Could not load QML interface: %s", qml_file)
        return 2

    window = engine.rootObjects()[0]
    controller.attachWindow(window)
    controller.beginStartupWarmup()
    logger.info("Qt Quick interface loaded")

    if configuration.configData["appUI"].get("sendTelemetry", False):
        import threading
        from modules import telemetry

        threading.Thread(target=telemetry.startPing, name="telemetry", daemon=True).start()

    return qt_app.exec()


if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda *_args: QApplication.quit())
    raise SystemExit(main())
