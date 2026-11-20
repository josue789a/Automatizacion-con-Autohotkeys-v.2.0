import ctypes
import tkinter as tk
import os
from ctypes import wintypes

user32, kernel32 = ctypes.windll.user32, ctypes.windll.kernel32

class MSG(ctypes.Structure):
    _fields_ = [("hwnd", wintypes.HWND), ("message", wintypes.UINT),
                ("wParam", wintypes.WPARAM), ("lParam", wintypes.LPARAM),
                ("time", wintypes.DWORD), ("pt", wintypes.POINT)]

HOOKPROC = ctypes.WINFUNCTYPE(ctypes.c_ssize_t, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM)
user32.SetWindowsHookExW.restype = wintypes.HHOOK
user32.SetWindowsHookExW.argtypes = [ctypes.c_int, HOOKPROC, wintypes.HINSTANCE, wintypes.DWORD]
user32.CallNextHookEx.restype = ctypes.c_ssize_t
user32.CallNextHookEx.argtypes = [wintypes.HHOOK, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM]
kernel32.GetTickCount64.restype = ctypes.c_ulonglong

_estado = {"barrel": None}
log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_pen_pointer.log")
_log = open(log_path, "a", buffering=1)

def _proc(n, w, l):
    if n >= 0:
        m = ctypes.cast(l, ctypes.POINTER(MSG)).contents
        if m.message in (0x245, 0x246, 0x247):          # UPDATE / DOWN / UP
            flags = (m.wParam >> 16) & 0xFFFF
            barrel = bool(flags & 0x20)
            if barrel != _estado["barrel"]:
                _estado["barrel"] = barrel
                line = f"{kernel32.GetTickCount64()} BARREL {'DOWN' if barrel else 'UP'} msg={m.message:#x} flags={flags:#x}\n"
                print(line, end="")
                _log.write(line)
    return user32.CallNextHookEx(None, n, w, l)

_cb = HOOKPROC(_proc)   # mantener referencia viva
root = tk.Tk()
root.title("Sonda Vía C: WH_GETMESSAGE Pointer")
e = tk.Entry(root, width=40, font=("Consolas", 14))
e.pack(padx=20, pady=20)
hook = user32.SetWindowsHookExW(3, _cb, None, kernel32.GetCurrentThreadId())

def on_b3(ev):
    line = f"{kernel32.GetTickCount64()} TK ButtonPress-3\n"
    print(line, end="")
    _log.write(line)

root.bind("<ButtonPress-3>", on_b3)
root.mainloop()
user32.UnhookWindowsHookEx(hook)
