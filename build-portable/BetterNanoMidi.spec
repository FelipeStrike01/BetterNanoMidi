# -*- mode: python ; coding: utf-8 -*-
from pathlib import Path
import PySide6

project = Path(SPECPATH).parent.resolve()
pyside_root = Path(PySide6.__file__).resolve().parent
qml_root = pyside_root / "qml"

# PySide6's catch-all package collector was bundling WebEngine, Qt3D, every
# translation and every QML style. Keep just the Python modules reached by
# Analysis plus the QML components used by the app's imports.
datas = [
    (str(project / "assets"), "assets"),
    (str(project / "ui" / "qml"), "ui/qml"),
]
binaries = []


def add_qml_files(relative_dir, recursive=True):
    source_dir = qml_root / relative_dir
    if not source_dir.is_dir():
        raise FileNotFoundError(f"Required Qt Quick module is missing: {source_dir}")
    iterator = source_dir.rglob("*") if recursive else source_dir.iterdir()
    for source in iterator:
        if not source.is_file():
            continue
        destination = Path("PySide6") / "qml" / source.relative_to(qml_root).parent
        entry = (str(source), str(destination))
        if source.suffix.lower() in {".dll", ".pyd"}:
            binaries.append(entry)
        else:
            datas.append(entry)


# Core QML modules and the Basic Controls style selected in main.py.
add_qml_files("QtQml", recursive=False)
add_qml_files("QtQml/Models")
add_qml_files("QtQml/WorkerScript")
add_qml_files("QtQuick", recursive=False)
add_qml_files("QtQuick/Controls", recursive=False)
for module in (
    "QtQuick/Controls/Basic",
    "QtQuick/Controls/impl",
    "QtQuick/Templates",
    "QtQuick/Layouts",
    "QtQuick/Window",
    "QtQuick/Effects",
):
    add_qml_files(module)

hiddenimports = [
    "mido.backends.rtmidi",
    "PySide6.QtQml",
    "PySide6.QtQuick",
    "pypresence",
]

analysis = Analysis(
    [str(project / "main.py")],
    pathex=[str(project)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[str(project / "build-portable" / "hooks")],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        "PySide6.QtWebEngineCore",
        "PySide6.QtWebEngineWidgets",
        "PySide6.QtWebEngineQuick",
        "PySide6.Qt3DCore",
        "PySide6.Qt3DRender",
        "PySide6.QtCharts",
        "PySide6.QtDataVisualization",
        "PySide6.QtGraphs",
        "PySide6.QtMultimedia",
        "PySide6.QtQuick3D",
        "PySide6.QtPdf",
        "PySide6.QtPdfWidgets",
        "PIL",
    ],
    noarchive=False,
    optimize=1,
)

# The workspace PATH exposes private UCRT and ICU DLLs from unrelated image
# processing and Poppler packages. QtCore expects the Windows ICU ABI; keeping
# the versioned Poppler ICU ahead of System32 makes QtCore fail to load.
system_runtime_names = {"ucrtbase.dll", "icuuc.dll", "icudt78.dll"}
optional_graphics_names = {
    # Qt Quick defaults to Direct3D 11 on Windows. Keep Qt's native graphics
    # backend, but omit optional OpenGL and unused Python wrappers. The QML
    # Controls plugin uses Qt6QuickControls2.dll, collected from its dependency.
    "opengl32sw.dll",
    "qtopengl.pyd",
    "qtquickcontrols2.pyd",
}
analysis.binaries = [
    entry
    for entry in analysis.binaries
    if Path(entry[0]).name.lower() not in system_runtime_names | optional_graphics_names
]

pyz = PYZ(analysis.pure)

exe = EXE(
    pyz,
    analysis.scripts,
    analysis.binaries,
    analysis.datas,
    [],
    name="Better NanoMid",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    # Qt DLLs are built with Control Flow Guard; UPX would require disabling it.
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=[str(project / "assets" / "branding" / "better-nanomidi" / "BetterNanoMidi.ico")],
)
