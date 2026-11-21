"""Piezas compartidas por las pestañas 2-4: contexto, tarjeta con barra de acento y rejilla de checks."""
from __future__ import annotations
import tkinter as tk
from dataclasses import dataclass
from pathlib import Path
from typing import Callable
import customtkinter as ctk
from . import theme as T
from .widgets import lbl


@dataclass
class TabCtx:
    """Lo que las pestañas necesitan de la app (sin acoplarse a CalibradorApp)."""
    draft: object                       # core.draft.Draft sobre posiciones_gui.ini
    store: object                       # core.ini_store.IniFile de posiciones_gui.ini
    bridge: object                      # core.ahk_bridge.AhkBridge
    theme_store: object                 # IniFile de theme.ini
    data_dir: Path
    modo: Callable[[], str]             # "Normal" | "Enfoque" (modo de trabajo actual)
    on_dirty: Callable[[], None]
    flash: Callable[..., None]          # flash(texto, ok=True)
    reload_all: Callable[[], None]      # releer INI y refrescar todas las pestañas

    def send(self, cmd: str, *args, ok_msg: str | None = None) -> bool:
        ok = self.bridge.send(cmd, *args)
        if ok and ok_msg:
            self.flash(ok_msg)
        elif not ok:
            self.flash("✗ AHK no respondió" if self.bridge.conectado else "AHK no conectado (comando registrado)", False)
        return ok


class Card(ctk.CTkFrame):
    """Tarjeta del mockup: barra de acento + icono/título (+ subtítulo) y un `body` para el contenido."""
    def __init__(self, master, title: str, icon: str = "", sub: str = "", accent: str = T.ACCENT, compact: bool = False):
        super().__init__(master, fg_color=T.CARD, corner_radius=10, border_width=1, border_color=T.BORDER)
        self.grid_columnconfigure(0, weight=1)
        import tkinter as tk
        hd = tk.Frame(self, bg=T.CARD, bd=0, highlightthickness=0)
        hd.grid(row=0, column=0, sticky="ew", padx=T.PAD, pady=(6, 2) if compact else (10, 4))
        hd.grid_columnconfigure(2, weight=1)

        class BarFrame(tk.Frame):
            def configure(self, cnf=None, **kw):
                if "fg_color" in kw:
                    kw["bg"] = kw.pop("fg_color")
                super().configure(cnf, **kw)

        self.bar = BarFrame(hd, width=4, height=18, bg=accent, bd=0, highlightthickness=0)
        self.bar.grid(row=0, column=0, rowspan=2, padx=(0, 8), sticky="ns")
        self.title = tk.Label(hd, text=f"{icon}  {title}".strip(), bg=T.CARD, fg=T.TXT,
                              font=T.font(13, True), bd=0, padx=0, pady=0, anchor="w")
        self.title.grid(row=0, column=1, columnspan=2, sticky="w")
        if sub:
            self.sub = tk.Label(hd, text=sub, bg=T.CARD, fg=T.TXT2,
                                font=T.font(10), bd=0, padx=0, pady=0, anchor="w")
            self.sub.grid(row=1, column=1, columnspan=2, sticky="w")
        self.body = tk.Frame(self, bg=T.CARD, bd=0, highlightthickness=0)
        self.body.grid(row=1, column=0, sticky="nsew", padx=T.PAD, pady=(0, 8) if compact else (2, T.PAD))
        self.grid_rowconfigure(1, weight=1)


class CheckGrid(ctk.CTkFrame):
    """Rejilla de checks en N columnas. `tint` = (color_marca, color_borde) para la vista previa de temas."""
    def __init__(self, master, items, get, set_, cols=2, tint=None, readonly=False, pady=5):
        super().__init__(master, fg_color="transparent", width=0, height=0)
        self.items, self.get, self.set_, self.readonly = items, get, set_, readonly
        self.vars: dict[str, tk.IntVar] = {}
        for i, (key, text) in enumerate(items):
            self.grid_columnconfigure(i % cols, weight=1, uniform="cg")
            v = tk.IntVar(value=0)
            c = ctk.CTkCheckBox(self, text=text, variable=v, font=T.font(12), text_color=T.TXT,
                                fg_color=(tint[0] if tint else T.ACCENT), hover_color=(tint[0] if tint else T.PRIMARY),
                                border_color=(tint[1] if tint else T.FIELD_OFF), checkmark_color="white",
                                checkbox_width=18, checkbox_height=18, corner_radius=5, border_width=2,
                                command=lambda k=key, vv=v: self._click(k, vv))
            if readonly:
                c.configure(state="disabled", text_color_disabled=T.TXT)
            c.grid(row=i // cols, column=i % cols, sticky="w", padx=(4, 2), pady=pady)
            self.vars[key] = v
        self.refresh()

    def _click(self, key, var):
        if not self.readonly:
            self.set_(key, var.get())

    def refresh(self):
        for key, v in self.vars.items():
            nv = 1 if self.get(key) else 0
            if v.get() != nv:
                v.set(nv)
