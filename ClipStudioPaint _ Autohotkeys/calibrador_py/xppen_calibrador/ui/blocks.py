"""Tarjetas de bloque (A·Configuración básica, B·Particularidades), enlazadas al borrador."""
from __future__ import annotations
import tkinter as tk
import customtkinter as ctk
from . import theme as T
from .widgets import (lbl, btn, check, combo, entry, switch, Hint, Stepper, ColorChip, ResponsiveRow, FlowRow, EvenRow)
from ..core.ini_schema import FIELDS, PILDORA_TAMS


class Ctx:
    """Contexto compartido entre bloques (evento actual, borrador, puente, avisos)."""
    def __init__(self, draft, bridge, catalogo, on_dirty):
        self.draft, self.bridge, self.catalogo, self.on_dirty = draft, bridge, catalogo, on_dirty
        self.event_id: str | None = None
        self.blocks: list["Block"] = []

    def eid(self, name: str) -> str:
        return "" if "{id}" not in FIELDS[name].key else (self.event_id or "")

    def get(self, name):
        return self.draft.get(name, self.eid(name))

    def explicito(self, name) -> bool:
        """False = la clave no tiene valor propio (se muestra la fábrica en gris)."""
        try:
            return self.draft.explicito(name, self.eid(name))
        except Exception:
            return True

    def set(self, name, value) -> bool:
        ok = self.draft.set(name, self.eid(name), value)
        if ok:
            self.on_dirty()
        return ok

    def refresh_all(self):
        for b in self.blocks:
            if b.expanded:
                b.refresh()
            else:
                b.refresh_master_only()


