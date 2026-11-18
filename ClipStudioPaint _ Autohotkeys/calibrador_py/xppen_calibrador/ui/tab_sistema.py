"""Pestaña 3 · ⚙ Sistema y perfiles: perfil/escalas, botones del script, backup del INI, píldoras y acceso rápido."""
from __future__ import annotations
import tkinter as tk
from datetime import datetime
from tkinter import messagebox
import customtkinter as ctk
from . import theme as T
from .cards import Card, CheckGrid, TabCtx
from .widgets import lbl, btn, combo, entry, Hint
from ..core.ini_schema import PERFILES, PILDORAS, ACCESOS

ICONOS_ACC = {"frente": "📌", "estabilizador": "🎚", "voltear": "⇋", "modo_enfoque": "🔍",
              "layout_paneles": "▤", "acciones_rapidas": "⚡", "restaurar_audio": "🔊"}
ACC_ITEMS = tuple((k, f"{ICONOS_ACC.get(k, '')}  {t}".strip()) for k, t, _ in ACCESOS)


def perfil_label(valor: str) -> str:
    return PERFILES.get(str(valor), f"Perfil {valor}")


class PerfilForm(ctk.CTkFrame):
    """Perfil de equipo + escalas. `readonly=True` = vista previa de temas (misma pieza, sin edición)."""
    def __init__(self, master, tc: TabCtx, tint=None, readonly=False):
        super().__init__(master, fg_color="transparent", width=0, height=0)
        self.tc, self.readonly = tc, readonly
        self.grid_columnconfigure(1, weight=1)
        lbl(self, "Perfil de equipo:", 12, T.TXT).grid(row=0, column=0, sticky="w", pady=4)
        self.cb = combo(self, list(PERFILES.values()), command=self._perfil, width=170)
        self.cb.grid(row=0, column=1, columnspan=2, sticky="ew", padx=(10, 0), pady=3 if readonly else 4)
        self.ents: dict[str, ctk.CTkEntry] = {}
        for r, (name, txt, nota) in enumerate((("escala_botones", "Escala de botones (%):", "(al guardar)"),
                                               ("escala_avisos", "Escala de avisos (%):", "(HUD, mini-textos)")), start=1):
            lbl(self, txt, 12, T.TXT).grid(row=r, column=0, sticky="w", pady=4)
            e = entry(self, 74)
            e.grid(row=r, column=1, sticky="w", padx=(10, 8), pady=4)
            lbl(self, nota, 11, T.TXT2).grid(row=r, column=2, sticky="w")
            e.bind("<Return>", lambda _e, n=name: self._commit(n))
            e.bind("<FocusOut>", lambda _e, n=name: self._commit(n))
            self.ents[name] = e
        self.hint = Hint(self, "El cambio de perfil se aplica al guardar y reiniciar el script.", 10)
        if not readonly:
            self.hint.grid(row=3, column=0, columnspan=3, sticky="ew", pady=(4, 0))
        else:
            self.cb.configure(state="disabled", text_color_disabled=T.TXT)
            for e in self.ents.values():
                e.configure(state="disabled")
        self.refresh()

    def _d(self):
        return self.tc.draft

    def refresh(self):
        val = self._d().get("perfil_equipo", "")
        if self.readonly:
            self.cb.configure(state="normal")
        self.cb.set(perfil_label(str(val)))
        if self.readonly:
            self.cb.configure(state="disabled")
        for n, e in self.ents.items():
            if self.readonly:
                e.configure(state="normal")
            if self.focus_get() is not getattr(e, "_entry", None):
                e.delete(0, "end")
                e.insert(0, str(self._d().get(n, "")))
            e.configure(border_color=T.FIELD_BORDER)
            if self.readonly:
                e.configure(state="disabled")

    def _perfil(self, label: str):
        val = next((k for k, v in PERFILES.items() if v == label), None)
        if val is not None and self._d().set("perfil_equipo", "", val):
            self.tc.on_dirty()

    def _commit(self, name: str):
        e = self.ents[name]
        if self._d().set(name, "", e.get()):
            e.configure(border_color=T.FIELD_BORDER)
            self.tc.on_dirty()
        else:
            e.configure(border_color=T.DANGER)


