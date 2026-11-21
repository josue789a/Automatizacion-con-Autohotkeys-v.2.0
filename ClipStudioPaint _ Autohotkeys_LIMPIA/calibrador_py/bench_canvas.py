"""Microbenchmark aislado para FASE 1.0 (Spike de rendimiento: CTk vs Canvas).

Compara:
1) 200 widgets CTk (100 CTkButton + 60 CTkEntry + 40 CTkCheckBox)
2) 200 elementos visuales equivalentes dibujados en un solo tk.Canvas
3) Canvas con 1 Entry flotante reutilizable para edición
"""
from __future__ import annotations
import sys
import time
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

import tkinter as tk
import customtkinter as ctk

# Tokens de tema equivalentes a ui.theme
BG_COLOR = "#F8F9FA"
CARD_COLOR = "#FFFFFF"
PRIMARY_COLOR = "#7863A6"
BORDER_COLOR = "#E5E0F0"
TXT_COLOR = "#1C1917"
TXT2_COLOR = "#78716C"

def round_polygon(x, y, w, h, r):
    """Genera coordenadas para un polígono redondeado smooth en tk.Canvas."""
    return [
        x + r, y,
        x + w - r, y,
        x + w, y,
        x + w, y + r,
        x + w, y + h - r,
        x + w, y + h,
        x + w - r, y + h,
        x + r, y + h,
        x, y + h,
        x, y + h - r,
        x, y + r,
        x, y
    ]

# ─────────────────────────────────────────────────────────────────────────────
# 1) BENCHMARK CTK (200 widgets)
# ─────────────────────────────────────────────────────────────────────────────
def run_bench_ctk():
    root = ctk.CTk(fg_color=BG_COLOR)
    root.withdraw()
    root.geometry("700x600")

    scroll = ctk.CTkScrollableFrame(root, width=680, height=580)
    scroll.pack(fill="both", expand=True)

    t0_build = time.perf_counter()
    buttons = []
    entries = []
    checks = []

    for i in range(100):
        b = ctk.CTkButton(scroll, text=f"Boton {i}", fg_color=PRIMARY_COLOR, corner_radius=8, width=120, height=28)
        b.pack(pady=2)
        buttons.append(b)

    for i in range(60):
        e = ctk.CTkEntry(scroll, width=140, height=28)
        e.insert(0, f"Valor {i}")
        e.pack(pady=2)
        entries.append(e)

    for i in range(40):
        c = ctk.CTkCheckBox(scroll, text=f"Opcion {i}")
        c.pack(pady=2)
        checks.append(c)

    root.update_idletasks()
    t_build = (time.perf_counter() - t0_build) * 1000

    # Cambio de evento (actualizar 50 controles: 20 checks, 20 entries, 10 buttons)
    t0_event = time.perf_counter()
    for i in range(20):
        (checks[i].select if i % 2 == 0 else checks[i].deselect)()
    for i in range(20):
        entries[i].delete(0, "end")
        entries[i].insert(0, f"Nuevo {i*10}")
    for i in range(10):
        buttons[i].configure(text=f"Modificado {i}")
    root.update_idletasks()
    t_event = (time.perf_counter() - t0_event) * 1000

    # Resize (de 700 a 1100 px)
    t0_resize = time.perf_counter()
    root.geometry("1100x600")
    root.update_idletasks()
    t_resize = (time.perf_counter() - t0_resize) * 1000

    root.destroy()
    return t_build, t_event, t_resize

