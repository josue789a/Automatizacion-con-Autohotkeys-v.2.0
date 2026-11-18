"""Pestaña 4 · ⬢ Paleta de temas: 15 temas de theme.ini con chips, descripción, Probar/Aplicar y vista previa."""
from __future__ import annotations
import tkinter as tk
import customtkinter as ctk
from . import lite
from . import theme as T
from .cards import Card, CheckGrid, TabCtx
from .tab_sistema import PerfilForm, ACC_ITEMS
from .widgets import lbl, btn
from ..core import temas as TM
from ..core.ini_schema import PILDORAS

PREV_PIL = PILDORAS[0], PILDORAS[2], PILDORAS[4], PILDORAS[6]      # Bloquear, Recargar, Ventana, Slider


class _RowBg:
    """API de CTkFrame usada por _pintar(): configure(fg_color=...)."""
    def __init__(self, lst, i): self.l, self.i = lst, i
    def configure(self, **kw):
        if "fg_color" in kw:
            self.l.set_bg(self.i, kw["fg_color"])
    def bind(self, *a, **k): pass


class _RowName:
    """API de CTkLabel usada por _pintar(): configure(text_color=, font=)."""
    def __init__(self, lst, i): self.l, self.i = lst, i
    def configure(self, **kw):
        if "text_color" in kw or "font" in kw:
            self.l.set_name(self.i, kw.get("text_color"), kw.get("font"))
    def bind(self, *a, **k): pass


