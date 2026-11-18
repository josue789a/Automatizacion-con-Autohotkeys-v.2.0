"""Paneles de la pestaña 1: catálogo (izquierda), editor (derecha) y footer."""
from __future__ import annotations
import os
import time
import customtkinter as ctk
from . import theme as T
from .widgets import lbl, btn, combo, entry, ellipsize
from .blocks import GROUP_A, GROUP_B, Ctx

MAX_OPEN = 5            # tarjetas expandidas a la vez (A01+A02+A03 + B01+B02 por defecto; hay scroll)


class CatalogoPanel(ctk.CTkFrame):
    def __init__(self, master, catalogo, on_select, on_add):
        super().__init__(master, fg_color=T.CARD, corner_radius=10, border_width=1, border_color=T.BORDER, width=T.LEFT_W)
        self.catalogo, self.on_select, self.on_add = catalogo, on_select, on_add
        self.grid_propagate(False)
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)
        self.selected: str | None = None
        self._rows: dict[str, tuple] = {}
        self._heads: dict[str, ctk.CTkLabel] = {}
        self._job = None

        top = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        top.grid(row=0, column=0, sticky="ew", padx=2, pady=(2, 1))
        top.grid_columnconfigure(0, weight=1)
        lbl(top, "Eventos", 14, T.TXT, True).grid(row=0, column=0, sticky="w")
        self.grp = combo(top, ["Todos los grupos"], command=lambda _v: self._filter(), width=150)
        self.grp.set("Todos los grupos")
        self.grp.grid(row=0, column=1)

        bar = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        bar.grid(row=1, column=0, sticky="ew", padx=8, pady=(0, 4))
        bar.grid_columnconfigure(0, weight=1)
        self.q = entry(bar, 10, "🔍  Buscar evento…")
        self.q.grid(row=0, column=0, sticky="ew")
        self.q.bind("<KeyRelease>", self._sched)
        ctk.CTkButton(bar, text="+", width=30, height=30, corner_radius=8, fg_color=T.CARD, hover_color=T.SOFT,
                      text_color=T.TXT, border_width=1, border_color=T.FIELD_BORDER, font=T.font(15, True),
                      command=self.on_add).grid(row=0, column=1, padx=(8, 0))

        import tkinter as tk
        self._ROW_H, self._HEAD_H = 26, 16
        self._W = 0
        self._vis: list = []
        self._items: dict[str, tuple] = {}
        self._f, self._fb, self._fh = T.font(12), T.font(12, True), T.font(11, True)
        self._bg = self._c(T.CARD)

        self.lst = ctk.CTkFrame(self, fg_color="transparent", corner_radius=0, width=0, height=0)
        self.lst.grid(row=2, column=0, sticky="nsew", padx=(6, 2), pady=(0, 4))
        self.lst.grid_columnconfigure(0, weight=1)
        self.lst.grid_rowconfigure(0, weight=1)
        self.cv = tk.Canvas(self.lst, bg=self._bg, highlightthickness=0, bd=0,
                            yscrollincrement=12, takefocus=0)
        self.cv.grid(row=0, column=0, sticky="nsew")
        self.sb = ctk.CTkScrollbar(self.lst, orientation="vertical", command=self.cv.yview, width=12,
                                   fg_color="transparent", button_color="#D9D4E6",
                                   button_hover_color=T.ACCENT)
        self.sb.grid(row=0, column=1, sticky="ns", padx=(2, 0))
        self.cv.configure(yscrollcommand=self.sb.set)
        self.cv.bind("<Configure>", self._on_resize)
        self.cv.bind_all("<MouseWheel>", self._wheel, add="+")

        self.count = lbl(self, "", 10, T.TXT2)
        self.count.grid(row=3, column=0, sticky="w", padx=14, pady=(0, 10))
        self.rebuild()

    @staticmethod
    def _c(col):
        if isinstance(col, (tuple, list)):
            return col[1] if ctk.get_appearance_mode() == "Dark" else col[0]
        return col

    def _rrect(self, x1, y1, x2, y2, r, **kw):
        p = [x1 + r, y1, x2 - r, y1, x2, y1, x2, y1 + r, x2, y2 - r, x2, y2,
             x2 - r, y2, x1 + r, y2, x1, y2, x1, y2 - r, x1, y1 + r, x1, y1]
        return self.cv.create_polygon(p, smooth=True, **kw)

    def _wheel(self, e):
        try:
            if self.winfo_containing(e.x_root, e.y_root) is not self.cv:
                return
            n = -int(e.delta / 120) or (-1 if e.delta > 0 else 1)
            self.cv.yview_scroll(n * 3, "units")   # 3 x 12 px = 36 px por golpe
        except Exception:
            pass

    def _on_resize(self, e):
        if abs(e.width - self._W) > 1:
            self._render_canvas(keep=True)

    def rebuild(self):
        self._rows.clear()
        actual = self.grp.get()
        self.grp.configure(values=["Todos los grupos", *self.catalogo.grupos()])
        if actual not in self.grp.cget("values"):
            self.grp.set("Todos los grupos")
        for ev in self.catalogo.eventos:
            self._rows[ev.id] = (None, None, ev)   # forma (row, tx, ev) conservada
        self._filter()

    def _sched(self, _e=None):
        if self._job:
            self.after_cancel(self._job)
        self._job = self.after(150, self._filter)

    def _filter(self):
        self._job = None
        q = self.q.get().strip().lower()
        g = self.grp.get()
        self._vis = []
        n = 0
        for grupo in self.catalogo.grupos():
            vis = [i for i, (_, _, ev) in self._rows.items()
                   if ev.grupo == grupo and (g in ("", "Todos los grupos", grupo))
                   and (not q or q in ev.nombre.lower())]
            if not vis:
                continue
            self._vis.append(("h", grupo))
            self._vis.extend(("r", i) for i in vis)
            n += len(vis)
        self.count.configure(text=f"{n} evento{'s' if n != 1 else ''}")
        self._render_canvas(keep=False)

    def _render_canvas(self, keep=True):
        cv = self.cv
        w = max(cv.winfo_width(), 80)
        self._W = w
        y0 = cv.yview()[0] if keep else 0.0
        cv.delete("all")
        self._items.clear()
        soft, accent = self._c(T.SOFT), self._c(T.ACCENT)
        pri = self._c(T.PRIMARY)
        y = 2
        for kind, key in self._vis:
            if kind == "h":
                y += 14 if y > 2 else 2
                cv.create_text(10, y + self._HEAD_H / 2, text=key.upper(), font=self._fh,
                               fill=pri, anchor="w", state="disabled")
                y += self._HEAD_H + 2
                continue
            ev = self._rows[key][2]
            on = key == self.selected
            rect = self._rrect(4, y, w - 6, y + self._ROW_H - 2, 8,
                               fill=soft if on else self._bg, outline="")
            txt = cv.create_text(22, y + self._ROW_H / 2 - 1,
                                 text=ellipsize(ev.nombre, self._f, max(60, w - 58)),
                                 font=self._fb if on else self._f,
                                 fill=self._c(T.PRIMARY if on else T.TXT),
                                 anchor="w", state="disabled")
            self._items[key] = (rect, txt)
            cv.tag_bind(rect, "<Button-1>", lambda _e, i=key: self.select(i))
            cv.tag_bind(rect, "<Enter>", lambda _e, i=key: self._hov(i, True))
            cv.tag_bind(rect, "<Leave>", lambda _e, i=key: self._hov(i, False))
            y += self._ROW_H
        cv.configure(scrollregion=(0, 0, w, y + 4))
        cv.yview_moveto(y0)

    def _hov(self, i, enter):
        it = self._items.get(i)
        if not it:
            return
        self.cv.configure(cursor="hand2" if enter else "")
        if i != self.selected:
            self.cv.itemconfigure(it[0], fill=self._c(T.SOFT) if enter else self._bg)

    def select(self, id_ev: str, notify=True):
        self.selected = id_ev
        self._paint()
        if notify:
            self.on_select(id_ev)

    def _paint(self):
        for i, (rect, txt) in self._items.items():
            on = i == self.selected
            self.cv.itemconfigure(rect, fill=self._c(T.SOFT) if on else self._bg)
            self.cv.itemconfigure(txt, fill=self._c(T.PRIMARY if on else T.TXT),
                                  font=self._fb if on else self._f)


