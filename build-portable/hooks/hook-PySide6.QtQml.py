"""Collect only the QML components listed by the portable build spec."""

from PyInstaller.utils.hooks.qt import add_qt6_dependencies

hiddenimports, binaries, datas = add_qt6_dependencies(__file__)

# QML debugger plugins are development tools and pull in Qt Quick 3D support.
binaries = [
    entry
    for entry in binaries
    if not any("/qmltooling/" in str(part).replace("\\", "/").lower() for part in entry[:2])
]
