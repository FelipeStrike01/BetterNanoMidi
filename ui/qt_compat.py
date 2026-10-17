"""Small state adapters that let the existing MIDI services talk to QML.

The adapters intentionally mimic only the value/configuration surface used by
the old UI-facing functions. They do not create widgets or a hidden Tk root.
"""

from __future__ import annotations

import threading
from typing import Any

from PySide6.QtCore import QObject, Property, QThread, QTimer, Qt, Signal, Slot


_registry: dict[str, dict[str, "CompatWidget"]] = {}
_registry_lock = threading.RLock()


class CompatVar:
    """A tiny StringVar-compatible value holder used by the core functions."""

    def __init__(self, value: Any = "off") -> None:
        self._value = value
        self._lock = threading.RLock()

    def get(self) -> Any:
        with self._lock:
            return self._value

    def set(self, value: Any) -> None:
        with self._lock:
            self._value = value


class CompatWidget(QObject):
    """A QObject state proxy with the subset of Tk widget methods still used."""

    valueChanged = Signal()
    textChanged = Signal()
    valuesChanged = Signal()
    enabledChanged = Signal()
    stateChanged = Signal()
    accentColorChanged = Signal()
    _updateRequested = Signal(object)
    _scheduleRequested = Signal(int, object)

    def __init__(self, page: str, name: str) -> None:
        super().__init__()
        self.page = page
        self.name = name
        self._value: Any = ""
        self._text = ""
        self._values: list[Any] = []
        self._enabled = True
        self._state = "normal"
        self._accent_color = ""
        self._options: dict[str, Any] = {}
        self._lock = threading.RLock()
        self._updateRequested.connect(self._applyUpdate, Qt.ConnectionType.QueuedConnection)
        self._scheduleRequested.connect(self._schedule, Qt.ConnectionType.QueuedConnection)

    @Property("QVariant", notify=valueChanged)
    def value(self) -> Any:
        with self._lock:
            return self._value

    @value.setter
    def value(self, value: Any) -> None:
        self._requestUpdate({"value": value})

    @Property(str, notify=textChanged)
    def text(self) -> str:
        with self._lock:
            return self._text

    @text.setter
    def text(self, value: str) -> None:
        self._requestUpdate({"text": value})

    @Property("QVariantList", notify=valuesChanged)
    def values(self) -> list[Any]:
        with self._lock:
            return list(self._values)

    @values.setter
    def values(self, value: list[Any]) -> None:
        self._requestUpdate({"values": list(value or [])})

    @Property(bool, notify=enabledChanged)
    def enabled(self) -> bool:
        with self._lock:
            return self._enabled

    @enabled.setter
    def enabled(self, value: bool) -> None:
        self._requestUpdate({"enabled": bool(value)})

    @Property(str, notify=stateChanged)
    def state(self) -> str:
        with self._lock:
            return self._state

    @Property(str, notify=accentColorChanged)
    def accentColor(self) -> str:
        with self._lock:
            return self._accent_color

    def _requestUpdate(self, changes: dict[str, Any]) -> None:
        if QThread.currentThread() == self.thread():
            self._applyUpdate(changes)
        else:
            self._updateRequested.emit(changes)

    @Slot(object)
    def _applyUpdate(self, changes: dict[str, Any]) -> None:
        value_changed = text_changed = values_changed = False
        enabled_changed = state_changed = accent_changed = False
        with self._lock:
            for key, value in changes.items():
                self._options[key] = value
                if key == "value":
                    if self._value != value:
                        self._value = value
                        value_changed = True
                elif key in ("text", "placeholder_text"):
                    text = str(value if key == "text" else (self._text or value))
                    if self._text != text:
                        self._text = text
                        text_changed = True
                elif key == "values":
                    values = list(value or [])
                    if self._values != values:
                        self._values = values
                        values_changed = True
                elif key == "state":
                    state = str(value)
                    if self._state != state:
                        self._state = state
                        state_changed = True
                    enabled = state not in ("disabled", "hidden")
                    if self._enabled != enabled:
                        self._enabled = enabled
                        enabled_changed = True
                elif key == "enabled":
                    enabled = bool(value)
                    if self._enabled != enabled:
                        self._enabled = enabled
                        enabled_changed = True
                    state = "normal" if enabled else "disabled"
                    if self._state != state:
                        self._state = state
                        state_changed = True
                elif key in ("fg_color", "hover_color", "text_color"):
                    color = value[-1] if isinstance(value, (tuple, list)) and value else value
                    if self._accent_color != str(color):
                        self._accent_color = str(color)
                        accent_changed = True
            if "value" in changes and isinstance(self._value, str) and not changes.get("text"):
                if self._text != self._value:
                    self._text = self._value
                    text_changed = True
        if value_changed:
            self.valueChanged.emit()
        if text_changed:
            self.textChanged.emit()
        if values_changed:
            self.valuesChanged.emit()
        if enabled_changed:
            self.enabledChanged.emit()
        if state_changed:
            self.stateChanged.emit()
        if accent_changed:
            self.accentColorChanged.emit()

    def configure(self, **kwargs: Any) -> None:
        self._requestUpdate(kwargs)

    def config(self, **kwargs: Any) -> None:
        self.configure(**kwargs)

    def set(self, value: Any) -> None:
        self._requestUpdate({"value": value, "text": str(value)})

    def get(self) -> Any:
        return self.value

    def cget(self, option: str) -> Any:
        aliases = {"values": "values", "state": "state", "text": "text", "fg_color": "fg_color"}
        key = aliases.get(option, option)
        if key == "values":
            return self.values
        if key == "state":
            return self.state
        if key == "text":
            return self.text
        with self._lock:
            return self._options.get(key)

    def delete(self, _start: Any = None, _end: Any = None) -> None:
        self._requestUpdate({"text": "", "value": ""})

    def insert(self, _index: Any, value: Any) -> None:
        self._requestUpdate({"text": str(value), "value": str(value)})

    def after(self, milliseconds: int, callback: Any = None) -> None:
        if callback is not None:
            self._scheduleRequested.emit(max(0, int(milliseconds)), callback)

    @Slot(int, object)
    def _schedule(self, milliseconds: int, callback: Any) -> None:
        QTimer.singleShot(milliseconds, callback)

    # Legacy event and layout hooks have no meaning in QML; QML owns those.
    def bind(self, *_args: Any, **_kwargs: Any) -> None:
        return None

    def unbind(self, *_args: Any, **_kwargs: Any) -> None:
        return None

    def bind_all(self, *_args: Any, **_kwargs: Any) -> None:
        return None

    def update(self, *_args: Any, **_kwargs: Any) -> None:
        return None

    def update_idletasks(self, *_args: Any, **_kwargs: Any) -> None:
        return None

    def destroy(self) -> None:
        return None

    def pack(self, *_args: Any, **_kwargs: Any) -> None:
        return None

    def pack_forget(self) -> None:
        return None

    def winfo_children(self) -> list[Any]:
        return []

    def winfo_exists(self) -> bool:
        return True


def widgetProxy(page: str, name: str) -> CompatWidget:
    with _registry_lock:
        page_widgets = _registry.setdefault(page, {})
        if name not in page_widgets:
            page_widgets[name] = CompatWidget(page, name)
        return page_widgets[name]


def widgetGroups() -> dict[str, dict[str, CompatWidget]]:
    with _registry_lock:
        return {page: dict(widgets) for page, widgets in _registry.items()}


class ProxyPageMeta(type):
    def __getattr__(cls, name: str) -> CompatWidget:
        namespace = getattr(cls, "_namespace", cls.__name__)
        return widgetProxy(namespace, name)