# ─────────────────────────────────────────────────────────────────────────────
# 2) BENCHMARK CANVAS PURO (200 elementos visuales dibujados)
# ─────────────────────────────────────────────────────────────────────────────
def run_bench_canvas():
    root = tk.Tk()
    root.withdraw()
    root.geometry("700x600")
    root.configure(bg=BG_COLOR)

    canvas = tk.Canvas(root, bg=BG_COLOR, highlightthickness=0)
    canvas.pack(fill="both", expand=True)

    t0_build = time.perf_counter()

    btn_tags = []
    entry_tags = []
    chk_tags = []

    y = 10
    # 100 botones dibujados
    for i in range(100):
        tag_bg = f"btn_bg_{i}"
        tag_txt = f"btn_txt_{i}"
        pts = round_polygon(20, y, 120, 28, 6)
        canvas.create_polygon(pts, fill=PRIMARY_COLOR, outline="", smooth=True, tags=(tag_bg, "btn"))
        canvas.create_text(80, y + 14, text=f"Boton {i}", fill="#FFFFFF", font=("Segoe UI", 10, "bold"), tags=(tag_txt, "btn"))
        btn_tags.append((tag_bg, tag_txt))
        y += 32

    # 60 entries dibujados
    for i in range(60):
        tag_bg = f"ent_bg_{i}"
        tag_txt = f"ent_txt_{i}"
        pts = round_polygon(20, y, 140, 28, 6)
        canvas.create_polygon(pts, fill=CARD_COLOR, outline=BORDER_COLOR, smooth=True, tags=(tag_bg, "entry"))
        canvas.create_text(30, y + 14, text=f"Valor {i}", anchor="w", fill=TXT_COLOR, font=("Segoe UI", 10), tags=(tag_txt, "entry"))
        entry_tags.append((tag_bg, tag_txt))
        y += 32

    # 40 checkboxes dibujados
    for i in range(40):
        tag_box = f"chk_box_{i}"
        tag_mark = f"chk_mark_{i}"
        tag_lbl = f"chk_lbl_{i}"
        pts = round_polygon(20, y + 4, 18, 18, 4)
        canvas.create_polygon(pts, fill=CARD_COLOR, outline=BORDER_COLOR, smooth=True, tags=(tag_box, "chk"))
        canvas.create_text(29, y + 13, text="✓", fill=PRIMARY_COLOR, font=("Segoe UI", 10, "bold"), state="hidden", tags=(tag_mark, "chk"))
        canvas.create_text(46, y + 13, text=f"Opcion {i}", anchor="w", fill=TXT_COLOR, font=("Segoe UI", 10), tags=(tag_lbl, "chk"))
        chk_tags.append((tag_box, tag_mark, tag_lbl))
        y += 28

    canvas.configure(scrollregion=(0, 0, 700, y + 20))
    root.update_idletasks()
    t_build = (time.perf_counter() - t0_build) * 1000

    # Cambio de evento (50 items: itemconfig de 20 checks, 20 entries, 10 buttons)
    t0_event = time.perf_counter()
    for i in range(20):
        state = "normal" if i % 2 == 0 else "hidden"
        canvas.itemconfig(chk_tags[i][1], state=state)
    for i in range(20):
        canvas.itemconfig(entry_tags[i][1], text=f"Nuevo {i*10}")
    for i in range(10):
        canvas.itemconfig(btn_tags[i][1], text=f"Modificado {i}")
    root.update_idletasks()
    t_event = (time.perf_counter() - t0_event) * 1000

    # Resize (de 700 a 1100 px: reubicar coords con canvas.coords)
    t0_resize = time.perf_counter()
    root.geometry("1100x600")
    # En canvas, el reacomodo solo ajusta coords de elementos responsivos
    for i, (bg, txt) in enumerate(entry_tags):
        pts = round_polygon(20, 100 * 32 + i * 32, 220, 28, 6) # se expande a 220 px
        canvas.coords(bg, *pts)
    canvas.configure(scrollregion=(0, 0, 1100, y + 20))
    root.update_idletasks()
    t_resize = (time.perf_counter() - t0_resize) * 1000

    root.destroy()
    return t_build, t_event, t_resize

# ─────────────────────────────────────────────────────────────────────────────
# 3) BENCHMARK CANVAS + 1 ENTRY FLOTANTE (Overlay)
# ─────────────────────────────────────────────────────────────────────────────
def run_bench_canvas_overlay():
    root = tk.Tk()
    root.withdraw()
    root.geometry("700x600")
    root.configure(bg=BG_COLOR)

    canvas = tk.Canvas(root, bg=BG_COLOR, highlightthickness=0)
    canvas.pack(fill="both", expand=True)

    t0_build = time.perf_counter()

    # 1 Entry flotante reutilizable para todos los campos
    floating_entry = tk.Entry(canvas, font=("Segoe UI", 10), bg=CARD_COLOR, fg=TXT_COLOR,
                              bd=1, relief="solid", highlightthickness=0)
    floating_win = canvas.create_window(-500, -500, window=floating_entry, anchor="nw", state="hidden")

    y = 10
    entry_tags = []
    for i in range(60):
        tag_bg = f"ent_bg_{i}"
        tag_txt = f"ent_txt_{i}"
        pts = round_polygon(20, y, 140, 28, 6)
        canvas.create_polygon(pts, fill=CARD_COLOR, outline=BORDER_COLOR, smooth=True, tags=(tag_bg, f"field_{i}"))
        canvas.create_text(30, y + 14, text=f"Valor {i}", anchor="w", fill=TXT_COLOR, font=("Segoe UI", 10), tags=(tag_txt, f"field_{i}"))
        entry_tags.append((tag_bg, tag_txt, 20, y, 140, 28))
        y += 32

    # Simular clic en el campo 5 -> activa el entry flotante en esa posición
    target = entry_tags[5]
    canvas.coords(floating_win, target[2] + 2, target[3] + 2)
    floating_entry.configure(width=16)
    floating_entry.delete(0, "end")
    floating_entry.insert(0, "Texto editable activo")
    canvas.itemconfig(floating_win, state="normal")

    canvas.configure(scrollregion=(0, 0, 700, y + 20))
    root.update_idletasks()
    t_build = (time.perf_counter() - t0_build) * 1000

    # Cambio de posición flotante a otro campo (ej. campo 15)
    t0_move = time.perf_counter()
    target2 = entry_tags[15]
    canvas.coords(floating_win, target2[2] + 2, target2[3] + 2)
    floating_entry.delete(0, "end")
    floating_entry.insert(0, "Nuevo campo")
    root.update_idletasks()
    t_move = (time.perf_counter() - t0_move) * 1000

    root.destroy()
    return t_build, t_move