class SistemaTab(ctk.CTkFrame):
    def __init__(self, master, tc: TabCtx):
        super().__init__(master, fg_color="transparent")
        self.tc = tc
        self.grid_columnconfigure((0, 1), weight=1, uniform="sis")
        self.grid_rowconfigure(0, weight=1)
        izq = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        izq.grid(row=0, column=0, sticky="nsew", padx=(0, 6))
        der = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        der.grid(row=0, column=1, sticky="nsew", padx=(6, 0))
        for f in (izq, der):
            f.grid_columnconfigure(0, weight=1)
        # izquierda
        c1 = Card(izq, "Perfil y escalas", "👤")
        c1.grid(row=0, column=0, sticky="ew")
        c1.body.grid_columnconfigure(0, weight=1)
        self.perfil = PerfilForm(c1.body, tc)
        self.perfil.grid(row=0, column=0, sticky="ew")
        c2 = Card(izq, "Botones del script y paneles de CSP", "🔧")
        c2.grid(row=1, column=0, sticky="ew", pady=(8, 0))
        b = c2.body
        b.grid_columnconfigure((0, 1, 2), weight=1, uniform="lay")
        btn(b, "🔒  Fijar botones", lambda: tc.send("LOCK_BUTTONS", ok_msg="Botones fijados/desfijados")).grid(row=0, column=0, columnspan=2, sticky="ew", padx=(0, 4))
        btn(b, "↻  Reubicar botones", lambda: tc.send("RELOCATE_BUTTONS", ok_msg="Botones reubicados")).grid(row=0, column=2, sticky="ew", padx=(4, 0))
        lbl(b, "Layout de paneles de CSP (guardar / aplicar):", 11, T.TXT2).grid(row=1, column=0, columnspan=3, sticky="w", pady=(10, 4))
        btn(b, "💾  Normal", lambda: tc.send("LAYOUT_SAVE", "normal", ok_msg="Layout Normal guardado")).grid(row=2, column=0, sticky="ew", padx=(0, 4))
        btn(b, "💾  Enfoque", lambda: tc.send("LAYOUT_SAVE", "enfoque", ok_msg="Layout Enfoque guardado")).grid(row=2, column=1, sticky="ew", padx=4)
        btn(b, "▶  Aplicar", lambda: tc.send("LAYOUT_APPLY", tc.modo().lower(), ok_msg="Layout aplicado")).grid(row=2, column=2, sticky="ew", padx=(4, 0))
        c3 = Card(izq, "Copia de seguridad de posiciones_gui.ini", "🗂")
        c3.grid(row=2, column=0, sticky="ew", pady=(8, 0))
        b = c3.body
        b.grid_columnconfigure((0, 1), weight=1, uniform="bk")
        btn(b, "💾  Crear backup", self._backup).grid(row=0, column=0, sticky="ew", padx=(0, 4))
        self.b_rest = btn(b, "⇄  Restaurar último", self._restaurar)
        self.b_rest.grid(row=0, column=1, sticky="ew", padx=(4, 0))
        self.l_bk = lbl(b, "", 11, T.TXT2)
        self.l_bk.grid(row=1, column=0, columnspan=2, sticky="w", pady=(6, 0))
        # derecha
        c4 = Card(der, "Píldoras — marcar = mostrar", "💊")
        c4.grid(row=0, column=0, sticky="ew")
        c4.body.grid_columnconfigure(0, weight=1)
        self.pil = CheckGrid(c4.body, PILDORAS, lambda k: self.tc.draft.get(f"pil_{k}", ""), self._set_pil, cols=2)
        self.pil.grid(row=0, column=0, sticky="ew")
        Hint(c4.body, "Marcado = la píldora se muestra (por defecto nacen ocultas). Clic derecho en una píldora abre el menú.").grid(
            row=1, column=0, sticky="ew", pady=(6, 0))
        c5 = Card(der, "Acceso rápido — menú clic derecho", "⚡")
        c5.grid(row=1, column=0, sticky="ew", pady=(8, 0))
        c5.body.grid_columnconfigure(0, weight=1)
        self.acc = CheckGrid(c5.body, ACC_ITEMS, lambda k: self.tc.draft.get(f"acc_{k}", ""), self._set_acc, cols=2)
        self.acc.grid(row=0, column=0, sticky="ew")
        Hint(c5.body, "Marcado = aparece en el anticlick del companion. Sin marcar = solo desde aquí.").grid(
            row=1, column=0, sticky="ew", pady=(6, 0))
        self.refresh()

    # ── datos ──────────────────────────────────────────────
    def _set_pil(self, k, v):
        self.tc.draft.set(f"pil_{k}", "", v)
        self.tc.on_dirty()

    def _set_acc(self, k, v):
        self.tc.draft.set(f"acc_{k}", "", v)
        self.tc.on_dirty()

    def refresh(self):
        self.perfil.refresh()
        self.pil.refresh()
        self.acc.refresh()
        self._estado_backup()

    # ── backups ────────────────────────────────────────────
    def _estado_backup(self):
        bks = self.tc.store.backups()
        if bks:
            ts = datetime.fromtimestamp(bks[-1].stat().st_mtime).strftime("%d/%m/%Y %H:%M")
            self.l_bk.configure(text=f"{len(bks)} backup{'s' if len(bks) != 1 else ''} · último: {ts}")
        else:
            self.l_bk.configure(text="Sin backups todavía.")
        self.b_rest.configure(state="normal" if bks else "disabled", text_color=T.TXT if bks else T.TXT3)

    def _backup(self):
        try:
            dst = self.tc.store.backup_now()
        except OSError as e:
            self.tc.flash(f"✗ {e}", False)
            return
        self._estado_backup()
        self.tc.flash(f"✓ Backup creado: {dst.name}")

    def _restaurar(self):
        bks = self.tc.store.backups()
        if not bks:
            return
        if not messagebox.askyesno("Restaurar último backup",
                                   f"Se reemplazará {self.tc.store.path.name} por:\n{bks[-1].name}\n\nLos cambios sin guardar se descartan. ¿Continuar?",
                                   parent=self.winfo_toplevel()):
            return
        try:
            self.tc.store.restore_last()
        except OSError as e:
            self.tc.flash(f"✗ {e}", False)
            return
        self.tc.draft.clear()
        self.tc.reload_all()
        self.tc.send("RELOAD_INI", ok_msg="✓ Backup restaurado")