GROUP_META = {
    "A": ("Configuración básica", "Identidad, apariencia y comportamiento general del evento."),
    "B": ("Particularidades", "Funciones especiales que modifican el comportamiento del evento."),
}


class EditorPanel(ctk.CTkFrame):
    def __init__(self, master, ctx: Ctx):
        super().__init__(master, fg_color="transparent")
        self.ctx = ctx
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        hd = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        hd.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        top = ctk.CTkFrame(hd, fg_color="transparent", width=0, height=0)
        top.grid(row=0, column=0, sticky="w")
        ctk.CTkFrame(top, width=3, height=14, fg_color=T.ACCENT, corner_radius=2).pack(side="left", padx=(0, 8))
        lbl(top, "Editor de evento", 11, T.TXT2).pack(side="left")
        self.title = lbl(hd, "Seleccione un evento", 19, T.TXT, True)
        self.title.grid(row=1, column=0, sticky="w", pady=(2, 0))
        lbl(hd, "Configuración del evento seleccionado", 11, T.TXT2).grid(row=2, column=0, sticky="w")

        self.scroll = ctk.CTkScrollableFrame(self, fg_color="transparent", corner_radius=0,
                                             scrollbar_button_color="#D9D4E6", scrollbar_button_hover_color=T.ACCENT)
        self.scroll.grid(row=1, column=0, sticky="nsew")
        self.scroll.grid_columnconfigure(0, weight=1)
        self.opened: list = []
        r = 0
        self.groups: dict[str, list] = {}
        for key, title, group, collapsed in (("A", "A · CONFIGURACIÓN BÁSICA", GROUP_A, False), ("B", "B · PARTICULARIDADES", GROUP_B, False)):
            head = ctk.CTkFrame(self.scroll, fg_color="transparent", cursor="hand2")
            head.grid(row=r, column=0, sticky="ew", padx=4, pady=(T.GAP if r else 0, 3))
            head.grid_columnconfigure(1, weight=1)
            badge = ctk.CTkFrame(head, fg_color=T.PRIMARY, corner_radius=T.GROUP_BADGE // 2,
                                 width=T.GROUP_BADGE, height=T.GROUP_BADGE)
            badge.grid(row=0, column=0, rowspan=2, padx=(0, 10))
            badge.grid_propagate(False)
            b_lbl = lbl(badge, key, 12, "#FFFFFF", True)
            b_lbl.place(relx=0.5, rely=0.5, anchor="center")
            l1 = lbl(head, GROUP_META[key][0], 13, T.TXT, True)
            l1.grid(row=0, column=1, sticky="w")
            l_sub = lbl(head, GROUP_META[key][1], 10, T.TXT2)
            l_sub.grid(row=1, column=1, sticky="w")
            chev = lbl(head, "⌄" if collapsed else "⌃", 14, T.TXT2, anchor="e")
            chev.grid(row=0, column=2, rowspan=2, padx=(0, 10))
            r += 1
            self.groups[key] = []
            for cls in group:
                b = cls(self.scroll, ctx, self._on_toggle)
                b.grid(row=r, column=0, sticky="ew", pady=(0, T.GAP), padx=(0, 6))
                self.groups[key].append(b)
                if collapsed:
                    b.grid_remove()
                r += 1
            for w in (head, badge, b_lbl, l1, l_sub, chev):
                w.bind("<Button-1>", lambda _e, k=key, c=chev: self._toggle_group(k, c))
                w.configure(cursor="hand2")
            self.groups[key + "_collapsed"] = collapsed
        self.blocks = ctx.blocks
        for b in self.blocks:
            if b.__class__.__name__ in ("A01Base", "A02Hud", "A03Sonido",
                                        "B01Presencia", "B02Disparador"):
                b.set_expanded(True)
                self.opened.append(b)
        self._warm_job = None
        self._schedule_prewarm(600)

    def _toggle_group(self, key, chev):
        _t0 = time.perf_counter()
        col = not self.groups[key + "_collapsed"]
        self.groups[key + "_collapsed"] = col
        for b in self.groups[key]:
            (b.grid_remove if col else b.grid)()
        _t1 = time.perf_counter()
        chev.configure(text="⌄" if col else "⌃")
        self._queue_sync()
        if os.environ.get("XPPEN_PROF"):
            import tkinter as tk_raw
            _t2 = time.perf_counter()
            _cnt = {}
            def _count(e, _c=_cnt):
                k = e.widget.winfo_class()
                _c[k] = _c.get(k, 0) + 1
            _bid = tk_raw.Misc.bind_all(self, "<Configure>", _count, add="+")
            self.update_idletasks()
            _t3 = time.perf_counter()
            tk_raw.Misc.unbind_all(self, "<Configure>")
            self._sync_scroll()
            _t4 = time.perf_counter()
            print(f"[PROF] toggle_group {key} col={col}: grid={(_t1-_t0)*1000:.1f}ms "
                  f"chev+queue={(_t2-_t1)*1000:.1f}ms "
                  f"idletasks={(_t3-_t2)*1000:.1f}ms sync={(_t4-_t3)*1000:.1f}ms")
            print(f"[PROF]   configure events: {dict(sorted(_cnt.items(), key=lambda kv: -kv[1])[:6])}")

    def _on_toggle(self, block):
        if block.expanded:
            self.opened.append(block)
            while len(self.opened) > MAX_OPEN:
                old = self.opened.pop(0)
                if old is not block:
                    old.set_expanded(False)
        elif block in self.opened:
            self.opened.remove(block)
        self._queue_sync()
        self._schedule_prewarm()

    def _schedule_prewarm(self, delay=150):
        if getattr(self, "_warm_job", None) is None:
            self._warm_job = self.after(delay, self._prewarm)

    def _prewarm(self):
        self._warm_job = None
        try:
            for b in self.blocks:
                if b.available and not b._built:
                    b.prewarm()
                    self._warm_job = self.after(30, self._prewarm)
                    return
        except Exception:
            pass

    def _queue_sync(self):
        if getattr(self, "_sync_job", None) is None:
            self._sync_job = self.after_idle(self._sync_scroll)
        late = getattr(self, "_sync_late", None)
        if late is not None:
            try:
                self.after_cancel(late)
            except Exception:
                pass
        self._sync_late = self.after(40, self._sync_scroll_late)

    def _sync_scroll_late(self):
        self._sync_late = None
        self._sync_scroll()

    def _sync_scroll(self):
        self._sync_job = None
        try:
            if not self.winfo_exists():
                return
            cv = self.scroll._parent_canvas
            bb = cv.bbox("all")
            if bb != getattr(self, "_last_bb", None):
                self._last_bb = bb
                if bb:
                    cv.configure(scrollregion=bb)
            top = cv.yview()[0]
            if top > 0:
                cv.yview_moveto(top)   # clamp al nuevo alto
        except Exception:
            pass

    def show_event(self, ev):
        self.ctx.event_id = ev.id
        if getattr(self, "_title_txt", None) != ev.nombre:
            self._title_txt = ev.nombre
            self.title.configure(text=ev.nombre)
        sig = tuple(True if not b.CAP else bool(ev.tiene(b.CAP)) for b in self.blocks)
        if sig != getattr(self, "_avail_sig", None):
            self._avail_sig = sig
            for b, disp in zip(self.blocks, sig):
                b.set_available(disp)
                if not disp and b in self.opened:
                    self.opened.remove(b)
        _p0 = time.perf_counter()
        self.ctx.refresh_all()
        _p1 = time.perf_counter()
        try:
            self.scroll._parent_canvas.yview_moveto(0)
        except Exception:
            pass
        _p2 = time.perf_counter()
        self._queue_sync()
        self._schedule_prewarm(100)
        _p3 = time.perf_counter()
        if os.environ.get("XPPEN_PROF"):
            print(f"[PROF] show_event {ev.id}: refresh_all={(_p1-_p0)*1000:.1f}ms "
                  f"yview={(_p2-_p1)*1000:.1f}ms queue+prewarm={(_p3-_p2)*1000:.1f}ms")


