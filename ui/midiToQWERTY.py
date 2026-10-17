"""Compatibility namespace used by the MIDI input service."""

from ui.qt_compat import ProxyPageMeta


class MidiToQwertyTab(metaclass=ProxyPageMeta):
    _namespace = "midiToQwerty"
