"""macOS accessibility permission helpers retained for the Qt interface."""

import subprocess

from ui.qt_compat import ProxyPageMeta


def checkAccessibility() -> bool:
    try:
        from ApplicationServices import AXIsProcessTrusted

        return bool(AXIsProcessTrusted())
    except Exception:
        return False


class DarwinPermissionTab(metaclass=ProxyPageMeta):
    _namespace = "darwinPermission"


def openAccessibilitySettings() -> None:
    subprocess.run(["open", "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"], check=False)


def openInputMonitoringSettings() -> None:
    subprocess.run(["open", "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"], check=False)