class Footer(ctk.CTkFrame):
    def __init__(self, master, on_save, on_save_close, on_restart, on_modo, modo_inicial="Normal"):
        super().__init__(master, fg_color=T.CARD, corner_radius=0, height=T.FOOTER_H, border_width=0)
        self.grid_columnconfigure(1, weight=1)
        self.grid_propagate(False)
        ctk.CTkFrame(self, height=1, fg_color=T.BORDER).place(x=0, y=0, relwidth=1)
        self.info = lbl(self, "ⓘ  Ningún evento seleccionado", 11, T.TXT2)
        self.info.grid(row=0, column=0, sticky="w", padx=(18, 0), pady=T.GAP)
        self.status = lbl(self, "", 11, T.OK)
        self.status.grid(row=0, column=1, sticky="w", padx=14)
        bar = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        bar.grid(row=0, column=2, sticky="e", padx=(0, 16))
        btn(bar, "💾  Guardar cambios", on_save, width=150, height=34).grid(row=0, column=0, padx=4)
        btn(bar, "💾  Guardar y cerrar", on_save_close, primary=True, width=160, height=34).grid(row=0, column=1, padx=4)
        btn(bar, "⟳  Reiniciar script", on_restart, width=150, height=34).grid(row=0, column=2, padx=4)
        self.modo = combo(bar, ["Modo: Normal", "Modo: Enfoque"], command=lambda v: on_modo(v.split(": ")[1]), width=130)
        self.modo.configure(height=34)
        self.modo.set(f"Modo: {modo_inicial}")
        self.modo.grid(row=0, column=3, padx=4)
        self._job = None

    def set_info(self, nombre: str | None, dirty: int, icon: str = "ⓘ"):
        base = f"{icon}  {nombre}" if nombre else "ⓘ  Ningún evento seleccionado"
        self.info.configure(text=base + (f"  ·  {dirty} cambio{'s' if dirty != 1 else ''} sin guardar" if dirty else ""))

    def flash(self, text: str, ok=True):
        self.status.configure(text=text, text_color=T.OK if ok else T.DANGER)
        if self._job:
            self.after_cancel(self._job)
        self._job = self.after(3500, lambda: self.status.configure(text=""))