class Block(ctk.CTkFrame):
    NUM, TITLE, SUB, CAP = "", "", "", None          # CAP: nombre de capacidad en Evento.tiene()
    MASTER: tuple[str, ...] = ()                     # flags que gobiernan el check de cabecera
    MASTER_DEFAULT = ""                              # flag que se enciende al activar el maestro

    def __init__(self, master, ctx: Ctx, on_toggle):
        super().__init__(master, fg_color=T.CARD, corner_radius=12, border_width=1, border_color="#E5E0F0")
        self.ctx, self.on_toggle = ctx, on_toggle
        self.expanded, self._built, self._loading, self.available = False, False, False, True
        self._loaders: list = []
        self._stash: dict[str, object] = {}
        self.grid_columnconfigure(0, weight=1)
        self._header()
        self.body = ctk.CTkFrame(self, fg_color="transparent", width=0, height=0)
        ctx.blocks.append(self)

    # ── cabecera ───────────────────────────────────────────
    def _header(self):
        h = ctk.CTkFrame(self, fg_color="transparent", height=T.HEADER_H)
        h.grid(row=0, column=0, sticky="ew", padx=T.PAD, pady=(8, 4))
        h.grid_columnconfigure(1, weight=1)
        self.hdr = h
        self.num_badge = ctk.CTkFrame(
            h, fg_color=T.SOFT, corner_radius=8,
            width=T.BADGE_W, height=T.BADGE_H)
        self.num_badge.grid(row=0, column=0, rowspan=2, padx=(0, 10))
        self.num_badge.grid_propagate(False)
        self.l_num = lbl(self.num_badge, self.NUM, 11, T.PRIMARY, True)
        self.l_num.place(relx=0.5, rely=0.5, anchor="center")
        import customtkinter as _ctk
        from .widgets import icon_btn as _icon_btn
        self.title_row = _ctk.CTkFrame(h, fg_color="transparent")
        self.title_row.grid(row=0, column=1, sticky="w")
        self.l_title = lbl(self.title_row, self.TITLE, 13, T.TXT, True)
        self.l_title.pack(side="left")
        _ht = getattr(self, "HDR_TEST", None)          # (glifo, tooltip, nombre_método)
        if _ht:
            self.b_test = _icon_btn(self.title_row, _ht[0],
                                    lambda n=_ht[2]: getattr(self, n)(), tip=_ht[1])
            self.b_test.pack(side="left", padx=(6, 0))
        self.l_sub = lbl(h, self.SUB, 10, T.TXT2)
        self.l_sub.grid(row=1, column=1, sticky="w", pady=(0, 0))
        self.m_var = tk.IntVar(value=0)
        self.m_chk = check(h, "", self.m_var, self._master_click)
        self.m_chk.configure(width=22)
        if self.MASTER:
            self.m_chk.grid(row=0, column=2, rowspan=2, padx=(8, 6), sticky="")
        self.chev = lbl(h, "⌄", 16, T.TXT2, anchor="center", width=22)
        self.chev.grid(row=0, column=3, rowspan=2, sticky="")
        for w in (h, self.num_badge, self.l_num, self.l_title, self.l_sub, self.chev):
            w.bind("<Button-1>", lambda _e: self.toggle())
            w.configure(cursor="hand2")

    def toggle(self):
        if not self.available:
            return
        self.set_expanded(not self.expanded)
        self.on_toggle(self)

    def prewarm(self):
        if self.available and not self._built:
            self.build(self.body)   # body aún oculto: sin repintados intermedios
            self._built = True

    def set_expanded(self, on: bool):
        self.expanded = on
        self.chev.configure(text="⌃" if on else "⌄")
        if not on:
            self.body.grid_remove()
            return
        self.prewarm()
        self.body.grid(row=1, column=0, sticky="ew", padx=T.PAD, pady=(2, 10))
        self.refresh()

    def set_available(self, ok: bool):
        self.available = ok
        if not ok and self.expanded:
            self.set_expanded(False)
        self.l_title.configure(text_color=T.TXT if ok else T.TXT3)
        self.l_sub.configure(text=self.SUB if ok else "No disponible para este evento")
        self.chev.configure(text_color=T.TXT2 if ok else T.TXT3)
        if self.MASTER:
            (self.m_chk.grid if ok else self.m_chk.grid_remove)()

    # ── maestro derivado (G1: sin claves nuevas) ───────────
    def master_on(self) -> bool:
        return any(self.ctx.get(n) for n in self.MASTER)

    def master_apply(self, on: bool):
        if on:
            restore = {n: v for n, v in self._stash.items() if v}
            for n in (restore or {self.MASTER_DEFAULT: 1}):
                self.ctx.set(n, 1)
        else:
            self._stash = {n: self.ctx.get(n) for n in self.MASTER}
            for n in self.MASTER:
                self.ctx.set(n, 0)

    def _master_click(self):
        self.master_apply(bool(self.m_var.get()))
        self.ctx.refresh_all()

    def _sync_master(self):
        nv = 1 if self.master_on() else 0
        if self.m_var.get() != nv:
            self.m_var.set(nv)

    # ── refresco ───────────────────────────────────────────
    def refresh(self):
        if self.MASTER and self.ctx.event_id:
            self._sync_master()
        if not (self._built and self.expanded and self.ctx.event_id is not None):
            return
        self._loading = True
        try:
            for fn in self._loaders:
                fn()
        finally:
            self._loading = False

    def build(self, parent):            # subclases
        raise NotImplementedError

    # ── fábrica de controles enlazados ─────────────────────
    def _commit(self, name, value) -> bool:
        if self._loading:
            return True
        err = self.pre_validate(name, value)
        if err:
            return False
        ok = self.ctx.set(name, value)
        if ok:
            self.after_change(name)
        return ok

    def pre_validate(self, name, value):
        return None

    def after_change(self, name):
        if name in {n for b in self.ctx.blocks for n in b.MASTER}:
            self.ctx.refresh_all()
        else:
            self.refresh_master_only()

    def refresh_master_only(self):
        if self.MASTER:
            self._sync_master()

    def f_check(self, parent, name, text):
        var = tk.IntVar(value=0)
        w = check(parent, text, var, lambda: self._commit(name, var.get()))
        self._loaders.append(lambda: var.set(self.ctx.get(name)))
        return w

    def f_switch(self, parent, name):
        var = tk.IntVar(value=0)
        w = switch(parent, var, lambda: self._commit(name, var.get()))
        self._loaders.append(lambda: var.set(self.ctx.get(name)))
        return w

    def f_menu(self, parent, name, items, width=130):
        """items: [(etiqueta, valor_ini)]"""
        l2v, v2l = dict(items), {str(v).lower(): l for l, v in items}
        w = combo(parent, [l for l, _ in items], width=width,
                  command=lambda lab: self._commit(name, l2v[lab]))

        def load():
            cur = str(self.ctx.get(name))
            lab = v2l.get(cur.lower())
            if lab is None:
                lab = cur
                w.configure(values=[*[l for l, _ in items], lab])
            w.set(lab)
        self._loaders.append(load)
        return w

    def f_stepper(self, parent, name, step=1, width=38, suffix=""):
        f = FIELDS[name]
        if suffix:
            box = ctk.CTkFrame(parent, fg_color="transparent")
            w = Stepper(box, f.lo, f.hi, step, width, on_commit=lambda t: self._commit(name, t))
            w.pack(side="left")
            lbl(box, suffix, 10, T.TXT2).pack(side="left", padx=(4, 0))
            self._loaders.append(lambda: w.set(self.ctx.get(name)))
            return box
        w = Stepper(parent, f.lo, f.hi, step, width, on_commit=lambda t: self._commit(name, t))
        self._loaders.append(lambda: w.set(self.ctx.get(name)))
        return w

    def f_entry(self, parent, name, width=140, placeholder=""):
        w = entry(parent, width, placeholder)

        def commit(_e=None):
            ok = self._commit(name, w.get())
            w.configure(border_color=T.FIELD_BORDER if ok else T.DANGER)
        w.bind("<FocusOut>", commit)
        w.bind("<Return>", commit)

        def load():
            w.delete(0, "end")
            w.insert(0, str(self.ctx.get(name)))
            w.configure(border_color=T.FIELD_BORDER)
        self._loaders.append(load)
        return w

    def f_entry_default(self, parent, name, width=56, defecto="1000", vacio="auto"):
        """Entry con valor de fábrica visible en gris.

        - Sin valor propio (INI == `vacio`, p. ej. "auto"): el campo se ve
          vacío y muestra `defecto` en gris (placeholder).
        - Con valor propio: el número se muestra en negro (texto normal).
        - Confirmar en blanco guarda `vacio` y vuelve al valor de fábrica.

        Reutilizable en cualquier bloque; A02Hud lo usa para la duración.
        """
        w = entry(parent, width)
        w.configure(placeholder_text=str(defecto), placeholder_text_color=T.TXT3)

        def commit(_e=None):
            raw = w.get().strip()
            ok = self._commit(name, vacio if raw == "" else raw)
            w.configure(border_color=T.FIELD_BORDER if ok else T.DANGER)
        w.bind("<FocusOut>", commit)
        w.bind("<Return>", commit)

        def load():
            cur = str(self.ctx.get(name) or "").strip()
            w.delete(0, "end")
            if cur and cur.lower() != str(vacio).lower():
                w.insert(0, cur)            # valor propio -> negro
            else:
                # delete() borra el texto del placeholder: hay que reactivarlo
                try:
                    w._activate_placeholder()
                except Exception:
                    pass
            w.configure(border_color=T.FIELD_BORDER)
        self._loaders.append(load)
        return w

    def f_stepper_default(self, parent, name, step=1, width=48, suffix=""):
        """Stepper con valor de fábrica en gris y valor propio en negro.

        - Sin valor propio: se muestra el valor efectivo de fábrica en gris
          (p. ej. el `quick_ms` del evento: 250/300/400 según la tabla de
          particularidades), no un número inventado.
        - Con valor propio: negro.
        - Vaciar el campo y confirmar vuelve al valor de fábrica.
        - Los ▴/▾ parten del valor de fábrica aunque el campo esté en gris.

        Reutilizable en cualquier bloque; B03 lo usa para el umbral (ms).
        """
        f = FIELDS[name]
        w = Stepper(parent, f.lo, f.hi, step, width, suffix=suffix,
                    on_commit=lambda t: self._commit_stepper_default(name, w, t))

        def load():
            val = self.ctx.get(name)
            if self.ctx.explicito(name):
                w.set(val)                  # propio -> negro
            else:
                w.set_default(val)          # fábrica -> gris
        self._loaders.append(load)
        return w

    def _commit_stepper_default(self, name, w, texto):
        txt = str(texto).strip()
        if txt == "":
            txt = str(w.fallback if w.fallback is not None else FIELDS[name].default)
        if not self._commit(name, txt):
            return False
        if self.ctx.explicito(name):
            w.set(self.ctx.get(name))
        else:
            w.set_default(self.ctx.get(name))
        return True

    def f_key_entry(self, parent, name, width=90, on_clear=None):
        """Campo estándar para captura de atajos de teclado (hasta 4 teclas).
        Incluye Entry con fuente condensada, attach_keycapture y dúo compacto ✓/✕."""
        from .widgets import KEY_W, duo_ok_clear
        width = max(width, KEY_W)
        c = ctk.CTkFrame(parent, fg_color="transparent")
        e = self.f_entry(c, name, width)
        e.pack(side="left", padx=(0, 2))

        from .widgets import _find_entry, attach_keycapture
        _en = _find_entry(e)
        if _en is not None:
            _en.configure(font=T.font_cap(11))

        def clear():
            if on_clear:
                on_clear()
            else:
                e.delete(0, "end")
                self._commit(name, "")

        attach_keycapture(e, on_clear=clear)

        # Dúo ✓ / ✕ apilado: alto == KEY_H, sin márgenes internos
        duo_ok_clear(c, on_ok=lambda: self._commit(name, e.get()),
                     on_clear=clear).pack(side="left", padx=(1, 0))
        return c, e

    def row(self, parent, r, label, widget, label_w=120):
        lbl(parent, label, 12, T.TXT2, width=label_w).grid(row=r, column=0, sticky="w", pady=3)
        widget.grid(row=r, column=1, sticky="w", pady=3)

    def inline(self, flow, texto, make, gap=6, chip=False):
        """Celda etiqueta+control para FlowRow. make(contenedor) crea el control."""
        c = ctk.CTkFrame(flow, fg_color="transparent", width=0, height=0)
        if chip:
            ch = ctk.CTkFrame(c, fg_color=T.SOFT, corner_radius=10)
            ch.grid(row=0, column=0, sticky="w", padx=(0, gap))
            lbl(ch, texto, 11, T.PRIMARY, True).pack(padx=10, pady=2)
        else:
            lbl(c, texto, 12, T.TXT2).grid(row=0, column=0, sticky="w", padx=(0, gap))
        w = make(c)
        w.grid(row=0, column=1, sticky="w")
        flow.add(c)
        return w


