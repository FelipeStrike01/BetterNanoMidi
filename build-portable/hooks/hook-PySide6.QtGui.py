"""Keep Qt image/platform plugins used by this app; skip PDF and virtual keyboard."""

from pathlib import PurePath

from PyInstaller.utils.hooks.qt import add_qt6_dependencies

hiddenimports, binaries, datas = add_qt6_dependencies(__file__)

optional_plugins = {"qpdf.dll", "qtvirtualkeyboardplugin.dll"}
binaries = [
    entry
    for entry in binaries
    if not any(PurePath(str(part)).name.lower() in optional_plugins for part in entry[:2])
]
