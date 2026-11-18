"""Instancia única por mutex nombrado.

Al abrir el calibrador:
  * no hay instancia viva            -> arranca normalmente.
  * hay una instancia viva al día    -> se le avisa (recarga) y se trae al frente.
  * hay una instancia con código viejo (arrancó antes de la última modificación
    de un .py)                        -> se termina y el proceso nuevo toma el relevo.
    Así nunca se queda en pantalla una UI desactualizada.
"""
from __future__ import annotations
import logging
import sys
import time
from pathlib import Path

TITULO = "Calibración · rangos, avisos y sistema"
_MUTEX_NOMBRE = "Local\\XPPEN_CalibradorPy"
_EVT_NOMBRE = "Local\\XPPEN_CalibradorPy_Recarga"

_handle = None
_evt = None

log = logging.getLogger("calibrador.instancia")


def mtime_codigo() -> float:
    """mtime del .py más reciente del paquete (huella del código en disco)."""
    try:
        base = Path(__file__).resolve().parents[1]
        return max((p.stat().st_mtime for p in base.rglob("*.py")), default=0.0)
    except OSError:
        return 0.0


# ── ayudantes Win32 ──────────────────────────────────────────
def _win():
    import ctypes
    from ctypes import wintypes as wt
    k32, u32 = ctypes.windll.kernel32, ctypes.windll.user32
    k32.CreateMutexW.restype, k32.CreateMutexW.argtypes = wt.HANDLE, [ctypes.c_void_p, wt.BOOL, wt.LPCWSTR]
    k32.CreateEventW.restype, k32.CreateEventW.argtypes = wt.HANDLE, [ctypes.c_void_p, wt.BOOL, wt.BOOL, wt.LPCWSTR]
    k32.SetEvent.restype, k32.SetEvent.argtypes = wt.BOOL, [wt.HANDLE]
    k32.CloseHandle.restype, k32.CloseHandle.argtypes = wt.BOOL, [wt.HANDLE]
    k32.OpenProcess.restype, k32.OpenProcess.argtypes = wt.HANDLE, [wt.DWORD, wt.BOOL, wt.DWORD]
    k32.TerminateProcess.restype, k32.TerminateProcess.argtypes = wt.BOOL, [wt.HANDLE, wt.UINT]
    k32.GetProcessTimes.restype = wt.BOOL
    k32.GetProcessTimes.argtypes = [wt.HANDLE] + [ctypes.POINTER(wt.FILETIME)] * 4
    u32.FindWindowW.restype, u32.FindWindowW.argtypes = wt.HWND, [wt.LPCWSTR, wt.LPCWSTR]
    u32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
    u32.ShowWindow.argtypes = [wt.HWND, ctypes.c_int]
    u32.SetForegroundWindow.argtypes = [wt.HWND]
    return ctypes, k32, u32


def _pid_ventana() -> int:
    """PID dueño de la ventana del calibrador (0 si no hay ventana)."""
    ctypes, _k32, u32 = _win()
    from ctypes import wintypes as wt
    h = u32.FindWindowW(None, TITULO)          # también encuentra ventanas ocultas
    if not h:
        return 0
    pid = wt.DWORD(0)
    u32.GetWindowThreadProcessId(h, ctypes.byref(pid))
    return int(pid.value)


def _inicio_proceso(pid: int) -> float:
    """Hora de arranque del proceso en epoch Unix (0.0 si no se puede leer)."""
    ctypes, k32, _u32 = _win()
    from ctypes import wintypes as wt
    h = k32.OpenProcess(0x1000, False, pid)     # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return 0.0
    try:
        ct, ex, kt, ut = (wt.FILETIME() for _ in range(4))
        if not k32.GetProcessTimes(h, ctypes.byref(ct), ctypes.byref(ex), ctypes.byref(kt), ctypes.byref(ut)):
            return 0.0
        ticks = (ct.dwHighDateTime << 32) | ct.dwLowDateTime
        return ticks / 1e7 - 11644473600.0      # FILETIME -> epoch Unix
    finally:
        k32.CloseHandle(h)


def _terminar(pid: int) -> bool:
    _ctypes, k32, _u32 = _win()
    h = k32.OpenProcess(0x0001, False, pid)     # PROCESS_TERMINATE
    if not h:
        return False
    try:
        return bool(k32.TerminateProcess(h, 1))
    finally:
        k32.CloseHandle(h)


def _obsoleta(pid: int) -> bool:
    """True si el proceso arrancó antes de la última edición de código."""
    ini = _inicio_proceso(pid)
    if not ini:
        return False
    return ini < mtime_codigo()


def _avisar_no_reemplazable(pid: int) -> None:
    import ctypes
    ctypes.windll.user32.MessageBoxW(
        None,
        "Hay otra instancia del calibrador abierta que no se puede cerrar automáticamente\n"
        f"(PID {pid}, se abrió antes de los últimos cambios).\n\n"
        "Ciérrala desde el Administrador de tareas (pythonw.exe) y vuelve a abrir el calibrador.",
        "Calibrador — instancia antigua abierta", 0x30 | 0x40000)   # MB_ICONWARNING | MB_TOPMOST


# ── API pública ──────────────────────────────────────────────
def adquirir() -> bool:
    """True si este proceso debe continuar; False si ya hay una instancia al día."""
    global _handle, _evt
    if sys.platform != "win32":
        return True
    _ctypes, k32, u32 = _win()
    _evt = k32.CreateEventW(None, False, False, _EVT_NOMBRE)     # auto-reset

    h = k32.CreateMutexW(None, False, _MUTEX_NOMBRE)
    if k32.GetLastError() != 183:                                # 183 = ERROR_ALREADY_EXISTS
        _handle = h
        return True
    k32.CloseHandle(h)

    pid = _pid_ventana()
    if pid and _obsoleta(pid):
        if _terminar(pid):
            log.info("instancia obsoleta %s terminada (código más nuevo en disco)", pid)
            for _ in range(40):                                  # hasta 2 s a que suelte el mutex
                h = k32.CreateMutexW(None, False, _MUTEX_NOMBRE)
                if k32.GetLastError() != 183:
                    _handle = h
                    return True
                k32.CloseHandle(h)
                time.sleep(0.05)
            log.warning("el mutex sigue ocupado tras terminar la instancia %s", pid)
        else:
            log.warning("no se pudo terminar la instancia obsoleta %s (¿permisos?)", pid)
            _avisar_no_reemplazable(pid)

    # instancia viva y al día: avisarla (recarga) y traerla al frente
    if _evt:
        k32.SetEvent(_evt)
    hwnd = u32.FindWindowW(None, TITULO)
    if hwnd:
        u32.ShowWindow(hwnd, 9)                                  # SW_RESTORE
        u32.SetForegroundWindow(hwnd)
    return False


def consumir_recarga() -> bool:
    """True una sola vez por cada aviso de otra instancia (no bloquea)."""
    if sys.platform != "win32" or not _evt:
        return False
    import ctypes
    from ctypes import wintypes as wt
    k32 = ctypes.windll.kernel32
    k32.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
    k32.WaitForSingleObject.restype = wt.DWORD
    return k32.WaitForSingleObject(_evt, 0) == 0


def liberar() -> None:
    """Suelta mutex y evento para que un proceso sucesor pueda adquirirlos."""
    global _handle, _evt
    if sys.platform == "win32":
        ctypes, k32, _u32 = _win()
        for h in (_handle, _evt):
            if h:
                try:
                    k32.CloseHandle(h)
                except Exception:
                    pass
    _handle = None
    _evt = None
