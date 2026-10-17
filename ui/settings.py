"""Compatibility namespace used by existing settings operations."""

from ui.qt_compat import ProxyPageMeta


class SettingsTab(metaclass=ProxyPageMeta):
    _namespace = "settings"