def _cols(parent, weights=(1,)):
    for i, w in enumerate(weights):
        parent.grid_columnconfigure(i, weight=w)


# ═══ A · Configuración básica ═══════════════════════════════════════════════
class A01Base(Block):
    NUM, TITLE, SUB = "01", "Base", "Identidad, apariencia y comportamiento general del evento."

    def build(self, p):
        _cols(p, (1,))
        fr = ctk.CTkFrame(p, fg_color="transparent")
        fr.grid(row=0, column=0, sticky="ew")
        self._flow = fr

        ca = ctk.CTkFrame(fr, fg_color="transparent")
        ca.pack(side="left", padx=(0, 24))
        lbl(ca, "Atajo CSP", 11, T.TXT2).pack(side="left", padx=(0, 6))
        c1, e1 = self.f_key_entry(ca, "atajo", 90, on_clear=lambda: self._reset("atajo", e1))
        c1.pack(side="left")

        cr = ctk.CTkFrame(fr, fg_color="transparent")
        cr.pack(side="left", padx=(0, 16))
        lbl(cr, "Remapeo Companion", 11, T.TXT2).pack(side="left", padx=(0, 6))
        c2, e2 = self.f_key_entry(cr, "remap", 110, on_clear=lambda: self._reset("remap", e2))
        c2.pack(side="left")

        self.aviso = lbl(fr, "", 10, T.WARN)
        self.aviso.pack(side="left")
        self.aviso.pack(side="left")

        def load_base():
            ev = self.ctx.catalogo.por_id(self.ctx.event_id)
            cur_a = self.ctx.get("atajo")
            cur_r = self.ctx.get("remap")
            val_a = cur_a if (cur_a and cur_a != "—") else (ev.atajo_def if ev and ev.atajo_def != "—" else "")
            val_r = cur_r if (cur_r and cur_r != "—") else (ev.remap_def if ev and ev.remap_def != "—" else "")
            e1.delete(0, "end")
            e1.insert(0, str(val_a))
            e2.delete(0, "end")
            e2.insert(0, str(val_r))
        self._loaders.append(load_base)
        self._loaders.append(self._check_dup)
        e1.bind("<KeyRelease>", lambda _e: self._check_dup(e1.get()), add="+")

    def _reset(self, name, ent):
        ev = self.ctx.catalogo.por_id(self.ctx.event_id)
        def_val = (ev.atajo_def if name == "atajo" else ev.remap_def) if ev else ""
        def_val = "" if def_val == "—" else def_val
        ent.delete(0, "end")
        ent.insert(0, def_val)
        self._commit(name, "")
        self._check_dup()

    def _check_dup(self, typed=None):
        mine = (typed if isinstance(typed, str) else self.ctx.get("atajo")).strip().lower()
        txt = ""
        if mine:
            for ev in self.ctx.catalogo.eventos:
                if ev.id == self.ctx.event_id:
                    continue
                other = (self.ctx.draft.get("atajo", ev.id) or ev.atajo_def).strip().lower()
                if other == mine:
                    txt = f"⚠ Atajo ya usado por «{ev.nombre}»"
                    break
        self.aviso.configure(text=txt)
        flow = getattr(self, "_flow", None)
        if flow and hasattr(flow, "reflow"):
            flow.reflow()


