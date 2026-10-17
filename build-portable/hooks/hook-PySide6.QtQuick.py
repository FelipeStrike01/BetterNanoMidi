"""The QML runtime uses QtQuick's C++ OpenGL backend, not its Python API."""

from PyInstaller.utils.hooks.qt import add_qt6_dependencies

hiddenimports, binaries, datas = add_qt6_dependencies(__file__)
hiddenimports = [name for name in hiddenimports if name != "PySide6.QtOpenGL"]
