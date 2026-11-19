"""Paneles de la pestaña 1: catálogo (izquierda), editor (derecha) y footer."""
from __future__ import annotations
import os
import time
import tkinter as tk
import customtkinter as ctk
from . import theme as T
from .widgets import lbl, btn, combo, entry, ellipsize
from .blocks import GROUP_A, GROUP_B, Ctx

MAX_OPEN = 5            # tarjetas expandidas a la vez (A01+A02+A03 + B01+B02 por defecto; hay scroll)


import ctypes
import sys
from ctypes import wintypes

_WM_POINTERDOWN = 0x0246
_GWLP_WNDPROC = -4
_U32 = None
_WNDPROC = (ctypes.WINFUNCTYPE(ctypes.c_ssize_t, wintypes.HWND, wintypes.UINT,
                               wintypes.WPARAM, wintypes.LPARAM)
            if sys.platform == "win32" else None)


def _user32():
    global _U32
    if _U32 is None:
        u = ctypes.WinDLL("user32")
        u.GetParent.argtypes = [wintypes.HWND]
        u.GetParent.restype = wintypes.HWND
        u.SetWindowLongPtrW.argtypes = [wintypes.HWND, ctypes.c_int, ctypes.c_void_p]
        u.SetWindowLongPtrW.restype = ctypes.c_void_p
        u.CallWindowProcW.argtypes = [ctypes.c_void_p, wintypes.HWND, wintypes.UINT,
                                      wintypes.WPARAM, wintypes.LPARAM]
        u.CallWindowProcW.restype = ctypes.c_ssize_t
        _U32 = u
    return _U32


