import tkinter as tk
import time
import os

log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_tk_raw.log")
with open(log_path, "w", encoding="utf-8") as f:
    f.write("=== LOG INICIADO ===\n")

r = tk.Tk()
r.title("Prueba 1: Log Crudo de Eventos en Tk")
e = tk.Entry(r, width=32, font=("Consolas", 14))
e.pack(padx=40, pady=40)

lbl = tk.Label(r, text="Pulsa el botón del lápiz sobre el cuadro (en hover y tocando el vidrio)\nCierra la ventana al terminar.", font=("Segoe UI", 10))
lbl.pack(pady=(0, 20))

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