class A02Hud(Block):
    NUM, TITLE, SUB = "02", "Feedback visual (HUD)", "Aviso en pantalla al ejecutar el evento."
    HDR_TEST = ("🔔", "Probar aviso en pantalla", "_test_hud")
    MASTER = ("hud_formato",)

    def _test_hud(self):
        cb = getattr(self, "_probar_hud_cb", None)
        if cb:
            cb()

    def master_on(self):
        return str(self.ctx.get("hud_formato")).lower() != "desactivado"

    def master_apply(self, on):
        if on:
            self.ctx.set("hud_formato", self._stash.get("f") or "moderno")
        else:
            cur = str(self.ctx.get("hud_formato"))
            self._stash = {"f": cur if cur.lower() != "desactivado" else "moderno"}
            self.ctx.set("hud_formato", "desactivado")

    def after_change(self, name):
        self.ctx.refresh_all() if name == "hud_formato" else None

    def build(self, p):
        _cols(p, (1,))
        f1 = ctk.CTkFrame(p, fg_color="transparent")
        f1.grid(row=0, column=0, sticky="ew")

        cf = ctk.CTkFrame(f1, fg_color="transparent")
        cf.pack(side="left", padx=(0, 36))
        lbl(cf, "Formato", 11, T.TXT2).pack(side="left", padx=(0, 8))
        self.f_menu(cf, "hud_formato", [("Moderno", "moderno"), ("Bruto", "bruto"), ("Desactivado", "desactivado")], 106).pack(side="left")

        cz = ctk.CTkFrame(f1, fg_color="transparent")
        cz.pack(side="left", padx=(0, 36))
        lbl(cz, "Zona", 11, T.TXT2).pack(side="left", padx=(0, 8))
        self.f_menu(cz, "hud_zona", [("Baja", "baja"), ("Media", "media"), ("Alta", "alta")], 92).pack(side="left")

        co = ctk.CTkFrame(f1, fg_color="transparent")
        co.pack(side="left")
        lbl(co, "Opacidad", 11, T.TXT2).pack(side="left", padx=(0, 8))
        self.f_menu(co, "hud_opac", [("50 %", "50"), ("70 % (Med)", "70"), ("90 %", "90"), ("100 %", "100")], 96).pack(side="left")

        f2 = ctk.CTkFrame(p, fg_color="transparent")
        f2.grid(row=1, column=0, sticky="ew", pady=(6, 0))

        lbl(f2, "Texto del evento", 11, T.TXT2).pack(side="left", padx=(0, 6))
        t_entry = self.f_entry(f2, "hud_texto", 240, "Por defecto: nombre del evento")
        t_entry.pack(side="left", padx=(0, 18))

        lbl(f2, "Duración", 11, T.TXT2).pack(side="left", padx=(0, 6))
        d = self.f_entry_default(f2, "hud_dur", 56, "1000")
        d.pack(side="left", padx=(0, 4))
        lbl(f2, "ms", 11, T.TXT2).pack(side="left")

        def load_txt():
            cur_t = self.ctx.get("hud_texto")
            ev = self.ctx.catalogo.por_id(self.ctx.event_id)
            if not cur_t and ev:
                t_entry.delete(0, "end")
                t_entry.insert(0, ev.nombre)
        self._loaders.append(load_txt)

        def _probar_hud():
            c = self.ctx
            # El texto no debe traer saltos ni tabuladores (rompen el delimitador del puente)
            txt = " ".join(str(c.get("hud_texto") or "").split())
            c.bridge.send(
                "TEST_HUD", c.event_id, "",                 # "" = color por defecto en AHK
                str(c.get("hud_formato") or ""),
                str(c.get("hud_zona") or ""),
                str(c.get("hud_opac") or ""),
                txt,
                str(c.get("hud_dur") or ""))

        self._probar_hud_cb = _probar_hud     # lo dispara el icono 🔔 de la cabecera


