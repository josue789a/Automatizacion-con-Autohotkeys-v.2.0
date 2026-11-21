"""Script de medición automática para la tabla de FASE 0.6."""
from __future__ import annotations
import io
import sys
import time
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

import customtkinter as ctk
import tkinter as tk

def contar(w):
    if w is None:
        return 0
    try:
        return 1 + sum(contar(c) for c in w.winfo_children())
    except Exception:
        return 1

def medir():
    t0 = time.perf_counter()
    from xppen_calibrador.app import CalibradorApp
    from xppen_calibrador.core.single_instance import TITULO
    t_import = time.perf_counter() - t0

    t1 = time.perf_counter()
    ini_path = str(BASE_DIR.parent / "posiciones_gui.ini")
    app = CalibradorApp(ini_path, "1", "normal", 0)
    t_created = time.perf_counter() - t0

    t2 = time.perf_counter()
    app.update_idletasks()
    app.update()
    t_ready = time.perf_counter() - t0

    total_w = contar(app)
    editor_w = contar(getattr(app, "editor", None))
    cat_w = contar(getattr(app, "cat_panel", None))

    # Medir cambio de evento
    t_switch = 0.0
    if hasattr(app, "catalogo") and len(app.catalogo.eventos) > 1:
        ev1 = app.ctx.event_id
        ev2 = next((e.id for e in app.catalogo.eventos if e.id != ev1), None)
        if ev2:
            ts0 = time.perf_counter()
            app._select(ev2)
            app.update_idletasks()
            t_switch = (time.perf_counter() - ts0) * 1000

    app.destroy()

    print(f"RESULTADOS_MEDICION:")
    print(f"ventana_creada_s={t_created:.3f}")
    print(f"contenido_listo_s={t_ready:.3f}")
    print(f"widgets_total={total_w}")
    print(f"widgets_editor={editor_w}")
    print(f"widgets_catalogo={cat_w}")
    print(f"cambio_evento_ms={t_switch:.2f}")

if __name__ == "__main__":
    medir()