def main():
    print("=" * 65)
    print("FASE 1.0: SPIKE DE RENDIMIENTO AISLADO (CTk vs Canvas)")
    print("=" * 65)
    print("Ejecutando 3 corridas de cada benchmark para promedio estable...\n")

    ctk_builds, ctk_events, ctk_resizes = [], [], []
    for _ in range(3):
        b, e, r = run_bench_ctk()
        ctk_builds.append(b); ctk_events.append(e); ctk_resizes.append(r)

    cv_builds, cv_events, cv_resizes = [], [], []
    for _ in range(3):
        b, e, r = run_bench_canvas()
        cv_builds.append(b); cv_events.append(e); cv_resizes.append(r)

    ov_builds, ov_moves = [], []
    for _ in range(3):
        b, m = run_bench_canvas_overlay()
        ov_builds.append(b); ov_moves.append(m)

    avg_ctk_b = sum(ctk_builds) / len(ctk_builds)
    avg_ctk_e = sum(ctk_events) / len(ctk_events)
    avg_ctk_r = sum(ctk_resizes) / len(ctk_resizes)

    avg_cv_b = sum(cv_builds) / len(cv_builds)
    avg_cv_e = sum(cv_events) / len(cv_events)
    avg_cv_r = sum(cv_resizes) / len(cv_resizes)

    ratio_b = avg_ctk_b / avg_cv_b if avg_cv_b > 0 else 999
    ratio_e = avg_ctk_e / avg_cv_e if avg_cv_e > 0 else 999
    ratio_r = avg_ctk_r / avg_cv_r if avg_cv_r > 0 else 999

    print("RESULTADOS PROMEDIO:")
    print("-" * 65)
    print(f"{'Métrica':<24} | {'CTk (200 w)':<12} | {'Canvas Puro':<12} | {'Aceleración':<10}")
    print("-" * 65)
    print(f"{'Construcción':<24} | {avg_ctk_b:8.2f} ms   | {avg_cv_b:8.2f} ms   | {ratio_b:6.1f}x")
    print(f"{'Cambio de evento':<24} | {avg_ctk_e:8.2f} ms   | {avg_cv_e:8.2f} ms   | {ratio_e:6.1f}x")
    print(f"{'Resize (700 -> 1100 px)':<24} | {avg_ctk_r:8.2f} ms   | {avg_cv_r:8.2f} ms   | {ratio_r:6.1f}x")
    print("-" * 65)
    print(f"\nCanvas + 1 Entry Flotante:")
    print(f"  • Construcción base: {sum(ov_builds)/len(ov_builds):.2f} ms")
    print(f"  • Mover/reutilizar Entry flotante al click: {sum(ov_moves)/len(ov_moves):.2f} ms")

    print("\nEVALUACIÓN DE CRITERIOS:")
    pass_build = ratio_b >= 5.0
    pass_event = ratio_e >= 3.0
    print(f"  • Construcción >= 5x:   {'✓ CUMPLE' if pass_build else '✗ NO CUMPLE'} ({ratio_b:.1f}x)")
    print(f"  • Cambio evento >= 3x:  {'✓ CUMPLE' if pass_event else '✗ NO CUMPLE'} ({ratio_e:.1f}x)")

    if pass_build and pass_event:
        print("\n>> VEREDICTO: LUZ VERDE PARA FASE 1 (PILOTO CANVAS)")
    else:
        print("\n>> VEREDICTO: DETENERSE Y REPORTAR (NO CUMPLE CRITERIOS)")
    print("=" * 65)

if __name__ == "__main__":
    main()
