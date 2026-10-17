"""Compatibility namespace used by the drums playback service."""

from ui.qt_compat import ProxyPageMeta


class DrumsMacroTab(metaclass=ProxyPageMeta):
    _namespace = "drums"
