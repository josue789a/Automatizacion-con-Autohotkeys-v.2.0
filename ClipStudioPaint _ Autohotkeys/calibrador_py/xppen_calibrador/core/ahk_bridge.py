"""Python → AHK por WM_COPYDATA (texto 'CMD|arg|arg'). En no-Windows es un no-op registrado."""
from __future__ import annotations
import logging
import queue
import sys
import threading

log = logging.getLogger("calibrador.bridge")
WM_COPYDATA, SMTO_ABORTIFHUNG, MARKER = 0x4A, 0x2, 0x58504E01


class AhkBridge:
    def __init__(self, ahk_hwnd: int | None, own_hwnd_getter=lambda: 0):
        self.ahk_hwnd, self._own = ahk_hwnd, own_hwnd_getter
        self.sent: list[str] = []
        self._q = None

    _TITULO_AHK = "XPPEN AHK VERSION ESTABLE.ahk"
    _t_ultimo_intento = 0.0

    def _buscar_hwnd_ahk(self) -> int:
        if sys.platform != "win32":
            return 0
        import ctypes
        import ctypes.wintypes as wt
        import tempfile
        from pathlib import Path
        u32 = ctypes.windll.user32
        try:
            p = Path(tempfile.gettempdir()) / "_ahk_bridge_hwnd.txt"
            if p.exists():
                h_txt = p.read_text(encoding="utf-8-sig").strip()
                if h_txt.isdigit():
                    h_val = int(h_txt)
                    if u32.IsWindow(h_val):
                        return h_val
        except Exception:
            pass
        encontrado: list[int] = []

        @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
        def _cb(h, _lp):
            cls = ctypes.create_unicode_buffer(64)
            u32.GetClassNameW(h, cls, 64)
            if cls.value == "AutoHotkey":
                n = u32.GetWindowTextLengthW(h)
                buf = ctypes.create_unicode_buffer(n + 1)
                u32.GetWindowTextW(h, buf, n + 1)
                if self._TITULO_AHK.lower() in buf.value.lower():
                    encontrado.append(int(h))
                    return False
            return True

        u32.EnumWindows(_cb, 0)
        return encontrado[0] if encontrado else 0

    @property
    def conectado(self) -> bool:
        if sys.platform != "win32":
            return False
        import ctypes
        import time
        if self.ahk_hwnd and ctypes.windll.user32.IsWindow(self.ahk_hwnd):
            return True
        ahora = time.monotonic()
        if ahora - self._t_ultimo_intento < 1.0:
            return False
        self._t_ultimo_intento = ahora
        self.ahk_hwnd = self._buscar_hwnd_ahk() or 0
        return bool(self.ahk_hwnd)

    def send_async(self, cmd: str, *args) -> None:
        """No bloquea la UI: encola (FIFO) y un hilo hace el SendMessageTimeoutW."""
        h = self._own()                      # Tk solo desde el hilo de UI: se cachea el hwnd
        if h:
            self._own = (lambda _h=h: _h)
        if self._q is None:
            self._q = queue.Queue()
            threading.Thread(target=self._worker, name="ahk-bridge", daemon=True).start()
        self._q.put((cmd, args))

    def _worker(self):
        while True:
            cmd, args = self._q.get()
            try:
                self.send(cmd, *args)
            except Exception:
                log.exception("send_async %s", cmd)

    def send(self, cmd: str, *args) -> bool:
        text = "|".join([cmd, *[str(a) for a in args]])
        self.sent.append(text)
        if not self.conectado:
            log.info("(sin AHK) %s", text)
            return False
        import ctypes
        from ctypes import wintypes

        class CDS(ctypes.Structure):
            _fields_ = [("dwData", ctypes.c_void_p), ("cbData", wintypes.DWORD), ("lpData", ctypes.c_void_p)]

        buf = ctypes.create_unicode_buffer(text)
        cds = CDS(MARKER, ctypes.sizeof(buf), ctypes.cast(buf, ctypes.c_void_p))
        res = ctypes.c_size_t(0)
        ok = ctypes.windll.user32.SendMessageTimeoutW(
            wintypes.HWND(self.ahk_hwnd), WM_COPYDATA, wintypes.WPARAM(self._own()),
            ctypes.byref(cds), SMTO_ABORTIFHUNG, 1500, ctypes.byref(res))
        log.info("→ AHK %s (ok=%s, res=%s)", text, bool(ok), res.value)
        return bool(ok) and res.value == 1
