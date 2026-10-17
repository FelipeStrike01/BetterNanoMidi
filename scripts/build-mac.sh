#!/bin/bash
set -e

ARCH="arm"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 --arch [intel|arm]"
            exit 1
            ;;
    esac
done

if [[ "$ARCH" != "intel" && "$ARCH" != "arm" ]]; then
    echo "Invalid architecture: $ARCH"
    exit 1
fi

echo "Building Better NanoMidi for macOS ($ARCH)"

rm -rf ./build ./dist ./venv-mac
mkdir -p build dist

python3 -m venv venv-mac
source ./venv-mac/bin/activate
pip install --upgrade pip setuptools wheel pyinstaller
pip install -r requirements.txt
python scripts/compile_shaders.py

if [[ "$ARCH" == "intel" ]]; then
    TARGET_ARCH="x86_64"
    DMG_NAME="BetterNanoMidi-Intel.dmg"
else
    TARGET_ARCH="arm64"
    DMG_NAME="BetterNanoMidi-ARM.dmg"
fi

pyinstaller --onefile --noconsole --noconfirm \
    --target-architecture "$TARGET_ARCH" \
    --hidden-import=mido.backends.rtmidi \
    --hidden-import=PySide6.QtQml \
    --hidden-import=PySide6.QtQuick \
    --hidden-import=PySide6.QtQuickControls2 \
    --collect-all PySide6 \
    --add-data="assets:assets" \
    --add-data="ui/qml:ui/qml" \
    --paths="." \
    --name="BetterNanoMidi" \
    --icon="assets/branding/better-nanomidi/BetterNanoMidi.ico" \
    main.py

chmod +x dist/BetterNanoMidi.app
mkdir -p dist/macOS-$ARCH
mv dist/BetterNanoMidi.app dist/macOS-$ARCH/
ln -s /Applications dist/macOS-$ARCH || true

if ! command -v create-dmg &> /dev/null; then
    brew install create-dmg
fi

rm -f dist/$DMG_NAME

create-dmg \
    --volname "Better NanoMidi" \
    --volicon "assets/branding/better-nanomidi/BetterNanoMidi.ico" \
    --background "assets/icons/integrated/dmgbackground.png" \
    --window-pos 200 120 \
    --window-size 625 400 \
    --icon-size 128 \
    --icon "BetterNanoMidi.app" 150 200 \
    --hide-extension "BetterNanoMidi.app" \
    --app-drop-link 475 200 \
    "dist/$DMG_NAME" \
    "dist/macOS-$ARCH/BetterNanoMidi.app"

rm -rf __pycache__ build venv-mac *.spec
echo "Build complete: dist/$DMG_NAME"
