import sys
import os
import tkinter as tk
import ctypes
from ctypes import wintypes as w

modo = sys.argv[1].lower() if len(sys.argv) > 1 and sys.argv[1].lower() in ("v0", "v1", "v2") else "v2"

log_name = f"probe_ptr_{modo}.log"
log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), log_name)
with open(log_path, "w", encoding="utf-8") as f:
    f.write(f"=== LOG WM_POINTER MODO {modo.upper()} INICIADO ===\n")

u32 = ctypes.windll.user32
c32 = ctypes.windll.comctl32
k32 = ctypes.windll.kernel32

LRESULT = ctypes.c_ssize_t
SUBCLASSPROC = ctypes.WINFUNCTYPE(LRESULT, w.HWND, w.UINT, w.WPARAM, w.LPARAM, ctypes.c_size_t, ctypes.c_size_t)

u32.DefWindowProcW.restype = LRESULT
u32.DefWindowProcW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]
c32.SetWindowSubclass.argtypes = [w.HWND, SUBCLASSPROC, ctypes.c_size_t, ctypes.c_size_t]
c32.SetWindowSubclass.restype = w.BOOL
c32.DefSubclassProc.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]
c32.DefSubclassProc.restype = LRESULT

def log_line(msg):
    print(msg)
    with open(log_path, "a", encoding="utf-8") as fp:
        fp.write(msg + "\n")

_prev = {"k": None}

def make_proc(m):
    def proc(hwnd, msg, wp, lp, uid, ref):
        if msg in (0x245, 0x246, 0x247):  # UPDATE, DOWN, UP
            flags = (wp >> 16) & 0xFFFF
            clave = flags & 0x26  # INRANGE/INCONTACT/SECONDBUTTON
            if clave != _prev["k"] or msg in (0x246, 0x247):
                _prev["k"] = clave
                log_line(f"{k32.GetTickCount64()} PTR msg={msg:#x} flags={flags:#x} barrel={bool(flags & 0x20)} contact={bool(flags & 0x04)}")
            if m == "v2":
                return u32.DefWindowProcW(hwnd, msg, wp, lp)
        return c32.DefSubclassProc(hwnd, msg, wp, lp)
    return proc

r = tk.Tk()
r.title(f"Sonda WM_POINTER [{modo.upper()}]")
r.geometry("450x260")

lbl = tk.Label(r, text=f"Sonda WM_POINTER — Modo: {modo.upper()}\n\n1. Hover con botón lateral pulsado.\n2. Tocar vidrio con botón lateral pulsado.\n3. Mantener punta ~1.2s sin botón (press-and-hold).\n\nCierra la ventana en la X al terminar.", font=("Segoe UI", 10), justify="center")
lbl.pack(pady=15)

e = tk.Entry(r, width=32, font=("Consolas", 14), justify="center")
e.pack(padx=20, pady=10)
e.focus_set()

for seq in ("<ButtonPress>", "<ButtonRelease>"):
    e.bind(seq, lambda ev, s=seq: log_line(f"{k32.GetTickCount64()}   TK {s} num={ev.num}"), add="+")
    r.bind(seq, lambda ev, s=seq: log_line(f"{k32.GetTickCount64()}   TK-ROOT {s} num={ev.num}"), add="+")

r.update_idletasks()

if modo in ("v1", "v2"):
    cb = SUBCLASSPROC(make_proc(modo))
    ga = u32.GetAncestor
    ga.argtypes = [w.HWND, w.UINT]
    ga.restype = w.HWND
    hwnds = {e.winfo_id(), r.winfo_id(), ga(e.winfo_id(), 2)}
    for i, h in enumerate(hwnds):
        res = c32.SetWindowSubclass(h, cb, 100 + i, 0)
        log_line(f"subclass {hex(h)} {res}")
else:
    log_line("v0: control puro sin subclass")

r.mainloop()