class TemasList:
    """Lista de temas en UN canvas: nombre + franja rectangular continua de 5 colores."""
    ROW_H, PAD = 28, 10

    def __init__(self, parent, temas, on_select):
        self.temas, self.on_select = list(temas), on_select
        n = len(self.temas)
        self.body = lite.LiteScroll(parent, T.CARD)     # tk.Frame con canvas + barra
        self.cv = self.body.cv
        self.f = lite.tk_font(self.body, T.font(11))
        self.fb = lite.tk_font(self.body, T.font(11, True))
        self._bg = [""] * n
        self._fg = [lite.c(T.TXT)] * n
        self._bold = [False] * n
        self._rect, self._txt = {}, {}
        self._job = None
        self.rows = [{"frame": _RowBg(self, i), "name": _RowName(self, i)} for i in range(n)]
        self.cv.bind("<Configure>", self._sched, add="+")
        self.cv.bind("<Button-1>", self._click)

    # ---- estado (lo escribe _pintar a través de los proxies) ----
    def set_bg(self, i, color):
        self._bg[i] = "" if color in (None, "", "transparent") else lite.c(color)
        it = self._rect.get(i)
        if it:
            self.cv.itemconfigure(it, fill=self._bg[i])

    def set_name(self, i, color, font):
        if color is not None:
            self._fg[i] = lite.c(color)
        if font is not None:
            try:
                self._bold[i] = font.cget("weight") == "bold"
            except Exception:
                pass
        it = self._txt.get(i)
        if it:
            self.cv.itemconfigure(it, fill=self._fg[i], font=self.fb if self._bold[i] else self.f)

    # ---- dibujo ----
    def _sched(self, _e=None):
        if self._job is None:
            self._job = self.body.after_idle(self._layout)

    def _layout(self):
        self._job = None
        cv = self.cv
        if not cv.winfo_exists():
            return
        w = cv.winfo_width()
        if w < 120:
            return
        s = lambda v: lite.scale(cv, v)
        rh, pad, m = s(self.ROW_H), s(self.PAD), s(6)
        seg = max(s(20), min(s(52), int(w * 0.42) // 5))
        sw = seg * 5
        x0 = w - pad - sw
        cv.delete("all")
        self._rect, self._txt = {}, {}
        for i, t in enumerate(self.temas):
            y0 = i * rh
            self._rect[i] = cv.create_rectangle(0, y0, w, y0 + rh, width=0, fill=self._bg[i])
            self._txt[i] = cv.create_text(pad, y0 + rh // 2, text=t.nombre, anchor="w",
                                          fill=self._fg[i],
                                          font=self.fb if self._bold[i] else self.f)
            for k, col in enumerate(t.swatches):          # 5 segmentos contiguos = una franja
                cv.create_rectangle(x0 + k * seg, y0 + m, x0 + (k + 1) * seg, y0 + rh - m,
                                    width=0, fill=f"#{col}")
        self.body.set_height(len(self.temas) * rh + s(4))

    def _click(self, e):
        rh = lite.scale(self.cv, self.ROW_H)
        i = int(self.cv.canvasy(e.y) // rh)
        if 0 <= i < len(self.temas):
            self.on_select(i)


class _Chip:
    def __init__(self, strip, i): self.s, self.i = strip, i
    def configure(self, **kw):
        if "fg_color" in kw:
            self.s.set(self.i, kw["fg_color"])


class MuestrasStrip:
    """Franja continua de N muestras en un solo canvas."""
    def __init__(self, parent, n=8, h=30):
        self.n = n
        self.cv = tk.Canvas(parent, bg=lite.c(T.CARD), highlightthickness=0, bd=0,
                            takefocus=0, height=lite.scale(parent, h))
        self._items = [self.cv.create_rectangle(0, 0, 0, 0, width=0, fill="#CCCCCC") for _ in range(n)]
        self._job = None
        self.chips = [_Chip(self, i) for i in range(n)]
        self.cv.bind("<Configure>", self._sched, add="+")

    def set(self, i, color):
        self.cv.itemconfigure(self._items[i], fill=color)

    def _sched(self, _e=None):
        if self._job is None:
            self._job = self.cv.after_idle(self._layout)

    def _layout(self):
        self._job = None
        if not self.cv.winfo_exists():
            return
        w, h = self.cv.winfo_width(), self.cv.winfo_height()
        for i, it in enumerate(self._items):
            self.cv.coords(it, round(i * w / self.n), 0, round((i + 1) * w / self.n), h)


class TemasTab(ctk.CTkFrame):
    def __init__(self, master, tc: TabCtx):
        super().__init__(master, fg_color="transparent")
        self.tc = tc
        self.temas = TM.cargar(tc.data_dir)
        self.sel = TM.activo(tc.theme_store, self.temas) or 0
        self.rows: list[dict] = []
        self.grid_columnconfigure(0, weight=3, uniform="tm")
        self.grid_columnconfigure(1, weight=2, uniform="tm")
        self.grid_rowconfigure(0, weight=1)
        self._build_izq()
        self._build_der()
        self.refresh()

    # ── izquierda: tabla + descripción + botones ───────────
    def _build_izq(self):
        self.card = Card(self, "Tema activo", "🎨")
        self.card.grid(row=0, column=0, sticky="nsew", padx=(0, 6))
        b = self.card.body
        b.grid_columnconfigure(0, weight=1)
        b.grid_rowconfigure(0, weight=1)
        tabla = ctk.CTkFrame(b, fg_color=T.CARD, corner_radius=8, border_width=1, border_color=T.BORDER)
        tabla.grid(row=0, column=0, sticky="nsew")
        tabla.grid_columnconfigure(0, weight=1)
        tabla.grid_rowconfigure(1, weight=1)
        hdr = ctk.CTkFrame(tabla, fg_color=T.SOFT, corner_radius=6, height=26)
        hdr.grid(row=0, column=0, sticky="ew", padx=2, pady=2)
        hdr.grid_columnconfigure(0, weight=1)
        lbl(hdr, "Paleta", 11, T.TXT, True).grid(row=0, column=0, sticky="w", padx=8, pady=3)
        lbl(hdr, "Muestra", 11, T.TXT, True, anchor="e").grid(row=0, column=1, sticky="e", padx=12, pady=3)

        self.lista = TemasList(tabla, self.temas, self.select)
        self.lst = self.lista.body
        self.lst.grid(row=1, column=0, sticky="nsew")
        self.rows = self.lista.rows
        self.desc = lbl(b, "", 11, T.TXT2, wrap=420)
        self.desc.grid(row=1, column=0, sticky="ew", pady=(8, 4))
        bar = ctk.CTkFrame(b, fg_color="transparent", width=0, height=0)
        bar.grid(row=2, column=0, sticky="ew")
        bar.grid_columnconfigure((0, 1), weight=1, uniform="tb")
        btn(bar, "🔔  Probar", self._probar, height=34).grid(row=0, column=0, sticky="ew", padx=(0, 4))
        self.b_ap = btn(bar, "✔  Aplicar", self._aplicar, primary=True, height=34)
        self.b_ap.grid(row=0, column=1, sticky="ew", padx=(4, 0))

    @staticmethod
    def _cols(f):
        f.grid_columnconfigure(0, weight=1, minsize=170)
        for i in range(5):
            f.grid_columnconfigure(1 + i, weight=0, minsize=58)

    # ── derecha: vista previa ──────────────────────────────
    def _build_der(self):
        self.prev = Card(self, "Vista previa del tema", "🎨")
        self.prev.grid(row=0, column=1, sticky="nsew", padx=(6, 0))
        self.prev.body.grid_columnconfigure(0, weight=1)
        self.prev.body.grid_rowconfigure(0, weight=1)
        b = ctk.CTkScrollableFrame(self.prev.body, fg_color="transparent", corner_radius=0,
                                   scrollbar_button_color="#D9D4E6", scrollbar_button_hover_color=T.ACCENT)
        b.grid(row=0, column=0, sticky="nsew")
        b.grid_columnconfigure(0, weight=1)
        self.c_perfil = Card(b, "Perfil y escalas", "👤", compact=True)
        self.c_perfil.grid(row=0, column=0, sticky="ew")
        self.c_perfil.body.grid_columnconfigure(0, weight=1)
        self.form = PerfilForm(self.c_perfil.body, self.tc, readonly=True)
        self.form.grid(row=0, column=0, sticky="ew")
        self.pil = CheckGrid(self.c_perfil.body, PREV_PIL, lambda k: self.tc.draft.get(f"pil_{k}", ""), None, cols=2, readonly=True, pady=3)
        self.pil.grid(row=1, column=0, sticky="ew", pady=(2, 0))
        self.c_acc = Card(b, "Acceso rápido", "⚡", compact=True)
        self.c_acc.grid(row=1, column=0, sticky="ew", pady=(6, 0))
        self.c_acc.body.grid_columnconfigure(0, weight=1)
        self.acc = CheckGrid(self.c_acc.body, ACC_ITEMS, lambda k: self.tc.draft.get(f"acc_{k}", ""), None, cols=2, readonly=True, pady=3)
        self.acc.grid(row=0, column=0, sticky="ew")
        self.c_mu = Card(b, "Muestras de colores", "🎨", compact=True)
        self.c_mu.grid(row=2, column=0, sticky="ew", pady=(6, 0))
        self.c_mu.body.grid_columnconfigure(0, weight=1)
        self.muestras = MuestrasStrip(self.c_mu.body, 8, 30)
        self.mu = self.muestras.cv
        self.mu.grid(row=0, column=0, sticky="ew")
        self.chips = self.muestras.chips

    # ── lógica ─────────────────────────────────────────────
    def refresh(self):
        self.form.refresh()
        self.pil.refresh()
        self.acc.refresh()
        self._pintar()

    def on_external_change(self):
        self.refresh()

    def select(self, i: int):
        self.sel = i
        self._pintar()

    def _aplicado(self) -> int | None:
        return TM.activo(self.tc.theme_store, self.temas)

    def _pintar(self):
        if not self.temas:
            self.card.title.configure(text="🎨  Sin temas (falta data/temas.json)")
            return
        ap, t = self._aplicado(), self.temas[self.sel]
        self.card.title.configure(text=f"🎨  Tema activo: {self.temas[ap].nombre}" if ap is not None else "🎨  Tema activo: (personalizado)")
        for i, r in enumerate(self.rows):
            on = i == self.sel
            r["frame"].configure(fg_color=T.SOFT if on else "transparent")
            r["name"].configure(text_color=T.PRIMARY if on else T.TXT, font=T.font(11, on or i == ap))
        self.desc.configure(text=t.desc + ("" if ap == self.sel else "   (seleccionado · aún sin aplicar)"))
        self.b_ap.configure(state="disabled" if ap == self.sel else "normal")
        c1, c2, c3, c4, c5 = t.swatches
        for w in (self.card, self.prev):
            w.bar.configure(fg_color=f"#{c4}")
        for card in (self.c_perfil, self.c_acc, self.c_mu):
            card.bar.configure(fg_color=f"#{c4}")
        for grid in (self.pil, self.acc):
            for ch in grid.winfo_children():
                ch.configure(fg_color=f"#{c4}", hover_color=f"#{c4}", border_color=f"#{c1}")
        for chip, col in zip(self.chips, TM.muestras(t)):
            chip.configure(fg_color=f"#{col}")

    def _probar(self):
        if not self.temas:
            return
        t = self.temas[self.sel]
        self.tc.send("TEST_HUD", "estab_slider", t.swatches[3], ok_msg=f"Probando «{t.nombre}»")

    def _aplicar(self):
        if not self.temas:
            return
        t = self.temas[self.sel]
        st = self.tc.theme_store
        try:
            st.save_patches(TM.parches(t))          # atómico: tmp + os.replace (+ respaldo de sesión)
        except OSError as e:
            self.tc.flash(f"✗ {e}", False)
            return
        self.tc.send("RELOAD_THEME", t.nombre, ok_msg=f"✓ Tema «{t.nombre}» aplicado")
        self._pintar()
