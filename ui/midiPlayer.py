"""Compatibility namespace used by the MIDI playback service."""

from ui.qt_compat import ProxyPageMeta


class MidiPlayerTab(metaclass=ProxyPageMeta):
    _namespace = "midiPlayer"
