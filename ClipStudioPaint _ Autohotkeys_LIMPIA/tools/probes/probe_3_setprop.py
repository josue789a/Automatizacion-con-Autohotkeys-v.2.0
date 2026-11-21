import tkinter as tk
import time
import os
import ctypes
from ctypes import wintypes as w

log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_tk_setprop.log")
with open(log_path, "w", encoding="utf-8") as f:
    f.write("=== LOG CON SETPROP INICIADO ===\n")

r = tk.Tk()
r.title("Prueba 3: Con MicrosoftTabletPenServiceProperty (Sin Press&Hold)")
e = tk.Entry(r, width=32, font=("Consolas", 14))
e.pack(padx=40, pady=40)

lbl = tk.Label(r, text="Prueba 3: Con SetProp (Sin press-and-hold ni círculo)\nPulsa el botón del lápiz sobre el cuadro.\nCierra la ventana al terminar.", font=("Segoe UI", 10))
lbl.pack(pady=(0, 20))

u32, k32 = ctypes.windll.user32, ctypes.windll.kernel32
k32.GlobalAddAtomW.argtypes = [w.LPCWSTR]; k32.GlobalAddAtomW.restype = w.ATOM
u32.SetPropW.argtypes = [w.HWND, w.LPCWSTR, w.HANDLE]; u32.SetPropW.restype = w.BOOL
u32.GetAncestor.argtypes = [w.HWND, w.UINT]; u32.GetAncestor.restype = w.HWND
FLAGS = 0x1 | 0x8 | 0x10 | 0x10000   # PRESSANDHOLD | PENTAPFEEDBACK | PENBARRELFEEDBACK | FLICKS
atom = k32.GlobalAddAtomW("MicrosoftTabletPenServiceProperty")
r.update_idletasks()

for h in {e.winfo_id(), r.winfo_id(), u32.GetAncestor(e.winfo_id(), 2)}:
    u32.SetPropW(h, ctypes.cast(atom, ctypes.c_wchar_p), ctypes.c_void_p(FLAGS))

t0 = time.perf_counter()

def log(tag):
    def f(ev):
        line = f"{(time.perf_counter()-t0)*1000:8.1f}ms {tag:16} num={getattr(ev,'num','-')} state={ev.state:#06x} x={ev.x} y={ev.y}"
        print(line)
        with open(log_path, "a", encoding="utf-8") as fp:
            fp.write(line + "\n")
    return f

for seq in ("<ButtonPress>", "<ButtonRelease>", "<B1-Motion>", "<Motion>"):
    e.bind(seq, log(seq), add="+")

r.mainloop()
