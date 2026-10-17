"""Compatibility namespace for the information page."""

from ui.qt_compat import ProxyPageMeta


class InfoTab(metaclass=ProxyPageMeta):
    _namespace = "info"