class A03Sonido(Block):
    NUM, TITLE, SUB = "03", "Feedback sonoro", "Sonido al ejecutar el evento."
    HDR_TEST = ("🔊", "Probar sonido", "_test_snd")
    MASTER, MASTER_DEFAULT = ("snd_activo",), "snd_activo"

    def _test_snd(self):
        c = self.ctx
        c.bridge.send("TEST_SND", c.get("snd_tipo"), c.get("snd_vol"), c.event_id)

    def build(self, p):
        _cols(p, (1,))
        fr = ctk.CTkFrame(p, fg_color="transparent")
        fr.grid(row=0, column=0, sticky="ew")

        ca = ctk.CTkFrame(fr, fg_color="transparent")
        ca.pack(side="left", padx=(0, 36))
        lbl(ca, "Ámbito", 11, T.TXT2).pack(side="left", padx=(0, 8))
        self.f_menu(ca, "snd_ambito", [("Global", "global"), ("Este evento", "este_evento")], 110).pack(side="left")

        cs = ctk.CTkFrame(fr, fg_color="transparent")
        cs.pack(side="left", padx=(0, 36))
        lbl(cs, "Sonido", 11, T.TXT2).pack(side="left", padx=(0, 8))
        self.f_menu(cs, "snd_tipo", [("Clic suave", "suave"), ("Clic", "clic"), ("Beep", "beep"), ("Silencio", "mute")], 106).pack(side="left")

        vol = ctk.CTkFrame(fr, fg_color="transparent")
        vol.pack(side="left")
        lbl(vol, "Volumen", 11, T.TXT2).pack(side="left", padx=(0, 8))
        self.vv = tk.IntVar(value=60)
        self.vl = lbl(vol, "60 %", 11, T.TXT, width=38)
        sl = ctk.CTkSlider(vol, from_=0, to=100, number_of_steps=100, variable=self.vv, width=96,
                           progress_color=T.PRIMARY, button_color=T.PRIMARY, button_hover_color=T.PRIMARY_HOVER,
                           fg_color="#E3DFEC", command=self._vol)
        sl.pack(side="left")
        self.vl.pack(side="left", padx=(8, 0))
        self._loaders.append(lambda: (self.vv.set(self.ctx.get("snd_vol")), self.vl.configure(text=f"{self.vv.get()} %")))

    def _vol(self, v):
        self.vl.configure(text=f"{int(v)} %")
        self._commit("snd_vol", int(v))


