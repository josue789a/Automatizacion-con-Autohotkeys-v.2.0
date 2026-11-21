"""Script de perfilado para FASE 0.5: cProfile sobre EditorPanel y _select(id)."""
from __future__ import annotations
import cProfile
import io
import pstats
import sys
import time
from pathlib import Path

# Agregar calibrador_py al sys.path
BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from xppen_calibrador.core.ini_store import IniFile
from xppen_calibrador.core.draft import Draft
from xppen_calibrador.core.catalogo import Catalogo
from xppen_calibrador.core.ahk_bridge import AhkBridge
from xppen_calibrador.ui.blocks import Ctx
from xppen_calibrador.ui.panels import EditorPanel, CatalogoPanel
from xppen_calibrador.ui import theme as T
import customtkinter as ctk
import tkinter as tk

INI_PATH = BASE_DIR.parent / "posiciones_gui.ini"
DATA_DIR = BASE_DIR / "data"

def contar_widgets(w):
    if w is None:
        return 0
    try:
        return 1 + sum(contar_widgets(c) for c in w.winfo_children())
    except Exception:
        return 1

def main():
    ctk.set_appearance_mode("light")
    root = ctk.CTk(fg_color=T.BG)
    root.withdraw() # invisible durante el test
    T.init_fonts(root)
    root.minsize(940, 600)

    store = IniFile(INI_PATH).load()
    draft = Draft(store, "1")
    catalogo = Catalogo(store, DATA_DIR).load()
    bridge = AhkBridge(0, 0)
    ctx = Ctx(draft, bridge, catalogo, lambda: None)

    container = ctk.CTkFrame(root, fg_color=T.BG)
    container.pack(fill="both", expand=True)

    # Catálogo panel
    cat_panel = CatalogoPanel(container, catalogo, lambda ev: None, lambda: None, app=None)

    # 1. PERFILADO DE CONSTRUCCIÓN DE EditorPanel
    print("\n" + "=" * 70)
    print("PARTE 1: cProfile de EditorPanel.__init__")
    print("=" * 70)
    prof_editor = cProfile.Profile()
    prof_editor.enable()

    t0_ed = time.perf_counter()
    editor = EditorPanel(container, ctx)
    editor.update_idletasks()
    t_ed_elapsed = time.perf_counter() - t0_ed

    prof_editor.disable()

    s_ed = io.StringIO()
    ps_ed = pstats.Stats(prof_editor, stream=s_ed).sort_stats("cumtime")
    ps_ed.print_stats(25)
    print(f"Tiempo total construcción EditorPanel: {t_ed_elapsed:.3f} s")
    print(s_ed.getvalue())

    # Conectar selección
    first_ev = catalogo.por_id("estab_slider") or catalogo.eventos[0]
    ctx.event_id = first_ev.id
    editor.show_event(first_ev)
    editor.update_idletasks()

    # 2. PERFILADO DE _select(id) (CAMBIO DE EVENTO)
    otro_ev = next((e for e in catalogo.eventos if e.id != first_ev.id), None)
    print("\n" + "=" * 70)
    print(f"PARTE 2: cProfile de _select(id) -> cambio a '{otro_ev.id}'")
    print("=" * 70)

    # Interceptar configure() y destroy() para contar exactamente
    configure_calls = 0
    destroy_calls = 0
    orig_configure = tk.Misc.configure
    orig_destroy = tk.Misc.destroy

    def counted_configure(self, *args, **kwargs):
        nonlocal configure_calls
        configure_calls += 1
        return orig_configure(self, *args, **kwargs)

    def counted_destroy(self, *args, **kwargs):
        nonlocal destroy_calls
        destroy_calls += 1
        return orig_destroy(self, *args, **kwargs)

    tk.Misc.configure = counted_configure
    tk.Misc.destroy = counted_destroy

    widgets_antes = contar_widgets(editor)

    prof_select = cProfile.Profile()
    prof_select.enable()

    t0_sel = time.perf_counter()
    editor.show_event(otro_ev)
    editor.update_idletasks()
    t_sel_elapsed = time.perf_counter() - t0_sel

    prof_select.disable()

    tk.Misc.configure = orig_configure
    tk.Misc.destroy = orig_destroy

    widgets_despues = contar_widgets(editor)

    s_sel = io.StringIO()
    ps_sel = pstats.Stats(prof_select, stream=s_sel).sort_stats("cumtime")
    ps_sel.print_stats(25)
    print(f"Tiempo total cambio de evento: {t_sel_elapsed*1000:.2f} ms")
    print(f"Widgets antes: {widgets_antes} | Widgets después: {widgets_despues} (delta: {widgets_despues - widgets_antes})")
    print(f"Llamadas a destroy(): {destroy_calls} (destruye/recrea = {'SÍ' if destroy_calls > 0 else 'NO, reconfigura'})")
    print(f"Llamadas a configure(): {configure_calls}")
    print(s_sel.getvalue())

    root.destroy()

if __name__ == "__main__":
    main()