class StylusContextMenu(tk.Toplevel):
    _active: StylusContextMenu | None = None

    def __init__(self, parent, x: int, y: int, is_sub: bool = False):
        super().__init__(parent)
        self.parent = parent
        self.is_sub = is_sub
        self.sub: StylusContextMenu | None = None
        self.parent_menu: StylusContextMenu | None = None
        self._ptr_rows: list = []          # (widget, fn, cierra_menu)
        self._ptr_hwnd = 0
        self._ptr_prev = None
        self._ptr_cb = None
        self._ptr_busy = False
        self.withdraw()
        try:
            self.attributes("-alpha", 0.0)  # evita el flash antes de posicionar
        except Exception:
            pass
        self.overrideredirect(True)
        self.attributes("-topmost", True)
        try:
            self.transient(parent.winfo_toplevel())
        except Exception:
            pass

        if not is_sub:
            if StylusContextMenu._active:
                try:
                    StylusContextMenu._active.close()
                except Exception:
                    pass
            StylusContextMenu._active = self

        self.configure(bg=T.BORDER)
        self.body = tk.Frame(self, bg=T.CARD, padx=2, pady=2)
        self.body.pack(fill="both", expand=True, padx=1, pady=1)

        if not is_sub:
            root = parent.winfo_toplevel()
            self._click_id = root.bind("<Button-1>", self._on_any_click, add="+")
            self._rclick_id = root.bind("<Button-3>", self._on_any_click, add="+")
            self._esc_id = root.bind("<Escape>", lambda e: self.close_all(), add="+")

    def add_command(self, label: str, command=None, state: str = "normal"):
        text_col = T.TXT if state == "normal" else T.TXT3
        is_disabled = (state == "disabled")
        lbl = tk.Label(
            self.body, text=f"  {label}", anchor="w", font=T.font(10),
            bg=T.CARD, fg=text_col, pady=5, cursor="hand2" if not is_disabled else ""
        )
        lbl.pack(fill="x")
        if not is_disabled:
            def _on_enter(_e):
                if self.sub:
                    try:
                        self.sub.close()
                    except Exception:
                        pass
                    self.sub = None
                lbl.configure(bg=T.SOFT)
            def _on_leave(_e):
                lbl.configure(bg=T.CARD)
            lbl.bind("<Enter>", _on_enter)
            lbl.bind("<Leave>", _on_leave)
            lbl.bind("<Button-1>", lambda _e: self._exec(command))
            self._ptr_rows.append((lbl, command, True))

    def add_separator(self):
        sep = tk.Frame(self.body, height=1, bg=T.BORDER)
        sep.pack(fill="x", padx=4, pady=3)

    def add_cascade(self, label: str, populate_fn):
        lbl = tk.Label(
            self.body, text=f"  {label}   ▸", anchor="w", font=T.font(10),
            bg=T.CARD, fg=T.TXT, pady=5, cursor="hand2"
        )
        lbl.pack(fill="x")

        def _open():
            if self.sub and self.sub.winfo_exists():
                return
            bx = self.winfo_rootx() + self.winfo_width() + 2
            by = lbl.winfo_rooty()
            sub = StylusContextMenu(self.parent, bx, by, is_sub=True)
            sub.parent_menu = self
            self.sub = sub
            populate_fn(sub)
            sub.show(bx, by)

        def _on_enter(_e):
            lbl.configure(bg=T.SOFT)
            self.after(100, _open)

        def _on_leave(_e):
            lbl.configure(bg=T.CARD)

        lbl.bind("<Enter>", _on_enter)
        lbl.bind("<Leave>", _on_leave)
        lbl.bind("<Button-1>", lambda _e: _open())
        self._ptr_rows.append((lbl, _open, False))

    def _exec(self, cmd):
        self.close_all()
        if cmd:
            try:
                cmd()
            except Exception as e:
                import logging
                logging.exception("Error executing context menu command: %s", e)

    def show(self, x: int, y: int):
        self.update_idletasks()
        w = max(210, self.body.winfo_reqwidth() + 8)
        h = self.body.winfo_reqheight() + 2
        sw = self.winfo_screenwidth()
        sh = self.winfo_screenheight()
        if x + w > sw - 10:
            x = max(10, x - w if not self.is_sub else (self.parent_menu.winfo_rootx() - w if self.parent_menu else x - w))
        if y + h > sh - 10:
            y = max(10, sh - h - 10)
        self.geometry(f"{w}x{h}+{int(x)}+{int(y)}")
        self.deiconify()
        self.lift()
        self.update_idletasks()
        try:
            self.attributes("-alpha", 1.0)
        except Exception:
            pass
        self._hook_pointer()

    def _pointer_hit(self, x: int, y: int) -> bool:
        """Hit-test en coords de pantalla. Agenda el comando (nunca ejecuta dentro del wndproc)."""
        if self._ptr_busy:
            return True
        for b, fn, closes in self._ptr_rows:
            try:
                bx, by = b.winfo_rootx(), b.winfo_rooty()
                if bx <= x < bx + b.winfo_width() and by <= y < by + b.winfo_height():
                    self._ptr_busy = True

                    def _run(fn=fn, closes=closes):
                        self._ptr_busy = False
                        if closes:
                            self._exec(fn)
                        elif fn:
                            fn()
                    self.parent.after(30, _run)   # equivalente a SetTimer(fn, -30) de AHK
                    return True
            except Exception:
                continue
        return False

    def _hook_pointer(self):
        if sys.platform != "win32" or self._ptr_hwnd:
            return
        try:
            u = _user32()
            inner = self.winfo_id()
            hwnd = u.GetParent(inner) or inner

            def _proc(h, msg, wp, lp):
                if msg == _WM_POINTERDOWN:
                    try:
                        x = ctypes.c_short(lp & 0xFFFF).value
                        y = ctypes.c_short((lp >> 16) & 0xFFFF).value
                        if self._pointer_hit(x, y):
                            return 0
                    except Exception:
                        pass
                return u.CallWindowProcW(self._ptr_prev, h, msg, wp, lp)

            self._ptr_cb = _WNDPROC(_proc)
            prev = u.SetWindowLongPtrW(hwnd, _GWLP_WNDPROC,
                                       ctypes.cast(self._ptr_cb, ctypes.c_void_p))
            if prev:
                self._ptr_prev, self._ptr_hwnd = prev, hwnd
            else:
                self._ptr_cb = None
        except Exception:
            self._ptr_cb = None   # sin ruta de puntero: queda el camino Tk normal

    def _unhook_pointer(self):
        if not self._ptr_hwnd:
            return
        try:
            _user32().SetWindowLongPtrW(self._ptr_hwnd, _GWLP_WNDPROC, self._ptr_prev)
        except Exception:
            pass
        self._ptr_hwnd = 0
        self._ptr_cb = None

    def _on_any_click(self, event):
        x, y = event.x_root, event.y_root
        for m in (self, getattr(self, "sub", None)):
            if m and m.winfo_exists():
                try:
                    wx, wy = m.winfo_rootx(), m.winfo_rooty()
                    ww, wh = m.winfo_width(), m.winfo_height()
                    if wx <= x <= wx + ww and wy <= y <= wy + wh:
                        return
                except Exception:
                    pass
        self.close_all()

    def close_all(self):
        if StylusContextMenu._active:
            StylusContextMenu._active.close()

    def close(self):
        self._unhook_pointer()
        if self.sub:
            try:
                self.sub.close()
            except Exception:
                pass
            self.sub = None
        if not self.is_sub:
            root = self.parent.winfo_toplevel()
            for attr in ("_click_id", "_rclick_id", "_esc_id"):
                bind_id = getattr(self, attr, None)
                if bind_id and root.winfo_exists():
                    try:
                        seq = "<Button-1>" if attr == "_click_id" else ("<Button-3>" if attr == "_rclick_id" else "<Escape>")
                        root.unbind(seq, bind_id)
                    except Exception:
                        pass
            if StylusContextMenu._active is self:
                StylusContextMenu._active = None
        try:
            self.destroy()
        except Exception:
            pass