# ═══ B · Particularidades ═══════════════════════════════════════════════════
class B01Presencia(Block):
    NUM, TITLE, SUB = "01", "Presencia y Superficie", "Píldora táctil en pantalla: nombre visible, tamaño e icono."
    MASTER, MASTER_DEFAULT = ("pildora",), "pildora"
    PILDORA_MODOS = [("Autoajuste", "auto"), ("Manual", "manual")]

    def build(self, p):
        p.grid_columnconfigure(0, weight=1)
        # Fila única: 4 celdas con huecos iguales y elásticos
        f1 = EvenRow(p, min_gap=10)
        f1.grid(row=0, column=0, sticky="ew")

        c0 = ctk.CTkFrame(f1, fg_color="transparent")
        self.f_check(c0, "pildora", "Píldora").pack(side="left")
        f1.add(c0)

        c1 = ctk.CTkFrame(f1, fg_color="transparent")
        lbl(c1, "Nombrar:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_entry(c1, "pildora_nombre", 70, "Ej: Hc").pack(side="left")
        f1.add(c1)

        c2 = ctk.CTkFrame(f1, fg_color="transparent")
        lbl(c2, "Tamaño:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_menu(c2, "pildora_modo_tam", self.PILDORA_MODOS, 105).pack(side="left")
        f1.add(c2)

        c3 = ctk.CTkFrame(f1, fg_color="transparent")
        lbl(c3, "Icono:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        btn(c3, "📁", self._importar_icono, width=28, height=24).pack(side="left", padx=(0, 6))
        self._ico_lbl = lbl(c3, "Sin icono", 11, T.TXT3)
        self._ico_lbl.pack(side="left")
        f1.add(c3)

        self._loaders.append(self._refrescar_icono)

    def _importar_icono(self):
        from tkinter import filedialog
        ruta = filedialog.askopenfilename(
            title="Importar icono de la píldora",
            filetypes=[("Imágenes", "*.png *.ico *.jpg *.jpeg *.webp"), ("Todos", "*.*")])
        if ruta:
            self._commit("pildora_icono", ruta)
            self._refrescar_icono()

    def _refrescar_icono(self):
        import os
        ruta = str(self.ctx.get("pildora_icono") or "")
        self._ico_lbl.configure(text=os.path.basename(ruta) if ruta else "Sin icono")

    def _tam(self, parent):
        items = list(PILDORA_TAMS.items())
        w = combo(parent, [k for k, _ in items], width=110, command=lambda lab: self._commit("pildora_tam", PILDORA_TAMS.get(lab, 100)) if lab in PILDORA_TAMS else None)

        def load():
            v = int(self.ctx.get("pildora_tam"))
            lab = next((k for k, px in items if px == v), f"Otro ({v} px)")
            w.configure(values=[k for k, _ in items] + ([lab] if lab not in PILDORA_TAMS else []))
            w.set(lab)
        self._loaders.append(load)
        return w


class B02Disparador(Block):
    NUM, TITLE, SUB = "02", "Disparador Espacial", "Activación geométrica por paso del lápiz, autoclick y remapeo de atajo."
    MASTER, MASTER_DEFAULT = ("cruzar", "auto"), "cruzar"

    def build(self, p):
        p.grid_columnconfigure(0, weight=1)
        # Fila única: 3 celdas con huecos iguales y elásticos
        fr = EvenRow(p, min_gap=12)
        fr.grid(row=0, column=0, sticky="ew")

        g0 = ctk.CTkFrame(fr, fg_color="transparent")
        btn(g0, "✎  Dibujar zona",
            lambda: self.ctx.bridge.send("CAL_ZONE", self.ctx.event_id, "panel", "cruzar" if self.ctx.get("cruzar") else "auto"),
            height=26, width=120).pack(side="left")
        fr.add(g0)

        g1 = ctk.CTkFrame(fr, fg_color="transparent")
        self.f_check(g1, "auto", "Paso → Autoclick").pack(side="left")
        fr.add(g1)

        g2 = ctk.CTkFrame(fr, fg_color="transparent")
        self.f_check(g2, "cruzar", "Paso → Atajo CSP").pack(side="left", padx=(0, 6))
        c_cz, e_cz = self.f_key_entry(g2, "atajo", 90, on_clear=lambda: self._reset("atajo", e_cz))
        c_cz.pack(side="left")
        fr.add(g2)

    def after_change(self, name):
        if name == "cruzar" and self.ctx.get("cruzar") and self.ctx.get("auto"):
            self.ctx.set("auto", 0)                         # exclusión mutua cruzar ⇄ auto
        elif name == "auto" and self.ctx.get("auto") and self.ctx.get("cruzar"):
            self.ctx.set("cruzar", 0)
        self.ctx.refresh_all()


class B03Modulacion(Block):
    NUM, TITLE, SUB = "03", "Modulación de Tecla", "Pulsación rápida (toque corto/largo) y alternancia bi-estado A ⇄ B."
    MASTER, MASTER_DEFAULT = ("quick", "toggle"), "quick"

    def build(self, p):
        p.grid_columnconfigure(0, weight=1)
        p.grid_columnconfigure(1, weight=1)

        # ── Columna Izquierda: Pulsación rápida ──
        a = ctk.CTkFrame(p, fg_color="transparent")
        a.grid(row=0, column=0, sticky="nsew", padx=(0, 12))

        # 1) Renglón A/B: fija la referencia de ancho de la columna.
        ra2 = ctk.CTkFrame(a, fg_color="transparent")
        ra2.grid(row=1, column=0, sticky="w")
        lbl(ra2, "A:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        c_qa, _ = self.f_key_entry(ra2, "quick_a", 90)
        c_qa.pack(side="left", padx=(0, 8))
        lbl(ra2, "B:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        c_qb, e_qb = self.f_key_entry(ra2, "quick_b", 90)
        c_qb.pack(side="left")

        # 2) Renglón del umbral: «ms» va DENTRO de la caja y el borde derecho de
        #    la caja queda alineado con el de la caja B de abajo (hueco elástico).
        ra1 = ctk.CTkFrame(a, fg_color="transparent")
        ra1.grid(row=0, column=0, sticky="w", pady=(0, 4))
        chk = self.f_check(ra1, "quick", "Pulsación rápida")
        chk.pack(side="left")
        self._gap = ctk.CTkFrame(ra1, fg_color="transparent", width=8, height=1)
        self._gap.pack(side="left")
        mun = ctk.CTkFrame(ra1, fg_color="transparent")
        mun.pack(side="left")
        lbl(mun, "Umbral:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_stepper_default(mun, "quick_ms", 50, 48).pack(side="left")
        # «ms» fuera del grupo alineado: la caja termina en la vertical de la caja B
        # y el sufijo cuelga a la derecha de esa línea.
        lbl(ra1, "ms", 9, T.TXT2).pack(side="left", padx=(4, 0))

        def _alinear(*_):
            try:
                wb = e_qb.winfo_width()
                if wb <= 20:                                    # aún sin geometría
                    a.after(60, _alinear)
                    return
                x_b = c_qb.winfo_x() + wb                       # borde der. de la caja B (px)
                hueco = x_b - chk.winfo_reqwidth() - mun.winfo_reqwidth()
                self._gap.configure(width=self._reverse_widget_scaling(max(4, hueco)))
            except Exception:
                pass
        a.bind("<Configure>", _alinear, add="+")
        self.after(60, _alinear)
        self._loaders.append(lambda: a.after_idle(_alinear))

        # Columna Derecha: Alternador A ⇄ B
        b = ctk.CTkFrame(p, fg_color="transparent")
        b.grid(row=0, column=1, sticky="nsew")
        rb1 = ctk.CTkFrame(b, fg_color="transparent")
        rb1.pack(fill="x", pady=(0, 4))
        self.f_check(rb1, "toggle", "Alternador A ⇄ B").pack(side="left", padx=(0, 10))
        lbl(rb1, "Bi-estado cíclico", 10, T.TXT3).pack(side="left")

        rb2 = ctk.CTkFrame(b, fg_color="transparent")
        rb2.pack(fill="x")
        lbl(rb2, "A:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        c_ta, _ = self.f_key_entry(rb2, "toggle_a", 90)
        c_ta.pack(side="left", padx=(0, 8))
        lbl(rb2, "B:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        c_tb, _ = self.f_key_entry(rb2, "toggle_b", 90)
        c_tb.pack(side="left")
        self.warn = lbl(rb2, "", 10, T.WARN)
        self.warn.pack(side="left", padx=(6, 0))
        self._loaders.append(self._warn)

    def _warn(self):
        bad = self.ctx.get("toggle") and not str(self.ctx.get("toggle_b")).strip()
        self.warn.configure(text="⚠ Requiere Tecla B" if bad else "")

    def after_change(self, name):
        super().after_change(name)
        if self._built:
            self._warn()


class B04Deslizador(Block):
    NUM, TITLE, SUB, CAP = "04", "Deslizador Virtual", "Control analógico continuo, escalonamiento por pasos y puntos Snap (P1-P5).", "slider"

    def build(self, p):
        p.grid_columnconfigure(0, weight=1)
        p.grid_columnconfigure(1, weight=0)

        left = ctk.CTkFrame(p, fg_color="transparent")
        left.grid(row=0, column=0, sticky="ew")

        # Fila 1: Teclas de paso y límites
        f1 = ctk.CTkFrame(left, fg_color="transparent")
        f1.pack(fill="x", pady=(0, 4))
        lbl(f1, "Teclas de paso:", 11, T.TXT2).pack(side="left", padx=(0, 8))
        lbl(f1, "Bajar (A):", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_entry(f1, "sl_tecla_bajar", 44).pack(side="left", padx=(0, 10))
        lbl(f1, "Subir (B):", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_entry(f1, "sl_tecla_subir", 44).pack(side="left", padx=(0, 12))
        lbl(f1, "Mín (%):", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_entry(f1, "sl_rmin", 40).pack(side="left", padx=(0, 10))
        lbl(f1, "Máx (%):", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_entry(f1, "sl_rmax", 40).pack(side="left")

        # Fila 2: Snaps
        f2 = ctk.CTkFrame(left, fg_color="transparent")
        f2.pack(fill="x")
        lbl(f2, "Snap P1 → P5 (%):", 11, T.TXT2).pack(side="left", padx=(0, 8))
        for i in range(1, 6):
            self.f_entry(f2, f"sl_snap_{i}", 36).pack(side="left", padx=(0, 4))

        # Columna Derecha: Botones de dibujo apilados
        right = ctk.CTkFrame(p, fg_color="transparent")
        right.grid(row=0, column=1, sticky="e", padx=(12, 0))
        btn(right, "✎  Dibujar deslizador", self._draw_slider, height=26).pack(fill="x", pady=(0, 4))
        btn(right, "✎  Dibujar enfoque", self._draw_focus, height=26).pack(fill="x")

    def _draw_slider(self):
        self.ctx.bridge.send("DRAW_SLIDER", "normal")

    def _draw_focus(self):
        self.ctx.bridge.send("DRAW_SLIDER", "enfoque")

    def pre_validate(self, name, value):
        try:
            v = int(str(value))
        except ValueError:
            return "num"
        if name == "sl_rmin" and v > int(self.ctx.get("sl_rmax")):
            return "min>max"
        if name == "sl_rmax" and v < int(self.ctx.get("sl_rmin")):
            return "max<min"
        return None


class B05Ventanas(Block):
    NUM, TITLE, SUB = "05", "Nuevas Ventanas y Lienzos", "Visibilidad dinámica de sub-lienzos, opacidad en reposo/hover y encuadre."
    MASTER, MASTER_DEFAULT = ("nv_lienzos", "hover"), "nv_lienzos"

    def build(self, p):
        p.grid_columnconfigure(0, weight=1)
        r = ctk.CTkFrame(p, fg_color="transparent")
        r.grid(row=0, column=0, sticky="ew")
        lbl(r, "Zona:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_menu(r, "nv_visibles", [("Todas", "Todas")], 100).pack(side="left", padx=(0, 14))
        lbl(r, "OPC Hover:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_stepper(r, "nv_opc_hover", 5, 38, "%").pack(side="left", padx=(0, 14))
        lbl(r, "OPC Desactivado:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_stepper(r, "nv_opc_off", 5, 38, "%").pack(side="left", padx=(0, 14))
        self.f_check(r, "nv_lienzos", "Lienzos").pack(side="left")

        r2 = ctk.CTkFrame(p, fg_color="transparent")
        r2.grid(row=1, column=0, sticky="ew", pady=(6, 0))
        self.f_check(r2, "hover", "Hover por rango").pack(side="left", padx=(0, 16))
        lbl(r2, "Reposo:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_stepper(r2, "hover_rep", 1, 38, "%").pack(side="left", padx=(0, 16))
        lbl(r2, "Activa:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        self.f_stepper(r2, "hover_act", 1, 38, "%").pack(side="left", padx=(0, 16))
        lbl(r2, "Borde:", 11, T.TXT2).pack(side="left", padx=(0, 6))
        self.f_switch(r2, "hover_borde").pack(side="left")


GROUP_A = (A01Base, A02Hud, A03Sonido)
GROUP_B = (B01Presencia, B02Disparador, B03Modulacion, B04Deslizador, B05Ventanas)
