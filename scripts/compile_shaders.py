"""Compile QML ShaderEffect shaders into Qt Shader Baker (.qsb) packages."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import PySide6


ROOT = Path(__file__).resolve().parents[1]
SHADER_DIR = ROOT / "ui" / "qml" / "shaders"


def find_qsb() -> str:
    executable = "qsb.exe" if sys.platform == "win32" else "qsb"
    bundled = Path(PySide6.__file__).resolve().parent / executable
    if bundled.is_file():
        return str(bundled)

    candidate = shutil.which("pyside6-qsb")
    if candidate:
        return candidate
    launcher = "pyside6-qsb.exe" if sys.platform == "win32" else "pyside6-qsb"
    adjacent = Path(sys.executable).resolve().parent / launcher
    if adjacent.exists():
        return str(adjacent)
    raise SystemExit("pyside6-qsb is unavailable; install the PySide6 build dependencies first")


def compile_shader(qsb: str, source: str, targets: tuple[str, ...]) -> None:
    path = SHADER_DIR / source
    output = path.with_suffix(path.suffix + ".qsb")
    command = [qsb, "--hlsl", "50", "--msl", "12", "--glsl", ",".join(targets), "-o", str(output), str(path)]
    print(f"Compiling {path.relative_to(ROOT)}")
    subprocess.run(command, check=True)


def main() -> None:
    qsb = find_qsb()
    compile_shader(qsb, "plasma.frag", ("100 es", "120", "150"))


if __name__ == "__main__":
    main()