class CatalogoPanel(ctk.CTkFrame):
    def __init__(self, master, catalogo, on_select, on_add, app=None):
        super().__init__(master, fg_color=T.CARD, corner_radius=10, border_width=1, border_color=T.BORDER, width=T.LEFT_W)
        self.catalogo, self.on_select, self.on_add, self.app = catalogo, on_select, on_add, app
        self.grid_propagate(False)
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)
        self.selected: str | None = None
        self.selected_set: set[str] = set()
        self._anchor: str | None = None
        self._rows: dict[str, tuple] = {}
        self._heads: dict[str, ctk.CTkLabel] = {}
        self._job = None
        self._lp_job = None
        self._lp_fired = False
        self._lp_start = (0, 0)

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
        self.btn_add = ctk.CTkButton(bar, text="+", width=30, height=30, corner_radius=8, fg_color=T.CARD, hover_color=T.SOFT,
                      text_color=T.TXT, border_width=1, border_color=T.FIELD_BORDER, font=T.font(15, True),
                      command=self.on_add)
        self.btn_add.grid(row=0, column=1, padx=(6, 0))
        self.btn_menu = ctk.CTkButton(bar, text="⋮", width=28, height=30, corner_radius=8, fg_color=T.CARD, hover_color=T.SOFT,
                       text_color=T.TXT, border_width=1, border_color=T.FIELD_BORDER, font=T.font(16, True),
                       command=self._on_btn_menu_click)
        self.btn_menu.grid(row=0, column=2, padx=(4, 0))

        import tkinter as tk
        self._ROW_H, self._HEAD_H = 26, 16
        self._W = 0
        self._vis: list = []
        self._items: dict[str, tuple] = {}
        self._row_bounds: list[tuple[int, int, str]] = []
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
        self.cv.bind("<Button-3>", lambda e: self._on_context_menu(e, None))
        self.cv.bind("<ButtonRelease-1>", lambda _e: self._cancel_lp(), add="+")
        self.cv.bind("<B1-Motion>", self._on_lp_motion, add="+")
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

    def rebuild(self, keep=True):
        self._rows.clear()
        actual = self.grp.get()
        vals = ["Todos los grupos", *self.catalogo.grupos()]
        if list(self.grp.cget("values")) != vals:
            self.grp.configure(values=vals)
        if actual not in vals:
            self.grp.set("Todos los grupos")
        for ev in self.catalogo.eventos:
            self._rows[ev.id] = (None, None, ev)   # forma (row, tx, ev) conservada
        self._filter(keep=keep)

    def _sched(self, _e=None):
        if self._job:
            self.after_cancel(self._job)
        self._job = self.after(150, lambda: self._filter(keep=False))

    def _filter(self, keep=True):
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
        self._render_canvas(keep=keep)

    def _render_canvas(self, keep=True):
        cv = self.cv
        w = max(cv.winfo_width(), 80)
        self._W = w
        py0 = cv.canvasy(0) if keep else 0.0
        cv.delete("all")
        self._items.clear()
        self._row_bounds.clear()
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
            on = key in self.selected_set
            is_lead = (key == self.selected)
            rect = self._rrect(4, y, w - 6, y + self._ROW_H - 2, 8,
                               fill=soft if on else self._bg, outline="")
            pausado = getattr(ev, "pausado", False)
            nom = f"⏸ {ev.nombre}" if pausado else ev.nombre
            font_use = self._fb if (is_lead or on) else self._f
            txt = cv.create_text(22, y + self._ROW_H / 2 - 1,
                                 text=ellipsize(nom, self._f, max(60, w - 58)),
                                 font=font_use,
                                 fill=self._c(T.PRIMARY if on else (T.TXT2 if pausado else T.TXT)),
                                 anchor="w", state="disabled")
            self._items[key] = (rect, txt)
            self._row_bounds.append((y, y + self._ROW_H, key))
            cv.tag_bind(rect, "<Button-1>", lambda e, i=key: self._on_row_down(e, i))
            cv.tag_bind(txt, "<Button-1>", lambda e, i=key: self._on_row_down(e, i))
            cv.tag_bind(rect, "<ButtonRelease-1>", lambda e: self._on_row_up(e))
            cv.tag_bind(txt, "<ButtonRelease-1>", lambda e: self._on_row_up(e))
            cv.tag_bind(rect, "<B1-Motion>", self._on_lp_motion)
            cv.tag_bind(txt, "<B1-Motion>", self._on_lp_motion)
            cv.tag_bind(rect, "<Button-3>", lambda e, i=key: self._on_context_menu(e, i))
            cv.tag_bind(txt, "<Button-3>", lambda e, i=key: self._on_context_menu(e, i))
            cv.tag_bind(rect, "<Enter>", lambda _e, i=key: self._hov(i, True))
            cv.tag_bind(rect, "<Leave>", lambda _e, i=key: self._hov(i, False))
            y += self._ROW_H
        total = y + 4
        cv.configure(scrollregion=(0, 0, w, total))
        if keep and py0 > 0.0:
            vis_h = max(cv.winfo_height(), 1)
            cv.yview_moveto(min(py0, max(0, total - vis_h)) / total)
        elif not keep:
            cv.yview_moveto(0.0)

    def _hov(self, i, enter):
        it = self._items.get(i)
        if not it:
            return
        self.cv.configure(cursor="hand2" if enter else "")
        if i not in self.selected_set:
            self.cv.itemconfigure(it[0], fill=self._c(T.SOFT) if enter else self._bg)

    def _on_row_click(self, event, key: str):
        shift = bool(event.state & 0x0001)
        ctrl = bool(event.state & 0x0004)
        vis_keys = [k for kind, k in self._vis if kind == "r"]

        if shift and self._anchor and self._anchor in vis_keys and key in vis_keys:
            i1 = vis_keys.index(self._anchor)
            i2 = vis_keys.index(key)
            start, end = min(i1, i2), max(i1, i2)
            rango = set(vis_keys[start:end + 1])
            if ctrl:
                self.selected_set.update(rango)
            else:
                self.selected_set = rango
            self.selected = key
            self._paint()
            self.on_select(key)
        elif ctrl:
            if key in self.selected_set:
                self.selected_set.remove(key)
                if self.selected == key:
                    self.selected = next(iter(self.selected_set), None)
                    if self.selected:
                        self.on_select(self.selected)
            else:
                self.selected_set.add(key)
                self.selected = key
                self._anchor = key
                self.on_select(key)
            self._paint()
        else:
            self.selected_set = {key}
            self._anchor = key
            self.select(key, notify=True)

    def select(self, id_ev: str, notify=True):
        prev = self.selected
        self.selected = id_ev
        if id_ev:
            self.selected_set = {id_ev}
            self._anchor = id_ev
        else:
            self.selected_set.clear()
            self._anchor = None
        self._paint()
        if notify and id_ev and (prev != id_ev or getattr(self, "_force_notify", False)):
            self.on_select(id_ev)

    def _paint(self):
        w = self._W or 80
        for i, (rect, txt) in self._items.items():
            on = i in self.selected_set
            is_lead = (i == self.selected)
            self.cv.itemconfigure(rect, fill=self._c(T.SOFT) if on else self._bg)
            ev = self._rows[i][2] if i in self._rows else None
            pausado = getattr(ev, "pausado", False) if ev else False
            font_use = self._fb if (is_lead or on) else self._f
            nom = f"⏸ {ev.nombre}" if (ev and pausado) else (ev.nombre if ev else "")
            self.cv.itemconfigure(txt, text=ellipsize(nom, self._f, max(60, w - 58)),
                                  fill=self._c(T.PRIMARY if on else (T.TXT2 if pausado else T.TXT)),
                                  font=font_use)

    def _cancel_lp(self):
        if self._lp_job is not None:
            try:
                self.after_cancel(self._lp_job)
            except Exception:
                pass
            self._lp_job = None

    def _start_lp(self, event, key: str):
        self._cancel_lp()
        self._lp_fired = False
        self._lp_start = (event.x_root, event.y_root)
        self._lp_job = self.after(420, lambda: self._trigger_lp(event, key))

    def _trigger_lp(self, event, key: str):
        self._lp_job = None
        self._lp_fired = True
        self._on_context_menu(event, key)

    def _on_lp_motion(self, event):
        if self._lp_job is not None:
            dx = abs(event.x_root - self._lp_start[0])
            dy = abs(event.y_root - self._lp_start[1])
            if dx > 8 or dy > 8:
                self._cancel_lp()

    def _on_row_down(self, event, key: str):
        self._on_row_click(event, key)
        self._start_lp(event, key)

    def _on_row_up(self, event):
        self._cancel_lp()

    def _on_btn_menu_click(self):
        try:
            x = self.btn_menu.winfo_rootx()
            y = self.btn_menu.winfo_rooty() + self.btn_menu.winfo_height() + 2
        except Exception:
            x, y = 100, 100
        class _Ev:
            pass
        ev = _Ev()
        ev.x_root = int(x)
        ev.y_root = int(y)
        ev.y = 0
        self._on_context_menu(ev, self.selected)

    # ── menú contextual y acciones del catálogo (compatible con stylus/ratón) ──
    def _on_context_menu(self, event, id_ev: str | None = None):
        # 1. Si no vino id_ev (clic con stylus o en el lienzo), resolver la fila por coordenadas
        if id_ev is None:
            cy = self.cv.canvasy(event.y)
            for y1, y2, k in self._row_bounds:
                if y1 <= cy <= y2:
                    id_ev = k
                    break

        # 2. Si todavía es None pero ya había un evento seleccionado, usar la selección activa
        if id_ev is None and self.selected:
            id_ev = self.selected

        # 3. Actualizar selección visual sin recargar innecesariamente el panel editor
        if id_ev:
            if id_ev not in self.selected_set:
                self.selected_set = {id_ev}
                self._anchor = id_ev
                self.selected = id_ev
            else:
                self.selected = id_ev
            self._paint()

        menu = StylusContextMenu(self, event.x_root, event.y_root)
        menu.add_command("➕  Nuevo evento", self.on_add)
        menu.add_separator()

        num_sel = len(self.selected_set)
        if num_sel > 1:
            pausados_cnt = sum(1 for eid in self.selected_set if getattr(self.catalogo.por_id(eid), "pausado", False))
            if pausados_cnt == num_sel:
                menu.add_command(f"▶  Activar seleccionados ({num_sel})", lambda: self._pausar_seleccionados(False))
            elif pausados_cnt == 0:
                menu.add_command(f"⏸  Pausar seleccionados ({num_sel})", lambda: self._pausar_seleccionados(True))
            else:
                menu.add_command(f"⏸  Pausar seleccionados ({num_sel})", lambda: self._pausar_seleccionados(True))
                menu.add_command(f"▶  Activar seleccionados ({num_sel})", lambda: self._pausar_seleccionados(False))

            customs = [eid for eid in self.selected_set if getattr(self.catalogo.por_id(eid), "custom", False)]
            if customs:
                menu.add_command(f"🗑  Eliminar eventos custom ({len(customs)})", self._eliminar_seleccionados)
            else:
                menu.add_command("🗑  Eliminar eventos (solo de fábrica)", None, state="disabled")

            def _build_sub_multi(sub):
                for g in self.catalogo.grupos():
                    sub.add_command(f"    {g}", lambda grp=g: self._mover_grupo_seleccionados(grp))
                sub.add_separator()
                sub.add_command("➕  Nuevo grupo…", self._pedir_nuevo_grupo_seleccionados)

            menu.add_cascade(f"📁  Guardar en grupo ({num_sel})", _build_sub_multi)

        elif id_ev:
            ev = self.catalogo.por_id(id_ev)
            if ev:
                menu.add_command("📋  Duplicar / Replicar evento", lambda: self._duplicar_evento(ev.id))

                esta_pausado = getattr(ev, "pausado", False)
                lbl_pausa = "▶  Activar evento" if esta_pausado else "⏸  Pausar / Activar evento"
                menu.add_command(lbl_pausa, lambda: self._toggle_pausa_evento(ev.id))

                if getattr(ev, "custom", False):
                    menu.add_command("🗑  Eliminar evento", lambda: self._eliminar_evento(ev.id))
                else:
                    menu.add_command("🗑  Eliminar evento (de fábrica)", None, state="disabled")

                def _build_sub_single(sub):
                    for g in self.catalogo.grupos():
                        chk = "✓ " if ev.grupo == g else "    "
                        sub.add_command(f"{chk}{g}", lambda grp=g: self._mover_grupo_evento(ev.id, grp))
                    sub.add_separator()
                    sub.add_command("➕  Nuevo grupo…", lambda: self._pedir_nuevo_grupo(ev.id))

                menu.add_cascade("📁  Guardar en grupo", _build_sub_single)
        else:
            menu.add_command("📋  Duplicar / Replicar evento", None, state="disabled")
            menu.add_command("⏸  Pausar / Activar evento", None, state="disabled")
            menu.add_command("🗑  Eliminar evento", None, state="disabled")
            menu.add_command("📁  Guardar en grupo", None, state="disabled")

        menu.show(event.x_root, event.y_root)
        return "break"

    def _pausar_seleccionados(self, pausar: bool):
        store = getattr(self.app, "store", None) or getattr(self.catalogo, "store", None)
        if not store or not self.selected_set:
            return
        val = "1" if pausar else None
        patches = [("EventosPausados", eid, val) for eid in self.selected_set]
        try:
            store.save_patches(patches)
        except OSError as e:
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash(str(e), False)
            return
        if self.app and hasattr(self.app, "bridge"):
            self.app.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        for ev_reloaded in self.catalogo.eventos:
            if ev_reloaded.id in self._rows:
                self._rows[ev_reloaded.id] = (None, None, ev_reloaded)
        self._paint()
        accion = "pausados" if pausar else "activados"
        if self.app and hasattr(self.app, "footer"):
            self.app.footer.flash(f"{'⏸' if pausar else '▶'} {len(patches)} eventos {accion}")

    def _mover_grupo_seleccionados(self, nuevo_grupo: str):
        store = getattr(self.app, "store", None) or getattr(self.catalogo, "store", None)
        if not store or not self.selected_set or not nuevo_grupo:
            return
        patches = [("EventosGrupo", eid, nuevo_grupo) for eid in self.selected_set]
        try:
            store.save_patches(patches)
        except OSError as e:
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash(str(e), False)
            return
        if self.app and hasattr(self.app, "bridge"):
            self.app.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        self.rebuild()
        if self.selected:
            self._paint()
        if self.app and hasattr(self.app, "footer"):
            self.app.footer.flash(f"📁 {len(patches)} eventos movidos a '{nuevo_grupo}'")

    def _pedir_nuevo_grupo_seleccionados(self):
        dialog = ctk.CTkInputDialog(text="Nombre del nuevo grupo para la selección:", title="Nuevo Grupo")
        nuevo = dialog.get_input()
        if nuevo and nuevo.strip():
            self._mover_grupo_seleccionados(nuevo.strip())

    def _eliminar_seleccionados(self):
        store = getattr(self.app, "store", None) or getattr(self.catalogo, "store", None)
        if not store or not self.selected_set:
            return
        customs = [eid for eid in self.selected_set if getattr(self.catalogo.por_id(eid), "custom", False)]
        if not customs:
            return
        import tkinter.messagebox as mb
        if not mb.askyesno("Eliminar eventos", f"¿Eliminar definitivamente los {len(customs)} eventos seleccionados?"):
            return
        lista = [c for c in (store.get("EventosCustom", "lista", "") or "").split(",") if c.strip()]
        lista_nueva = [c for c in lista if c not in customs]
        patches = [("EventosCustom", "lista", ",".join(lista_nueva))]
        for eid in customs:
            patches.append(("EventosCustom", eid, None))
            patches.append(("EventosPausados", eid, None))
            patches.append(("EventosGrupo", eid, None))
        try:
            store.save_patches(patches)
        except OSError as e:
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash(str(e), False)
            return
        if self.app and hasattr(self.app, "bridge"):
            self.app.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        self.selected_set.difference_update(customs)
        self.selected = next(iter(self.selected_set), None) or (self.catalogo.eventos[0].id if self.catalogo.eventos else None)
        self.rebuild()
        if self.selected:
            self.select(self.selected)
        if self.app and hasattr(self.app, "footer"):
            self.app.footer.flash(f"🗑 {len(customs)} eventos eliminados")

    def _toggle_pausa_evento(self, id_ev: str):
        ev = self.catalogo.por_id(id_ev)
        if not ev:
            return
        store = getattr(self.app, "store", None) or getattr(self.catalogo, "store", None)
        if not store:
            return
        val = store.get("EventosPausados", id_ev, "0")
        nuevo_val = None if val == "1" else "1"
        try:
            store.save_patches([("EventosPausados", id_ev, nuevo_val)])
        except OSError as e:
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash(str(e), False)
            return
        if self.app and hasattr(self.app, "bridge"):
            self.app.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        for ev_reloaded in self.catalogo.eventos:
            if ev_reloaded.id in self._rows:
                self._rows[ev_reloaded.id] = (None, None, ev_reloaded)
        self._paint()
        msg = f"⏸ Evento '{ev.nombre}' pausado" if nuevo_val == "1" else f"▶ Evento '{ev.nombre}' activado"
        if self.app and hasattr(self.app, "footer"):
            self.app.footer.flash(msg)

    def _duplicar_evento(self, id_ev: str):
        orig = self.catalogo.por_id(id_ev)
        if not orig:
            return
        store = getattr(self.app, "store", None) or getattr(self.catalogo, "store", None)
        if not store:
            return
        cid, _ = self.catalogo.siguiente_custom()
        nombre_copia = f"Copia de {orig.nombre}"
        atajo = orig.atajo_def or ""
        lista = [c for c in (store.get("EventosCustom", "lista", "") or "").split(",") if c.strip()]
        patches = [
            ("EventosCustom", "lista", ",".join([*lista, cid])),
            ("EventosCustom", cid, f"{nombre_copia}|{atajo}")
        ]
        if orig.grupo:
            patches.append(("EventosGrupo", cid, orig.grupo))
        try:
            store.save_patches(patches)
        except OSError as e:
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash(str(e), False)
            return
        if self.app and hasattr(self.app, "bridge"):
            self.app.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        self.rebuild()
        self.select(cid)
        if self.app and hasattr(self.app, "footer"):
            self.app.footer.flash(f"📋 Duplicado: '{orig.nombre}' -> '{nombre_copia}'")

    def _eliminar_evento(self, id_ev: str):
        ev = self.catalogo.por_id(id_ev)
        if not ev or not getattr(ev, "custom", False):
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash("Solo se pueden eliminar eventos personalizados", False)
            return
        store = getattr(self.app, "store", None) or getattr(self.catalogo, "store", None)
        if not store:
            return
        import tkinter.messagebox as mb
        if not mb.askyesno("Eliminar evento", f"¿Eliminar '{ev.nombre}' definitivamente?"):
            return
        lista = [c for c in (store.get("EventosCustom", "lista", "") or "").split(",") if c.strip()]
        lista_nueva = [c for c in lista if c != id_ev]
        patches = [
            ("EventosCustom", "lista", ",".join(lista_nueva)),
            ("EventosCustom", id_ev, None),
            ("EventosPausados", id_ev, None),
            ("EventosGrupo", id_ev, None),
        ]
        try:
            store.save_patches(patches)
        except OSError as e:
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash(str(e), False)
            return
        if self.app and hasattr(self.app, "bridge"):
            self.app.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        self.rebuild()
        primer = self.catalogo.eventos[0].id if self.catalogo.eventos else None
        if primer:
            self.select(primer)
        if self.app and hasattr(self.app, "footer"):
            self.app.footer.flash(f"🗑 Evento '{ev.nombre}' eliminado")

    def _mover_grupo_evento(self, id_ev: str, nuevo_grupo: str):
        ev = self.catalogo.por_id(id_ev)
        if not ev or not nuevo_grupo or ev.grupo == nuevo_grupo:
            return
        store = getattr(self.app, "store", None) or getattr(self.catalogo, "store", None)
        if not store:
            return
        try:
            store.save_patches([("EventosGrupo", id_ev, nuevo_grupo)])
        except OSError as e:
            if self.app and hasattr(self.app, "footer"):
                self.app.footer.flash(str(e), False)
            return
        if self.app and hasattr(self.app, "bridge"):
            self.app.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        self.rebuild(keep=True)
        if self.selected == id_ev:
            self._paint()
        else:
            self.select(id_ev)
        if self.app and hasattr(self.app, "footer"):
            self.app.footer.flash(f"📁 '{ev.nombre}' movido al grupo '{nuevo_grupo}'")

    def _pedir_nuevo_grupo(self, id_ev: str):
        dialog = ctk.CTkInputDialog(text="Nombre del nuevo grupo:", title="Nuevo Grupo")
        nuevo = dialog.get_input()
        if nuevo and nuevo.strip():
            self._mover_grupo_evento(id_ev, nuevo.strip())


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
            toggle_cb = lambda _e, k=key, c=chev: self._toggle_group(k, c)
            for w in (head, badge, b_lbl, l1, l_sub, chev):
                w.bind("<Button-1>", toggle_cb)
                if hasattr(w, "_canvas") and w._canvas:
                    w._canvas.bind("<Button-1>", toggle_cb)
                if hasattr(w, "_label") and w._label:
                    w._label.bind("<Button-1>", toggle_cb)
                try:
                    w.configure(cursor="hand2")
                except Exception:
                    pass
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
        prev_id = getattr(self.ctx, "event_id", None)
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
        if prev_id != ev.id:
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
