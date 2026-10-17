# Contributing

Better NanoMidi is an independent fork of nanoMIDIPlayer. Keep the original copyright and license notices when editing inherited code, and add third-party license details to `THIRD_PARTY_NOTICES.md` when introducing a dependency or asset.

## Development

1. Use Python 3.12 and install `requirements.txt` in a virtual environment.
2. Keep presentation and interaction changes in `ui/qml/`; keep application and device behavior in Python.
3. Run the platform build script for changes to packaging, QML resources, or dependencies.
4. Keep generated builds, local MIDI files, user settings, and credentials out of commits.
5. Describe affected platforms and manual verification steps in change summaries.

The project currently builds Windows, macOS Intel, macOS Apple silicon, and Linux artifacts through GitHub Actions.
