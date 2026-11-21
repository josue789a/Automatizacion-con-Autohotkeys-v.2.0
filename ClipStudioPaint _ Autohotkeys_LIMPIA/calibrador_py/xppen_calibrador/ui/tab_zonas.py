"""Pestaña 2 · ✎ Zonas y rangos: tabla editable de zonas por modo + herramientas globales Δ."""
from __future__ import annotations
import time
import tkinter as tk
import tkinter.font as tkfont
from tkinter import messagebox
import customtkinter as ctk
from . import theme as T
from . import lite
from .cards import Card, TabCtx
from .widgets import lbl, btn, switch, Stepper
from ..core import zonas as Z

COLS = (("x", "X"), ("y", "Y"), ("w", "Ancho"), ("h", "Alto"))
CHAIN_TIMEOUT_S = 120
SEL_BG = T.SOFT


class _Null:
    """Sustituye a los labels de fila (nm, tp) que ya no existen."""
    def configure(self, *a, **k): pass
    def bind(self, *a, **k): pass


class _RowProxy:
    """API de CTkFrame que usa _paint(): configure(fg_color=...)."""
    def __init__(self, tbl, zid): self.t, self.zid = tbl, zid
    def configure(self, **kw):
        if "fg_color" in kw:
            self.t.paint_row(self.zid, kw["fg_color"])
    def bind(self, *a, **k): pass


class _Cell:
    """API de CTkEntry que usan refresh() y _commit(): get/delete/insert."""
    def __init__(self, tbl, zid, col): self.t, self.zid, self.col = tbl, zid, col
    def get(self): return self.t.vals[(self.zid, self.col)]
    def delete(self, *a): self.t._set(self.zid, self.col, "")
    def insert(self, _i, txt): self.t._set(self.zid, self.col, str(txt))
    def configure(self, *a, **k): pass
    @property
    def _entry(self): return self.t._ed if self.t._ed_key == (self.zid, self.col) else None


