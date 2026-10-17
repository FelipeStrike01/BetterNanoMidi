# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

People who use MIDI files to play virtual pianos, keyboard games, or MIDI instruments. They need reliable playback and control while the target piano or instrument is in another application.

## Product Purpose

nanoMIDIPlayer plays MIDI files by simulating QWERTY key presses or sending events to a selected MIDI output. It also maps incoming MIDI input to QWERTY keys. Success means users can select a song, configure its playback, and run or control it reliably.

## Positioning

One desktop player combines MIDI-to-QWERTY playback, direct MIDI output, incoming MIDI-to-QWERTY mapping, and drum-key playback, with configurable maps and playback controls.

## Operating Context

Users select local `.mid` or `.midi` files, choose an input or output device when needed, and control playback with in-app buttons or configurable hotkeys while another piano application may have focus. MIDI Hub supplies searchable online MIDI files. The app stores configuration and downloaded MIDI files in the user's Documents/nanoMIDIPlayer folder.

## Capabilities and Constraints

- Preserve the existing MIDI player, drums player, MIDI Hub, MIDI-to-QWERTY input, settings, information, and platform permission flows.
- Preserve saved configuration, MIDI lists, playback maps, hotkeys, timing behavior, and the existing MIDI handling modules.
- The user selected a full UI migration to PySide6 and Qt Quick/QML while retaining the Python MIDI engine.
- Maintain Windows, macOS, and Linux support.
- Preserve the nanoMIDIPlayer name and current bundled icon and banner assets.

## Brand Commitments

The user selected a graphite interface with muted terracotta accents and a subtle animated Plasma shader background. The supplied LiquidMetalButton React component is the source of truth for QML button geometry, shader treatment, timing, and ripple behavior.

## Evidence on Hand

- `README.md` documents MIDI-to-QWERTY playback, MIDI output, MIDI input, drums playback, configurable maps, hotkeys, MIDI Hub, and Windows/macOS/Linux support.
- `assets/defaultConfig.json` contains existing playback, mapping, hotkey, and app preference settings.
- `assets/icons/` contains the current application icon and banner assets.

## Product Principles

- Keep MIDI playback and input responsive while the user works in another application.
- Make playback modes and their device requirements clear.
- Preserve user maps, hotkeys, and configuration across upgrades.
- Keep the same core workflows available across supported desktop platforms.
