"""Compatibility namespace used by MIDI Hub service state."""

from ui.qt_compat import ProxyPageMeta


class MidiHubTab(metaclass=ProxyPageMeta):
    _namespace = "hub"
