#!/bin/bash
set -euo pipefail

echo "=> Cleaning up previous builds..."
rm -rf ./build/
rm -rf ./dist/
mkdir build
mkdir dist

echo "=> Creating virtual environment..."
python3 -m venv venv-lnx

echo "=> Activating virtual environment..."
source ./venv-lnx/bin/activate

echo "=> Installing dependencies via pip..."
venv-lnx/bin/pip install --upgrade pip pyinstaller
venv-lnx/bin/pip install -r requirements.txt
python scripts/compile_shaders.py

echo "=> Running PyInstaller to create binary..."
pyinstaller --onefile --noconsole --noconfirm \
    --hidden-import=mido.backends.rtmidi \
    --hidden-import=PySide6.QtQml \
    --hidden-import=PySide6.QtQuick \
    --hidden-import=PySide6.QtQuickControls2 \
    --collect-all PySide6 \
    --add-data="assets/:assets" \
    --add-data="ui/qml/:ui/qml" \
    --paths="." \
    --name=BetterNanoMidi \
    --icon="assets/branding/better-nanomidi/BetterNanoMidi.ico" \
    main.py

echo " => Packaging executable as tar.gz archive..."
cd dist
tar -czvf BetterNanoMidi.tar.gz BetterNanoMidi
cd ..

echo " => Cleaning up temporary files..."
rm -rf __pycache__ build venv-lnx *.spec

echo " => Done! Packaged tar.gz is available in 'dist/BetterNanoMidi.tar.gz'."