class ZonasTable:
    """Tabla de zonas en dos canvas (cabecera fija + cuerpo con scroll) y UN editor flotante."""
    ROW_H, HDR_H, PAD = 25, 26, 10

    def __init__(self, parent, zonas, cols, on_select, on_commit):
        self.zonas, self.cols = list(zonas), list(cols)
        self.byid = {z.id: z for z in self.zonas}
        self.on_select, self.on_commit = on_select, on_commit   # on_commit(zona, col)
        self._cols_edit = ("desc",) + tuple(c for c, _ in self.cols)   # orden de Tab
        self.vals = {(z.id, col): "" for z in self.zonas for col in self._cols_edit}
        self._items, self._rects, self._sel = {}, {}, {}
        self._ed = self._ed_key = self._ed_win = None
        self._job = None
        self._rh = 0
        self.xs = {}
        self._idx_w = 0             # columna Puntos (índice P1..Pn)
        self._zone_x = 0            # inicio de la columna Zona
        self._zone_x1 = 0           # fin de la columna Zona (concatenada)
        self._desc_x = (0, 0)       # columna Descripción

        self.frame = ctk.CTkFrame(parent, fg_color="transparent", corner_radius=0, border_width=0)
        self.frame.grid_columnconfigure(0, weight=1)
        self.frame.grid_rowconfigure(1, weight=1)
        self.body = lite.LiteScroll(self.frame, T.CARD, sb_kw=dict(button_color="#D9D4E6", button_hover_color=T.ACCENT))
        self.cv = self.body.cv
        self.cv.configure(height=lite.scale(self.frame, 275))   # vista compacta (~11 filas visibles)
        self.hdr = tk.Canvas(self.frame, bg=lite.c(T.SOFT), highlightthickness=0, bd=0,
                             takefocus=0, height=lite.scale(self.frame, self.HDR_H))
        self.hdr.grid(row=0, column=0, sticky="ew", padx=(0, self.body.sb_px()))
        self.body.grid(row=1, column=0, sticky="nsew")

        self.f = lite.tk_font(self.frame, T.font(11))
        self.fb = self.f.copy()
        self.fb.configure(weight="bold")

        self.rows = {}
        for z in self.zonas:
            n = _Null()
            self.rows[z.id] = {"frame": _RowProxy(self, z.id), "zona": z, "labels": (n, n),
                               "ents": {col: _Cell(self, z.id, col) for col in self._cols_edit}}

        self.cv.bind("<Configure>", self._sched_layout, add="+")
        self.cv.bind("<Button-1>", self._on_click)
        self.cv.bind("<Motion>", self._on_motion)
        self.cv.bind("<Leave>", lambda _e: self.cv.itemconfigure("hover", state="hidden"))

    # ---------- datos ----------
    def _set(self, zid, col, txt):
        self.vals[(zid, col)] = txt
        raw = txt
        it = self._items.get((zid, col))
        if it:
            if col == "desc":
                a, b = self._desc_x
                txt = self._fit(txt, b - a - lite.scale(self.cv, 4))
            self.cv.itemconfigure(it, text=txt)
        if self._ed_key == (zid, col) and self._ed is not None:
            self._ed.delete(0, "end")
            self._ed.insert(0, raw)
        self._sched_layout()

    def set_zonas(self, nuevas_zonas):
        """Actualiza la lista de zonas (p. ej. al descubrir zonas de eventos dinámicas)."""
        nuevas = list(nuevas_zonas)
        if [z.id for z in nuevas] == [z.id for z in self.zonas]:
            return
        self.zonas = nuevas
        self.byid = {z.id: z for z in self.zonas}
        for z in self.zonas:
            for col in self._cols_edit:
                if (z.id, col) not in self.vals:
                    self.vals[(z.id, col)] = ""
            if z.id not in self.rows:
                n = _Null()
                self.rows[z.id] = {"frame": _RowProxy(self, z.id), "zona": z, "labels": (n, n),
                                   "ents": {col: _Cell(self, z.id, col) for col in self._cols_edit}}
        self._sched_layout()

    def paint_row(self, zid, color):
        self._sel[zid] = None if color in (None, "", "transparent") else lite.c(color)
        self._apply_sel(zid)

    def _apply_sel(self, zid):
        it, color = self._rects.get(zid), self._sel.get(zid)
        if it is None:
            return
        if color:
            self.cv.itemconfigure(it, fill=color, state="normal")
        else:
            self.cv.itemconfigure(it, state="hidden")

    # ---------- layout / dibujo ----------
    def _sched_layout(self, _e=None):
        if self._job is None:
            self._job = self.frame.after_idle(self._layout)

    def _fit(self, txt, px: int, font=None) -> str:
        """Recorta el texto con «…» para que no invada la columna siguiente."""
        txt = "" if txt is None else str(txt)
        f = font or self.f
        if px <= 8 or not txt:
            return "" if px <= 8 else txt
        if f.measure(txt) <= px:
            return txt
        while txt and f.measure(txt + "…") > px:
            txt = txt[:-1]
        return txt + "…"

    def _layout(self):
        self._job = None
        cv = self.cv
        if not cv.winfo_exists():
            return
        self._close_editor(True)
        w = cv.winfo_width()
        if w < 80:
            return
        s = lambda v: lite.scale(cv, v)
        rh, pad = s(self.ROW_H), s(self.PAD)
        gap, right = s(12), s(4)
        avail = w - pad - right

        # 1 · ancho mínimo de cada columna = su contenido más ancho (título incluido)
        def minimo(titulo, textos, pad_x=None):
            px = self.fb.measure(str(titulo))
            for t in textos:
                px = max(px, self.f.measure(str(t)))
            return px + (s(16) if pad_x is None else pad_x)

        zonas_txt = [f"{z.zid}  ·  {z.nombre}" if z.zid else z.nombre for z in self.zonas]
        idx_min = minimo("Puntos", [f"P{r + 1}" for r in range(len(self.zonas))])
        zona_min = minimo("Zona", zonas_txt)
        desc_min = minimo("Descripción de eventos", [self.vals[(z.id, "desc")] for z in self.zonas])
        num_min = {col: minimo(tx, [self.vals[(z.id, col)] for z in self.zonas]) for col, tx in self.cols}

        # 2 · Zona se queda en su ancho de contenido (así Descripción arranca pegado
        #     a la izquierda, no a media tabla) y todo el sobrante va a Descripción.
        libre = avail - (idx_min + zona_min + desc_min + sum(num_min.values()) + 3 * gap)
        if libre > 0:
            desc_w, zona_w = desc_min + libre, zona_min
        else:
            falta, desc_w, zona_w = -libre, desc_min, zona_min
            for attr in ("desc", "zona"):
                piso = s(90) if attr == "desc" else s(80)
                actual = desc_w if attr == "desc" else zona_w
                cut = min(falta, max(0, actual - piso))
                if attr == "desc":
                    desc_w -= cut
                else:
                    zona_w -= cut
                falta -= cut
            if falta > 0 and num_min:
                factor = max(0.0, 1 - falta / sum(num_min.values()))
                num_min = {c: max(s(40), int(v * factor)) for c, v in num_min.items()}

        # 3 · posiciones reales
        self._idx_w = int(idx_min)
        self._zone_x = pad + self._idx_w + gap
        zona_w = max(s(60), int(zona_w))
        self._zone_x1 = self._zone_x + zona_w
        desc_x0 = self._zone_x1 + gap
        desc_w = max(s(60), int(desc_w))
        self._desc_x = (desc_x0, desc_x0 + desc_w)
        self._rh = rh
        x = self._desc_x[1] + gap
        self.xs = {}
        for col, _ in self.cols:
            self.xs[col] = (x, x + int(num_min[col]))
            x = self.xs[col][1]

        txt, txt2 = lite.c(T.TXT), lite.c(T.TXT2)
        # cabecera
        h, hy = self.hdr, s(self.HDR_H) // 2
        h.delete("all")
        h.create_text(pad, hy, text="Puntos", anchor="w", fill=txt, font=self.fb)
        h.create_text(self._zone_x, hy, text="Zona", anchor="w", fill=txt, font=self.fb)
        h.create_text(desc_x0 + s(2), hy, text=self._fit("Descripción de eventos", desc_w - s(4), self.fb),
                      anchor="w", fill=txt, font=self.fb)
        for col, tx in self.cols:
            a, b = self.xs[col]
            h.create_text((a + b) // 2, hy, text=tx, fill=txt, font=self.fb)
        # cuerpo (orden de capas: rects de fila < hover < textos)
        cv.delete("all")
        self._items, self._rects = {}, {}
        for r, z in enumerate(self.zonas):
            self._rects[z.id] = cv.create_rectangle(0, r * rh, w, (r + 1) * rh, width=0, state="hidden")
        cv.create_rectangle(0, 0, 0, 0, width=0, fill=lite.c(T.SOFT), state="hidden", tags=("hover",))
        d0, d1 = self._desc_x
        for r, z in enumerate(self.zonas):
            yc = r * rh + rh // 2
            cv.create_text(pad, yc, text=f"P{r + 1}", anchor="w", fill=txt, font=self.fb)
            cv.create_text(self._zone_x, yc, text=self._fit(zonas_txt[r], zona_w - s(4)), anchor="w",
                           fill=txt, font=self.f)
            self._items[(z.id, "desc")] = cv.create_text(
                d0 + s(2), yc, text=self._fit(self.vals[(z.id, "desc")], d1 - d0 - s(4)),
                anchor="w", fill=txt2, font=self.f)
            for col, _ in self.cols:
                a, b = self.xs[col]
                self._items[(z.id, col)] = cv.create_text((a + b) // 2, yc, fill=txt, font=self.f,
                                                          text=self.vals[(z.id, col)])
        for zid in self._sel:
            self._apply_sel(zid)
        self.body.set_height(len(self.zonas) * rh + s(6))

    # ---------- interacción ----------
    def _hit(self, ex, ey):
        if not self._rh:
            return -1, None
        r = int(self.cv.canvasy(ey) // self._rh)
        if not 0 <= r < len(self.zonas):
            return -1, None
        d0, d1 = self._desc_x
        if d0 <= ex < d1:
            return r, "desc"
        for col, (a, b) in self.xs.items():
            if a <= ex < b:
                return r, col
        return r, None

    def _on_motion(self, e):
        r, col = self._hit(e.x, e.y)
        if r < 0 or col is None:
            self.cv.itemconfigure("hover", state="hidden")
            self.cv.configure(cursor="")
            return
        a, b = self._desc_x if col == "desc" else self.xs[col]
        m = lite.scale(self.cv, 3)
        self.cv.coords("hover", a + 1, r * self._rh + m, b - 1, (r + 1) * self._rh - m)
        self.cv.itemconfigure("hover", state="normal")
        self.cv.configure(cursor="xterm")

    def _on_click(self, e):
        r, col = self._hit(e.x, e.y)
        self._close_editor(True)
        if r < 0:
            return
        z = self.zonas[r]
        self.on_select(z.id)
        if col:
            self._open_editor(z, col)

    # ---------- editor flotante (uno solo) ----------
    def _ensure_visible(self, r):
        cv, rh = self.cv, self._rh
        vh = cv.winfo_height()
        total = max(len(self.zonas) * rh + lite.scale(cv, 6), vh)
        y0, top = r * rh, cv.canvasy(0)
        if y0 < top:
            cv.yview_moveto(y0 / total)
        elif y0 + rh > top + vh:
            cv.yview_moveto((y0 + rh - vh) / total)

    def _open_editor(self, z, col):
        if not self._rh or col not in self._cols_edit:
            return
        r = self.zonas.index(z)
        self._ensure_visible(r)
        a, b = self._desc_x if col == "desc" else self.xs[col]
        m = lite.scale(self.cv, 3)
        ed = tk.Entry(self.cv, justify="left" if col == "desc" else "center", bd=0, relief="flat",
                      font=self.f, bg=lite.c(T.CARD), fg=lite.c(T.TXT),
                      insertbackground=lite.c(T.TXT), highlightthickness=1,
                      highlightbackground=lite.c(T.BORDER),
                      highlightcolor=lite.c(getattr(T, "ACCENT", T.BORDER)))
        ed.insert(0, self.vals[(z.id, col)])
        self._ed, self._ed_key = ed, (z.id, col)
        self._ed_win = self.cv.create_window(a + 2, r * self._rh + m, anchor="nw",
                                             width=b - a - 4, height=self._rh - 2 * m, window=ed)
        ed.bind("<Return>", lambda _e: (self._close_editor(True), "break")[1])
        ed.bind("<Escape>", lambda _e: (self._close_editor(False), "break")[1])
        ed.bind("<Tab>", lambda _e: self._tab(+1))
        ed.bind("<Shift-Tab>", lambda _e: self._tab(-1))
        ed.bind("<FocusOut>", lambda _e: self._close_editor(True))
        ed.focus_set()
        ed.select_range(0, "end")

    def _tab(self, step):
        if not self._ed_key:
            return "break"
        zid, col = self._ed_key
        cols = list(self._cols_edit)
        r, i = self.zonas.index(self.byid[zid]), cols.index(col) + step
        if i >= len(cols):
            i, r = 0, r + 1
        elif i < 0:
            i, r = len(cols) - 1, r - 1
        r %= len(self.zonas)
        self._close_editor(True)
        z = self.zonas[r]
        self.on_select(z.id)
        self._open_editor(z, cols[i])
        return "break"

    def _close_editor(self, commit):
        if self._ed is None:
            return
        ed, key, win = self._ed, self._ed_key, self._ed_win
        txt = ed.get()
        self._ed = self._ed_key = self._ed_win = None   # antes de destruir: evita reentrada por FocusOut
        self.cv.delete(win)
        ed.destroy()
        if commit and key:
            zid, col = key
            self._set(zid, col, txt)
            self.on_commit(self.byid[zid], col)


class ZonasTab(ctk.CTkFrame):
    def __init__(self, master, tc: TabCtx):
        super().__init__(master, fg_color="transparent")
        self.tc = tc
        self.modo = 1 if tc.modo().lower() == "normal" else 2
        self.sel: str | None = None
        self.rows: dict[str, dict] = {}
        self._expect: Z.Zona | None = None       # zona que AHK está dibujando
        self._chain: dict | None = None
        self._dx = self._dy = 0
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=1)
        self.main = Card(self, "Instrucciones de zonas", "",
                         "Dibuja y configura las zonas de la pantalla para el modo normal o de enfoque.")
        self.main.grid(row=0, column=0, sticky="nsew")
        self.main.body.grid_columnconfigure(0, weight=1)
        self._build_selector()
        self._build_tabla()
        self._build_acciones()
        self._build_herramientas()
        self.refresh()

    # ── construcción ───────────────────────────────────────
    def _etiquetas(self):
        act = 1 if self.tc.modo().lower() == "normal" else 2
        return [f"NORMAL · Modo 1{'  (activo en CSP)' if act == 1 else ''}",
                f"ENFOQUE · Modo 2{'  (activo en CSP)' if act == 2 else ''}"]

    def _build_selector(self):
        self.seg = ctk.CTkSegmentedButton(self.main.body, values=self._etiquetas(), command=self._on_seg, height=34,
                                          corner_radius=8, font=T.font(12, True), text_color="white",
                                          selected_color=T.PRIMARY_HOVER, selected_hover_color=T.PRIMARY_HOVER,
                                          unselected_color="#8F82B3", unselected_hover_color=T.ACCENT,
                                          fg_color="#8F82B3")
        self.seg.grid(row=0, column=0, sticky="w", pady=(0, 8))

    def _build_tabla(self):
        body = self.main.body
        body.grid_rowconfigure(1, weight=1)
        self.tabla = ZonasTable(body, Z.ZONAS, COLS, on_select=self.select, on_commit=self._commit)
        self.tabla.frame.grid(row=1, column=0, sticky="nsew")
        self.rows = self.tabla.rows

    @staticmethod
    def _cols(f):
        f.grid_columnconfigure(0, weight=1, minsize=210)
        f.grid_columnconfigure(1, weight=0, minsize=60)
        for i in range(4):
            f.grid_columnconfigure(2 + i, weight=0, minsize=96)

    def _build_acciones(self):
        bar = ctk.CTkFrame(self.main.body, fg_color="transparent", width=0, height=0)
        bar.grid(row=2, column=0, sticky="ew", pady=(10, 0))
        for i in range(5):
            bar.grid_columnconfigure(i, weight=1, uniform="ac")
        spec = (("✎  Dibujar zona", self._dibujar), ("🔗  En cadena", self._cadena), ("🎚  Ajustar zona", self._ajustar),
                ("👁  Ver zonas", self._ver), ("↺  Por defecto", self._defecto))
        self.btns = []
        for i, (tx, cmd) in enumerate(spec):
            b = btn(bar, tx, cmd, height=34)
            b.grid(row=0, column=i, sticky="ew", padx=(0 if i == 0 else 6, 0))
            self.btns.append(b)
        self.b_chain = self.btns[1]

    def _build_herramientas(self):
        box = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        box.grid(row=1, column=0, sticky="ew", pady=(8, 0))
        box.grid_columnconfigure(0, weight=3)
        box.grid_columnconfigure(1, weight=1, minsize=250)
        g = Card(box, "Herramientas globales", "", "Desplaza todos los puntos de las zonas por la misma cantidad.")
        g.grid(row=0, column=0, sticky="nsew")
        r = ctk.CTkFrame(g.body, fg_color="transparent", width=0, height=0)
        r.grid(row=0, column=0, sticky="ew")
        g.body.grid_columnconfigure(0, weight=1)
        r.grid_columnconfigure(4, weight=1)
        lbl(r, "ΔX:", 12, T.TXT, True).grid(row=0, column=0, padx=(0, 6))
        self.sx = Stepper(r, -2000, 2000, 1, 120, on_commit=lambda t: self._delta("x", t))
        self.sx.set(0)
        self.sx.grid(row=0, column=1, padx=(0, 14))
        lbl(r, "ΔY:", 12, T.TXT, True).grid(row=0, column=2, padx=(0, 6))
        self.sy = Stepper(r, -2000, 2000, 1, 120, on_commit=lambda t: self._delta("y", t))
        self.sy.set(0)
        self.sy.grid(row=0, column=3)
        btn(r, "✔  Aplicar Δ", self._aplicar_delta, height=34).grid(row=0, column=4, sticky="ew", padx=(14, 0))
        p = Card(box, "Panel de CSP", "", "Mostrar/ocultar el panel de configuración de CSP.")
        p.grid(row=0, column=1, sticky="nsew", padx=(8, 0))
        p.body.grid_columnconfigure(0, weight=1)
        self.v_panel = tk.IntVar(value=1)
        switch(p.body, self.v_panel, self._panel).grid(row=0, column=0, sticky="e")

    # ── datos ──────────────────────────────────────────────
    def _d(self):
        return self.tc.draft

    def refresh(self):
        todas = Z.obtener_todas_zonas(self._d(), self.modo, getattr(self.tc, "catalogo", None))
        self.tabla.set_zonas(todas)
        self.rows = self.tabla.rows
        et = self._etiquetas()
        if et != getattr(self, "_et", None):          # solo si cambió «(activo en CSP)»: evita parpadeo
            self._et = et
            self.seg.configure(values=et)
        self.seg.set(et[self.modo - 1])
        for zid, row in self.rows.items():
            z = row["zona"]
            r = Z.leer(self._d(), self.modo, z)
            vals = dict(zip(("x", "y", "w", "h"), Z.a_ui(r)))
            col = T.TXT if Z.configurada(r) else T.TXT3
            for c, e in row["ents"].items():
                if self._tiene_foco(e):
                    continue
                e.delete(0, "end")
                e.insert(0, Z.leer_desc(self._d(), z) if c == "desc" else str(vals[c]))
                e.configure(text_color=T.TXT2 if c == "desc" else col, border_color=T.BORDER)
        self.v_panel.set(1 if self._d().get_key(Z.seccion(self.modo, self._d().perfil), Z.PANEL_CSP_KEY, "1").strip() != "0" else 0)
        self._paint()
        self.tc.on_dirty()

    def _tiene_foco(self, e) -> bool:
        try:
            return self.focus_get() is e._entry
        except Exception:
            return False

    def on_external_change(self):
        """AHK escribió el INI (p. ej. tras Dibujar zona): lo dibujado manda sobre cambios pendientes de esa zona."""
        if self._expect is not None:
            Z.descartar(self._d(), self.modo, self._expect)
            self._expect = None
        self.refresh()

    def info_text(self) -> str:
        n = Z.contar(self._d(), self.modo)
        return f"{n} zona{'s' if n != 1 else ''} configurada{'s' if n != 1 else ''}"

    # ── selección ──────────────────────────────────────────
    def select(self, zid: str):
        self.sel = zid
        self._paint()

    def _paint(self):
        for zid, row in self.rows.items():
            on = zid == self.sel
            row["frame"].configure(fg_color=SEL_BG if on else "transparent")
            for w in row["labels"]:
                w.configure(text_color=T.PRIMARY if on else (T.TXT if w is row["labels"][0] else T.TXT2))

    def _zona_sel(self) -> Z.Zona | None:
        if not self.sel:
            self.tc.flash("Selecciona una zona de la tabla", False)
            return None
        return self.rows[self.sel]["zona"]

    def _on_seg(self, label: str):
        self.modo = 1 if label.startswith("NORMAL") else 2
        self._stop_chain("Cadena detenida: cambió el modo")
        self.refresh()

    # ── edición de celdas ──────────────────────────────────
    def _commit(self, z: Z.Zona, col: str):
        e = self.rows[z.id]["ents"][col]
        txt = e.get().strip()
        if col == "desc":
            txt = " ".join(txt.split())
            Z.escribir_desc(self._d(), z, txt)
            self.tabla._set(z.id, "desc", txt)
            self.tc.on_dirty()
            return
        cur = dict(zip(("x", "y", "w", "h"), Z.a_ui(Z.leer(self._d(), self.modo, z))))[col]
        if txt == str(cur):
            e.configure(border_color=T.BORDER)
            return
        v = Z.validar_celda(col, txt)
        if v is None:
            e.configure(border_color=T.DANGER)
            return
        Z.editar_celda(self._d(), self.modo, z, col, v)
        self.refresh()

    # ── acciones ───────────────────────────────────────────
    def _dibujar(self):
        z = self._zona_sel()
        if z:
            self._expect = z
            self.tc.send("CAL_ZONE", z.prefijo, "dibujar", self.modo, "zona", z.nombre, ok_msg=f"Dibuja «{z.nombre}» en pantalla…")

    def _cadena(self):
        if self._chain:
            self._stop_chain("Cadena detenida")
            return
        if not self.tc.bridge.conectado:
            self.tc.flash("AHK no conectado: la cadena necesita el script", False)
            return
        orden = list(Z.ZONAS)
        i = next((k for k, z in enumerate(orden) if z.id == self.sel), 0)
        self._chain = {"cola": orden[i:], "sig": None, "t0": 0.0}
        self.b_chain.configure(text="■  Detener cadena")
        self._chain_next()

    def _firma(self):
        try:
            st = self.tc.store.path.stat()
            return st.st_mtime_ns, st.st_size
        except OSError:
            return None

    def _chain_next(self):
        ch = self._chain
        if not ch:
            return
        if not ch["cola"]:
            self._stop_chain("✓ Cadena completa", ok=True)
            return
        z = ch["cola"][0]
        self.select(z.id)
        self._expect = z
        ch["sig"], ch["t0"] = self._firma(), time.time()
        self.after(250, lambda z=z: self._chain_send(z))
        self.after(650, self._chain_poll)

    def _chain_send(self, z):
        if self._chain:
            self.tc.send("CAL_ZONE", z.prefijo, "panel", self.modo, "zona", z.nombre, ok_msg=f"Cadena: calibra «{z.nombre}»")

    def _chain_poll(self):
        ch = self._chain
        if not ch:
            return
        if self._firma() != ch["sig"]:            # AHK guardó la zona → siguiente
            ch["cola"].pop(0)
            self.tc.reload_all()
            self._chain_next()
        elif time.time() - ch["t0"] > CHAIN_TIMEOUT_S:
            self._stop_chain("Cadena detenida: sin respuesta de AHK", ok=False)
        else:
            self.after(400, self._chain_poll)

    def _stop_chain(self, msg: str, ok: bool = True):
        if self._chain is None:
            return
        self._chain = None
        self._expect = None
        self.b_chain.configure(text="🔗  En cadena")
        self.tc.flash(msg, ok)

    def _ver(self):
        self.tc.send("SHOW_ZONES", self.modo, ok_msg="Zonas visibles en pantalla")

    def _defecto(self):
        z = self._zona_sel() if self.sel else None
        alcance = f"«{z.nombre}»" if z else "TODAS las zonas de este modo"
        if not messagebox.askyesno("Por defecto", f"¿Volver a «sin configurar» {alcance}?\n(Se aplica al guardar.)", parent=self.winfo_toplevel()):
            return
        Z.por_defecto(self._d(), self.modo, (z,) if z else Z.ZONAS)
        self.refresh()

    def _delta(self, eje: str, txt: str) -> bool:
        try:
            v = int(str(txt).strip())
        except ValueError:
            return False
        if not -2000 <= v <= 2000:
            return False
        setattr(self, "_dx" if eje == "x" else "_dy", v)
        return True

    def _aplicar_delta(self):
        self.sx._commit()
        self.sy._commit()
        if not (self._dx or self._dy):
            self.tc.flash("Δ = 0: nada que desplazar", False)
            return
        n = Z.desplazar_todas(self._d(), self.modo, self._dx, self._dy)
        self._dx = self._dy = 0
        self.sx.set(0)
        self.sy.set(0)
        self.refresh()
        self.tc.flash(f"Δ aplicado a {n} zona{'s' if n != 1 else ''} (pendiente de guardar)" if n else "No hay zonas configuradas", bool(n))

    def _panel(self):
        self._d().set_key(Z.seccion(self.modo, self._d().perfil), Z.PANEL_CSP_KEY, self.v_panel.get(), default="1")
        self.tc.on_dirty()

    def _ajustar(self):
        z = self._zona_sel()
        if not z:
            return
        if not Z.configurada(Z.leer(self._d(), self.modo, z)):
            self.tc.flash("La zona está sin configurar: dibújala primero", False)
            return
        self._expect = z
        self.tc.send("CAL_ZONE", z.prefijo, "ajustar", self.modo, "zona", z.nombre, ok_msg=f"Ajusta «{z.nombre}» en pantalla…")

    def nudge(self, z: Z.Zona, dx=0, dy=0, dw=0, dh=0):
        x, y, w, h = Z.a_ui(Z.leer(self._d(), self.modo, z))
        w, h = max(0, w + dw), max(0, h + dh)
        x = max(Z.COORD_LO, min(Z.COORD_HI, x + dx))
        y = max(Z.COORD_LO, min(Z.COORD_HI, y + dy))
        Z.escribir(self._d(), self.modo, z, x, y, x + w, y + h)
        self.refresh()


class Ajuste(ctk.CTkToplevel):
    """Ajuste fino de una zona: mover y redimensionar con paso 1/5/10/50 px."""
    def __init__(self, tab: ZonasTab, z: Z.Zona):
        super().__init__(tab.winfo_toplevel(), fg_color=T.BG)
        self.title(f"Ajustar · {z.nombre}")
        self.resizable(False, False)
        self.transient(tab.winfo_toplevel())
        self.tab, self.z, self.paso = tab, z, 5
        seg = ctk.CTkSegmentedButton(self, values=["1", "5", "10", "50"], command=lambda v: setattr(self, "paso", int(v)),
                                     selected_color=T.PRIMARY, selected_hover_color=T.PRIMARY_HOVER, font=T.font(12, True))
        seg.set("5")
        lbl(self, "Paso (px)", 11, T.TXT2).grid(row=0, column=0, padx=14, pady=(12, 0), sticky="w")
        seg.grid(row=1, column=0, columnspan=2, padx=14, pady=(2, 8), sticky="ew")
        pad = ctk.CTkFrame(self, fg_color="transparent")
        pad.grid(row=2, column=0, padx=14, pady=4)
        for t, c, r, a in (("↑", 1, 0, (0, -1, 0, 0)), ("←", 0, 1, (-1, 0, 0, 0)), ("→", 2, 1, (1, 0, 0, 0)), ("↓", 1, 2, (0, 1, 0, 0))):
            btn(pad, t, lambda a=a: self._go(a), width=40).grid(row=r, column=c, padx=2, pady=2)
        sz = ctk.CTkFrame(self, fg_color="transparent")
        sz.grid(row=2, column=1, padx=(0, 14), pady=4)
        for i, (t, a) in enumerate((("Ancho −", (0, 0, -1, 0)), ("Ancho +", (0, 0, 1, 0)), ("Alto −", (0, 0, 0, -1)), ("Alto +", (0, 0, 0, 1)))):
            btn(sz, t, lambda a=a: self._go(a), width=84).grid(row=i // 2, column=i % 2, padx=2, pady=2)
        btn(self, "Cerrar", self.destroy, primary=True, width=100).grid(row=3, column=0, columnspan=2, pady=(6, 12))
        self.after(50, self.lift)

    def _go(self, a):
        self.tab.nudge(self.z, *(v * self.paso for v in a))
