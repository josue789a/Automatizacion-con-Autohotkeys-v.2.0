"""Widgets reutilizables con el estilo del mockup."""
from __future__ import annotations
import tkinter as tk
from tkinter import colorchooser
import customtkinter as ctk
from . import theme as T

PEN_GRACIA_MS = 1500   # tras un RButton solo, tiempo para pulsar la tecla del acorde
PEN_LATCH_MS = 4000    # tras tocar el botón RB de la UI


def lbl(parent, text="", size=12, color=T.TXT, bold=False, wrap=0, anchor="w", **kw):
    kw.setdefault("height", 0)
    return ctk.CTkLabel(parent, text=text, font=T.font(size, bold), text_color=color,
                        anchor=anchor, justify="left", wraplength=wrap, **kw)


def ellipsize(text: str, font_obj, max_px: int) -> str:
    if font_obj.measure(text) <= max_px:
        return text
    while text and font_obj.measure(text + "…") > max_px:
        text = text[:-1]
    return text.rstrip() + "…"


def btn(parent, text, command, primary=False, width=0, height=28, **kw):
    if primary:
        return ctk.CTkButton(parent, text=text, command=command, width=width, height=height, corner_radius=14,
                             fg_color=T.PRIMARY, hover_color=T.PRIMARY_HOVER, text_color="white",
                             font=T.font(11, True), **kw)
    return ctk.CTkButton(parent, text=text, command=command, width=width, height=height, corner_radius=14,
                         fg_color="#F8F6FD", hover_color=T.SOFT, text_color=T.PRIMARY, border_width=1,
                         border_color="#D8D2E7", font=T.font(11, True), **kw)


def check(parent, text, variable, command=None):
    return ctk.CTkCheckBox(parent, text=text, variable=variable, command=command, font=T.font(12, False),
                           text_color=T.TXT, fg_color=T.PRIMARY, hover_color=T.PRIMARY_HOVER, border_color="#C7C0D8",
                           checkmark_color="white", checkbox_width=18, checkbox_height=18, corner_radius=5,
                           border_width=2)


def combo(parent, values, command=None, width=130):
    return ctk.CTkComboBox(parent, values=list(values), command=command, width=width, height=28, state="readonly",
                           font=T.font(11), dropdown_font=T.font(11), fg_color="#FAF9FD", border_color="#D8D2E7",
                           border_width=1, button_color="#F1EDF8", button_hover_color=T.SOFT_HOVER,
                           text_color=T.TXT, dropdown_fg_color=T.CARD, dropdown_hover_color=T.SOFT,
                           dropdown_text_color=T.TXT, corner_radius=14)


KEY_W = 90    # ancho estándar de las cajas de atajo (f_key_entry)
KEY_H = 24    # alto estándar: Entry y dúo ✓/✕ (si el dúo queda 1 px distinto, cambiar SOLO esto a 25 o 26)


def rb_button(parent, host, width=22, height=KEY_H):
    """Botón compacto 'RB': un toque con la punta arma RButton como prefijo del acorde."""
    color = "#6B6585"
    lb = ctk.CTkLabel(parent, text="RB", text_color=color, font=T.font(9, True),
                      fg_color="transparent", corner_radius=2, width=width, height=height)

    def _go(_e=None):
        fn = getattr(host, "_kc_rbutton", None)
        if fn:
            fn()

    lb.bind("<Enter>", lambda _e: lb.configure(fg_color=T.SOFT, text_color="#1F1B2E"))
    lb.bind("<Leave>", lambda _e: lb.configure(fg_color="transparent", text_color=color))
    lb.bind("<Button-1>", _go)
    try:
        lb.configure(cursor="hand2")
    except Exception:
        pass
    return lb


def duo_ok_clear(parent, on_ok, on_clear, width=16, height=KEY_H):
    """Dúo ✓/✕ apilado, sin márgenes internos. Cada mitad ocupa relheight=0.5,
    por lo que el alto total == height y calza con el Entry en cualquier escala DPI."""
    box = ctk.CTkFrame(parent, fg_color="transparent", width=width, height=height, corner_radius=0)
    box.pack_propagate(False)

    CLR_OK = "#28233C"    # Negro carbón nítido (afirmación / guardar)
    CLR_DEL = "#958FA8"   # Gris medio atenuado (secundario / limpiar)

    def _mk(txt, color, cmd, rely):
        lb = ctk.CTkLabel(box, text=txt, text_color=color, font=T.font(9, True),
                          fg_color="transparent", corner_radius=2, height=1)
        lb.place(relx=0, rely=rely, relwidth=1.0, relheight=0.5)
        lb.bind("<Enter>", lambda _e: lb.configure(fg_color=T.SOFT, text_color="#1F1B2E"))
        lb.bind("<Leave>", lambda _e: lb.configure(fg_color="transparent", text_color=color))
        lb.bind("<Button-1>", lambda _e: cmd())
        try:
            lb.configure(cursor="hand2")
        except Exception:
            pass
        return lb

    _mk("✓", CLR_OK, on_ok, 0.0)
    _mk("✕", CLR_DEL, on_clear, 0.5)
    return box


class KeyHistory:
    """Historial LIFO en memoria de sesión para un campo de tecla (Undo + lista)."""
    MAX = 20

    def __init__(self, get_value, set_value):
        self._get = get_value
        self._set = set_value
        self._busy = False
        self._stack = []
        self.seed()

    def _safe_get(self):
        try:
            return self._get()
        except Exception:
            return ""

    def seed(self):
        self._stack = [self._safe_get()]

    def push(self):
        if self._busy:
            return
        v = self._safe_get()
        if not self._stack or self._stack[-1] != v:
            self._stack.append(v)
            del self._stack[:-self.MAX]

    def can_undo(self):
        return len(self._stack) > 1

    def undo(self):
        if not self.can_undo():
            return None
        self._stack.pop()
        v = self._stack[-1]
        self.apply(v, record=False)
        return v

    def items(self):
        seen, out = set(), []
        for v in reversed(self._stack):
            if v and v not in seen:
                seen.add(v)
                out.append(v)
        return out

    def apply(self, value, record=True):
        self._busy = not record
        try:
            self._set(value)
        finally:
            self._busy = False

    def history_tuple(self):
        prev = self._stack[-2] if len(self._stack) > 1 else ""
        return (prev, self.items())


def entry(parent, width=140, placeholder=""):
    return ctk.CTkEntry(parent, width=width, height=KEY_H, font=T.font(11), fg_color="#FAF9FD", text_color=T.TXT,
                        border_color="#D8D2E7", border_width=1, corner_radius=4,
                        placeholder_text=placeholder, placeholder_text_color=T.TXT3)


def switch(parent, variable, command=None):
    return ctk.CTkSwitch(parent, text="", variable=variable, command=command, width=38, switch_width=36,
                         switch_height=20, progress_color=T.PRIMARY, button_color="white",
                         button_hover_color="#F4F4F8", fg_color="#D8D2E7")


class Hint(ctk.CTkLabel):
    """Texto gris de ayuda que ajusta su wraplength al ancho real del contenedor."""
    def __init__(self, parent, text, size=10, color=T.TXT2):
        super().__init__(parent, text=text, font=T.font(size), text_color=color, anchor="w",
                         justify="left", wraplength=180, height=0)
        self._job = None
        parent.bind("<Configure>", self._sched, add="+")

    def _sched(self, _e=None):
        if self._job:
            self.after_cancel(self._job)
        self._job = self.after(60, self._fit)

    def _fit(self):
        self._job = None
        try:
            w = self.master.winfo_width()
            w = self.master._reverse_widget_scaling(w)
            self.configure(wraplength=max(120, int(w) - 28))
        except Exception:
            pass


class Stepper(ctk.CTkFrame):
    """Spinbox vertical compacto: [valor] [sufijo] [▴/▾] estilo caja casi cuadrada.

    El sufijo (p. ej. «ms») se dibuja **dentro** del marco: el borde derecho de
    la caja es también el final del grupo, así puede alinearse con otras cajas
    de la misma columna sin que el texto se salga de la línea.

    Modo «valor de fábrica»: `set_default()` muestra el número en gris (sin
    valor propio); `set()` lo muestra en negro (asignado a mano).
    """
    def __init__(self, parent, lo, hi, step=1, width=38, on_commit=None, suffix=""):
        super().__init__(parent, fg_color="#FAF9FD", corner_radius=4, border_width=1, border_color="#D8D2E7", height=24)
        self.lo, self.hi, self.step, self.on_commit = lo, hi, step, on_commit
        self.fallback = None            # valor de fábrica (se pinta en gris)
        self._factory = False
        self._v = tk.StringVar(value=str(lo))

        sfx_w = 14 if suffix else 0
        # Entry sin relleno interno: CTkEntry reserva >= 6 px por lado y recortaba el "100"
        ent_w = max(26, width - 12 - sfx_w)
        self.ent = ctk.CTkEntry(self, width=ent_w, height=20, textvariable=self._v, justify="center",
                                font=T.font_cap(11), fg_color="transparent", border_width=0,
                                corner_radius=0, text_color=T.TXT)
        try:
            self.ent._entry.grid_configure(padx=1)
        except Exception:
            pass
        self.ent.pack(side="left", padx=(1, 0), pady=1)

        if suffix:
            ctk.CTkLabel(self, text=suffix, width=sfx_w, font=T.font(9),
                         text_color=T.TXT2, height=1).pack(side="left")

        # Micro-muescas: mismo tamaño y vector, espejadas respecto al eje y=7 (14 - y)
        cv = tk.Canvas(self, width=9, height=14, bg="#FAF9FD", highlightthickness=0, bd=0, cursor="hand2")
        cv.pack(side="left", padx=(0, 2))

        p_up = cv.create_polygon(0.5, 6, 7.5, 6, 4.0, 2, fill=T.PRIMARY, outline=T.PRIMARY, width=1)
        p_dn = cv.create_polygon(0.5, 8, 7.5, 8, 4.0, 12, fill=T.PRIMARY, outline=T.PRIMARY, width=1)

        def _paint(item, color):
            cv.itemconfig(item, fill=color, outline=color)

        def _motion(ev):
            _paint(p_up, T.PRIMARY_HOVER if ev.y < 7 else T.PRIMARY)
            _paint(p_dn, T.PRIMARY if ev.y < 7 else T.PRIMARY_HOVER)

        def _leave(_ev):
            _paint(p_up, T.PRIMARY)
            _paint(p_dn, T.PRIMARY)

        def _click(ev):
            self._bump(self.step if ev.y < 7 else -self.step)

        cv.bind("<Motion>", _motion)
        cv.bind("<Leave>", _leave)
        cv.bind("<Button-1>", _click)

        self.ent.bind("<Return>", self._commit)
        self.ent.bind("<FocusOut>", self._commit)
        self.ent.bind("<FocusIn>", self._focus_in)
        self.ent.bind("<KeyRelease>", self._typed)

    def set(self, value):
        """Valor propio (negro)."""
        self._factory, self.fallback = False, None
        self._v.set("" if value is None else str(value))
        self.ent.configure(text_color=T.TXT)
        self.configure(border_color="#D8D2E7")

    def set_default(self, texto):
        """Sin valor propio: muestra el valor de fábrica en gris."""
        try:
            self.fallback = int(str(texto).strip())
        except (TypeError, ValueError):
            self.fallback = None
        self._factory = True
        self._v.set("" if texto is None else str(texto))
        self.ent.configure(text_color=T.TXT3)
        self.configure(border_color="#D8D2E7")

    def _value(self):
        try:
            return int(self._v.get())
        except ValueError:
            return self.fallback if self.fallback is not None else self.lo

    def _focus_in(self, _e=None):
        # En modo fábrica el texto se selecciona para que escribir lo reemplace
        if self._factory:
            try:
                self.ent._entry.selection_range(0, "end")
            except Exception:
                pass

    def _typed(self, _e=None):
        if self._factory and self._value() != self.fallback:
            self._factory = False
            self.ent.configure(text_color=T.TXT)

    def _bump(self, d):
        cur = self._value()
        self._factory = False
        self.ent.configure(text_color=T.TXT)
        self._v.set(str(max(self.lo, min(self.hi, cur + d))))
        self._commit()

    def _commit(self, _e=None):
        if self._factory and self._value() == self.fallback:
            self.ent.configure(text_color=T.TXT3)
        ok = self.on_commit(self._v.get()) if self.on_commit else True
        self.configure(border_color="#D8D2E7" if ok else T.DANGER)


class ColorChip(ctk.CTkFrame):
    def __init__(self, parent, on_pick):
        super().__init__(parent, fg_color="transparent")
        self.on_pick, self.hex = on_pick, "7863A6"
        self.sw = ctk.CTkButton(self, text="", width=34, height=26, corner_radius=7, border_width=1,
                                border_color=T.FIELD_BORDER, command=self._ask)
        self.sw.grid(row=0, column=0)
        self.tx = lbl(self, "#7863A6", 12)
        self.tx.grid(row=0, column=1, padx=(8, 0))

    def set(self, hexv: str):
        self.hex = hexv
        self.sw.configure(fg_color=f"#{hexv}", hover_color=f"#{hexv}")
        self.tx.configure(text=f"#{hexv}")

    def _ask(self):
        rgb, hx = colorchooser.askcolor(color=f"#{self.hex}", parent=self.winfo_toplevel())
        if hx and self.on_pick(hx.lstrip("#").upper()):
            self.set(hx.lstrip("#").upper())


# ══════════════════════════════════════════════════════════════════════
#  Motor de flujo elástico + captura de teclas + icono compacto
# ══════════════════════════════════════════════════════════════════════
import tkinter as tk
import customtkinter as ctk
from . import theme as _T

FLOW_SEP_X, FLOW_SEP_Y = 8, 6
FLOW_MIN_SHRINK = 0.70        # un control elástico encoge hasta el 70 %
FLOW_GROW_CAP = 1.6           # tope de crecimiento SOLO para ítems con grow=True (ej. slider de volumen)
FLOW_MAX_GROW = 1.45          # y crece hasta el 145 % (slider: 2.2)
FLOW_MAX_GAP_EXTRA = 24       # px lógicos extra entre elementos al sobrar sitio
AUTOSCALE_ON = True
AUTOSCALE_REF_W = 940         # px lógicos: por debajo se reduce la escala
AUTOSCALE_MIN = 0.80

_ELASTIC = (ctk.CTkEntry, ctk.CTkComboBox, ctk.CTkOptionMenu, ctk.CTkSlider)


def _scale_of(w):
    try:
        return float(ctk.ScalingTracker.get_widget_scaling(w))
    except Exception:
        return 1.0


def _find_elastic(w):
    if isinstance(w, _ELASTIC):
        return w
    for ch in w.winfo_children():
        r = _find_elastic(ch)
        if r is not None:
            return r
    return None


def _as_queue(top, e):
    if e is not None and e.widget is not top:
        return
    st = top._xp_as
    if st["job"]:
        try:
            top.after_cancel(st["job"])
        except Exception:
            pass
    st["job"] = top.after(220, lambda: _as_apply(top))


def _as_apply(top):
    st = top._xp_as
    st["job"] = None
    try:
        if top.state() == "iconic":
            return
        wl = top.winfo_width() / max(0.5, ctk.ScalingTracker.get_window_scaling(top))
    except Exception:
        return
    s = 1.0 if wl >= AUTOSCALE_REF_W else max(AUTOSCALE_MIN, wl / AUTOSCALE_REF_W)
    s = round(s * 20) / 20
    if abs(s - st["cur"]) < 0.001:
        return
    st["cur"] = s
    ctk.set_widget_scaling(s)


class FlowRow(ctk.CTkFrame):
    """Flujo elástico: mantiene filas horizontales encogiendo/estirando los
    controles elásticos antes de partir fila. API compatible: add(w)."""

    def __init__(self, master, *a, **kw):
        self._sx = kw.pop("sep_x", kw.pop("sep", FLOW_SEP_X))
        self._sy = kw.pop("sep_y", kw.pop("row_gap", FLOW_SEP_Y))
        kw.pop("gap", None)
        kw.pop("pad", None)
        kw.setdefault("fg_color", "transparent")
        super().__init__(master, *a, **kw)
        self._its, self._avail, self._job, self._sig = [], -1, None, None
        self.bind("<Configure>", self._on_cfg, add="+")
        self.after(80, self._hook_scale)

    # ── API pública ──
    def add(self, w, grow=False, **_):
        self._its.append({"w": w, "el": None, "n": 0, "h": 0, "ln": 0, "cap": FLOW_MAX_GROW, "grow": grow})
        self._sig = None
        self._queue()
        return w

    def clear(self):
        self._its.clear()
        self._sig = None

    def reflow(self):
        self._sig = None
        self._queue()

    # ── interno ──
    def _hook_scale(self):
        if not AUTOSCALE_ON or not self.winfo_exists():
            return
        top = self.winfo_toplevel()
        if getattr(top, "_xp_as", None):
            return
        top._xp_as = {"job": None, "cur": 1.0}
        top.bind("<Configure>", lambda e, t=top: _as_queue(t, e), add="+")
        _as_queue(top, None)

    def _on_cfg(self, e):
        if e.width != self._avail:
            self._queue()

    def _queue(self):
        if self._job is None:
            self._job = self.after_idle(self._layout)

    def _measure(self, its, sc):
        for i in its:
            if i["el"] is None:
                i["el"] = _find_elastic(i["w"]) or False
                if i["el"]:
                    i["ln"] = int(i["el"].cget("width"))
                    if isinstance(i["el"], ctk.CTkSlider):
                        i["cap"] = 2.2
            if i["el"]:
                i["el"].configure(width=i["ln"])
        self.update_idletasks()
        for i in its:
            i["n"] = i["w"].winfo_reqwidth()
            i["h"] = i["w"].winfo_reqheight()

    def _layout(self):
        self._job = None
        if not self.winfo_exists():
            return
        avail = self.winfo_width()
        if avail < 60:
            return
        self._avail = avail
        its = [i for i in self._its if i["w"].winfo_exists()]
        if not its:
            return
        sc = _scale_of(self)
        if self._sig != sc or any(i["n"] == 0 for i in its):
            self._measure(its, sc)
            self._sig = sc
        sx, sy = int(self._sx * sc), int(self._sy * sc)

        def lo(i):
            return i["n"] - int(i["ln"] * sc * (1 - FLOW_MIN_SHRINK)) if i["el"] else i["n"]

        rows, cur, used_min = [], [], 0
        for i in its:
            add_m = lo(i) + (sx if cur else 0)
            if cur and used_min + add_m > avail:
                rows.append(cur)
                cur, used_min = [i], lo(i)
            else:
                cur.append(i)
                used_min += add_m
        if cur:
            rows.append(cur)

        y = 0
        for row in rows:
            n = len(row)
            ws = [i["n"] for i in row]
            diff = avail - (sum(ws) + sx * (n - 1))
            els = [k for k, i in enumerate(row) if i["el"]]
            if diff < 0:
                pool = sum(row[k]["ln"] for k in els) or 1
            else:
                pool = sum(row[k]["ln"] for k in els if row[k].get("grow")) or 1
            for k in els:
                i = row[k]
                if diff < 0:
                    share = int(diff * i["ln"] / pool)
                    share = max(share, -int(i["ln"] * sc * (1 - FLOW_MIN_SHRINK)))
                elif diff > 0 and i.get("grow"):
                    share = int(diff * i["ln"] / pool)
                    share = min(share, int(i["ln"] * sc * (FLOW_GROW_CAP - 1)))
                else:
                    share = 0   # ancho natural: nunca se infla por sobrar espacio
                ws[k] = i["n"] + share
                new_w = max(40, round(i["ln"] + share / sc))
                if i.get("cw") != new_w:      # restaura el ancho natural tras un encogimiento previo
                    i["el"].configure(width=new_w)
                    i["cw"] = new_w
            gap = sx                           # gap fijo, sin dispersión
            rh = max(i["h"] for i in row)
            x = 0
            for k, i in enumerate(row):
                i["w"].place(x=int(x), y=y + (rh - i["h"]) // 2)
                x += ws[k] + gap
            y += rh + sy
        self.configure(height=max(1, int((y - sy) / sc)))


class EvenRow(ctk.CTkFrame):
    """Fila de celdas con huecos iguales y elásticos.

    Uso:
        fr = EvenRow(parent, min_gap=10)
        fr.grid(row=0, column=0, sticky="ew")
        fr.add(celda1); fr.add(celda2); fr.add(celda3)

    - Con espacio de sobra, **todos** los huecos crecen por igual (weight=1).
    - Con poco espacio, se comprimen hasta `min_gap`.
    - No salta de fila (a diferencia de FlowRow): prioriza comprimir.
    """

    def __init__(self, parent, min_gap=10, **kw):
        kw.setdefault("fg_color", "transparent")
        kw.setdefault("width", 0)
        kw.setdefault("height", 0)
        super().__init__(parent, **kw)
        self.min_gap = max(0, int(min_gap))
        self.cells: list = []

    def add(self, widget):
        self.cells.append(widget)
        self._layout()
        return widget

    def _layout(self):
        n = len(self.cells)
        for i, w in enumerate(self.cells):
            w.grid(row=0, column=2 * i, sticky="w")
            self.grid_columnconfigure(2 * i, weight=0, minsize=0)
        for i in range(n - 1):
            self.grid_columnconfigure(2 * i + 1, weight=1, minsize=self.min_gap)
        self.grid_rowconfigure(0, weight=0)


# ── Icono compacto (cabeceras de bloque) ──
def _tooltip(w, text):
    st = {"t": None, "j": None}

    def show():
        st["j"] = None
        if st["t"] or not w.winfo_exists():
            return
        t = tk.Toplevel(w)
        t.wm_overrideredirect(True)
        t.attributes("-topmost", True)
        tk.Label(t, text=text, bg="#1F2430", fg="#FFFFFF", padx=8, pady=3,
                 font=("Segoe UI", 9)).pack()
        t.geometry(f"+{w.winfo_rootx()}+{w.winfo_rooty() + w.winfo_height() + 4}")
        st["t"] = t

    def hide(*_):
        if st["j"]:
            w.after_cancel(st["j"])
            st["j"] = None
        if st["t"]:
            st["t"].destroy()
            st["t"] = None

    w.bind("<Enter>", lambda e: st.__setitem__("j", w.after(450, show)), add="+")
    w.bind("<Leave>", hide, add="+")
    w.bind("<ButtonPress>", hide, add="+")


def icon_btn(parent, glyph, cmd, size=28, tip=None):
    b = ctk.CTkButton(parent, text=glyph, width=size, height=size, corner_radius=6,
                      fg_color="transparent", hover_color=_T.BORDER, border_width=1,
                      border_color=_T.BORDER, text_color=_T.ACCENT,
                      font=ctk.CTkFont(size=14), command=cmd)
    if tip:
        _tooltip(b, tip)
    return b


# ── Captura de teclas directa sobre un Entry ──
_MODS_KS = {"Control_L", "Control_R", "Shift_L", "Shift_R", "Alt_L", "Alt_R", "Meta_L",
            "Meta_R", "Super_L", "Super_R", "Win_L", "Win_R", "Caps_Lock", "Num_Lock",
            "Scroll_Lock", "ISO_Level3_Shift", "Mode_switch"}
_KS_NAMES = {
    "space": "Space", "Return": "Enter", "Escape": "Esc", "Tab": "Tab", "Prior": "PgUp",
    "Next": "PgDn", "Home": "Home", "End": "End", "Insert": "Insert", "Left": "Left",
    "Right": "Right", "Up": "Up", "Down": "Down", "BackSpace": "Backspace",
    "Delete": "Delete", "grave": "`", "minus": "-", "equal": "=", "comma": ",",
    "period": ".", "slash": "/", "backslash": "\\", "semicolon": ";", "apostrophe": "'",
    "bracketleft": "[", "bracketright": "]", "plus": "+", "asterisk": "*", "less": "<",
    "greater": ">", "KP_Home": "NumpadHome", "KP_End": "NumpadEnd",
    "KP_Prior": "NumpadPgUp", "KP_Next": "NumpadPgDn", "KP_Left": "NumpadLeft",
    "KP_Right": "NumpadRight", "KP_Up": "NumpadUp", "KP_Down": "NumpadDown",
    "KP_Delete": "NumpadDel", "KP_Insert": "NumpadIns", "KP_Begin": "NumpadClear",
    "KP_Add": "NumpadAdd", "KP_Subtract": "NumpadSub", "KP_Multiply": "NumpadMult",
    "KP_Divide": "NumpadDiv", "KP_Enter": "NumpadEnter", "KP_Decimal": "NumpadDot",
}


def _key_name(ev):
    ks = ev.keysym
    if ks in _KS_NAMES:
        return _KS_NAMES[ks]
    if ks.startswith("KP_") and ks[3:].isdigit():
        return "Numpad" + ks[3:]
    if len(ks) == 1:
        return ks.upper()
    if ks[0] in "Ff" and ks[1:].isdigit():
        return "F" + ks[1:]
    ch = ev.char
    if ch and ch.isprintable() and not ch.isspace():
        return ch.upper()
    return ks


def _win_down():
    try:
        import ctypes
        u = ctypes.windll.user32
        return bool((u.GetAsyncKeyState(0x5B) | u.GetAsyncKeyState(0x5C)) & 0x8000)
    except Exception:
        return False


def _find_entry(w):
    if isinstance(w, (ctk.CTkEntry, tk.Entry)):
        return w
    try:
        for ch in w.winfo_children():
            r = _find_entry(ch)
            if r is not None:
                return r
    except Exception:
        pass
    return None


_TOK_MODS = (("Ctrl", ("Control_L", "Control_R"), (17, 162, 163)),
             ("Alt", ("Alt_L", "Alt_R"), (18, 164, 165)),
             ("Shift", ("Shift_L", "Shift_R"), (16, 160, 161)),
             ("Win", ("Super_L", "Super_R", "Win_L", "Win_R"), (91, 92)))
_MOD_ORDER = tuple(m[0] for m in _TOK_MODS)

def _tok_de(ev):
    """Token canónico de una tecla: modificador, nombre (VK en letras y dígitos) o ''."""
    if ev.keycode in (0xE8, 232) or ev.keysym in ("??", "vkE8"):
        return ""
    for nom, kss, kcs in _TOK_MODS:
        if ev.keysym in kss or ev.keycode in kcs:
            return nom
    if ev.keysym in _MODS_KS:
        return ""
    if 48 <= ev.keycode <= 57 or 65 <= ev.keycode <= 90:
        return chr(ev.keycode)
    return _key_name(ev)

def _acorde_txt(pico):
    mods = [m for m in _MOD_ORDER if m in pico]
    rb = ["RButton"] if "RButton" in pico else []
    resto = [t for t in pico if t not in _MOD_ORDER and t != "RButton"]
    return "+".join(mods + rb + resto)

_CAP = {"send": None}

def set_captura_bridge(send):
    """app.py registra aquí ctx.bridge.send; sin registro, el puente queda inerte."""
    _CAP["send"] = send

def _cap_send(cmd):
    fn = _CAP["send"]
    if fn is not None:
        try:
            fn(cmd)
        except Exception:
            pass


def attach_keycapture(host, on_clear=None, on_commit=None, get_history=None):
    """El Entry captura combinaciones (Ctrl+Alt+Shift+Win + tecla).
    Supr/Retroceso solos = on_clear(). Doble clic = escritura manual."""
    ent = _find_entry(host)
    if ent is None:
        return None
    inner = getattr(ent, "_entry", ent)
    st = {"manual": False, "down": set(), "pico": [], "cerrado": True,
          "job": None, "armed": False, "beat": None}
    orig = None
    if isinstance(ent, ctk.CTkEntry):
        try:
            orig = ent.cget("border_color")
        except Exception:
            orig = None

    def accent(on):
        try:
            if on:
                ent.configure(border_color=_T.ACCENT)
            elif hasattr(host, "_apply_style"):
                pass  # Conserva el estilo blindado del host
            elif orig is not None:
                ent.configure(border_color=orig)
        except Exception:
            pass

    def put(txt):
        ent.delete(0, "end")
        ent.insert(0, txt)

    def cancel_job():
        if st["job"] is not None:
            try:
                inner.after_cancel(st["job"])
            except Exception:
                pass
            st["job"] = None

    def reset_state():
        cancel_job()
        st["down"].clear()
        st["pico"].clear()
        st["cerrado"] = True

    def press(tok):
        cancel_job()
        if st["cerrado"]:
            st["pico"].clear()
            st["cerrado"] = False
        st["down"].add(tok)
        if tok not in st["pico"]:
            st["pico"].append(tok)
        put(_acorde_txt(st["pico"]))

    def release(tok):
        st["down"].discard(tok)
        if not st["down"]:
            cancel_job()
            _gracia = st.pop("gracia_once", None) or (PEN_GRACIA_MS if st["pico"] == ["RButton"] else 200)
            st["job"] = inner.after(_gracia, lambda: st.update(cerrado=True, job=None))

    # Botón "RB" de la UI: arma el capturador oficial si no está armado.
    def tap_rbutton():
        if st.get("armed"):
            return
        arm_capture()

    host._kc_rbutton = tap_rbutton

    def kdown(ev):
        sym = getattr(ev, "keysym", "")
        if sym in ("Tab", "ISO_Left_Tab"):
            return None
        if sym in ("BackSpace", "Delete"):
            if callable(on_clear):
                on_clear()
            else:
                put("")
                if callable(on_commit):
                    on_commit()
                try:
                    inner.event_generate("<FocusOut>")
                except Exception:
                    pass
            accent(False)
            return "break"
        if sym == "Escape":
            if st.get("armed"):
                st["armed"] = False
                accent(False)
            return "break"
        if st.get("manual"):
            return None
        tok = _tok_de(ev)
        if tok:
            if st.get("armed"):
                focus_out(force=True)   # desarma AHK (limpia + CAP_CANCEL) y captura local
            put(tok)
            if callable(on_commit):
                on_commit()
            try:
                inner.event_generate("<FocusOut>")
            except Exception:
                pass
            accent(False)
            return "break"
        return "break"

    def kup(ev):
        if getattr(ev, "keysym", "") in ("Tab", "ISO_Left_Tab"):
            return None
        return "break"

    def mdown(ev):
        if st["manual"]:
            return None
        inner.focus_set()
        try:
            inner.select_clear()
        except Exception:
            pass
        press("RButton")
        return "break"

    def mup(ev):
        if st["manual"]:
            return None
        try:
            inner.select_clear()
        except Exception:
            pass
        release("RButton")
        return "break"

    def mmotion(ev):
        if not st["manual"]:
            return "break"

    for _ev, _fn in (("<KeyPress>", kdown), ("<Alt-KeyPress>", kdown),
                     ("<KeyRelease>", kup), ("<Alt-KeyRelease>", kup),
                     ("<B3-Motion>", mmotion)):
        inner.bind(_ev, _fn, add="+")

    # Puente AHK: F24 = RButton del stylus/ratón mientras CAPTURE_ON.
    # Un binding con keysym concreto es más específico que <KeyPress> y lo reemplaza.
    def _f24_down(_e):
        press("RButton")
        return "break"

    def _f24_up(_e):
        release("RButton")
        return "break"

    inner.bind("<KeyPress-F24>", _f24_down, add="+")
    inner.bind("<KeyRelease-F24>", _f24_up, add="+")

    canvas = getattr(ent, "_canvas", None)
    def btn_press(ev):
        if getattr(ev, "num", None) == 3:
            return mdown(ev)

    def btn_release(ev):
        if getattr(ev, "num", None) == 3:
            return mup(ev)

    last_click_t = [0.0]
    last_ev_sig = [None]

    def _same_physical_click(ev):
        # Un clic físico se propaga a inner/ent/canvas con el mismo time y coords.
        t = getattr(ev, "time", None)
        if t is None:
            return False
        sig = (t, getattr(ev, "x_root", None), getattr(ev, "y_root", None))
        if sig == last_ev_sig[0]:
            return True
        last_ev_sig[0] = sig
        return False

    def _is_empty():
        try:
            return not bool(ent.get().strip())
        except Exception:
            return True

    def arm_capture():
        if st.get("armed"):
            return
        st["armed"] = True
        st["manual"] = False
        try:
            _res_file.unlink(missing_ok=True)
        except Exception:
            pass
        try:
            prev_val = ""
            items = []
            if callable(get_history):
                prev_val, items = get_history()
            hist_file = Path(tempfile.gettempdir()) / "_ahk_cap_hist.txt"
            lines = [str(prev_val or "")] + [str(it) for it in items if it]
            hist_file.write_text("\n".join(lines), encoding="utf-8-sig")
        except Exception:
            pass
        st["arm_deadline"] = _mono() + _ARM_MAX_S
        st["handoff_until"] = _mono() + _HANDOFF_S
        _cap_send("CAP_ARM")
        _poll_ahk()

    def on_click(ev=None):
        if getattr(ev, "num", None) == 3:
            return
        if _same_physical_click(ev):
            return
        now = _mono()
        last_click_t[0] = now
        try:
            inner.focus_set()           # teclado local; AHK solo con doble clic
        except Exception:
            pass

    def on_double_click(ev=None):
        arm_capture()

    for _w in ([w for w in (inner, ent, canvas) if w is not None]):
        try:
            _w.configure(cursor="hand2")
        except Exception:
            pass
        _w.bind("<ButtonPress>", btn_press, add="+")
        _w.bind("<ButtonRelease>", btn_release, add="+")
        _w.bind("<ButtonPress-3>", mdown, add="+")
        _w.bind("<ButtonRelease-3>", mup, add="+")
        _w.bind("<Button-3>", mdown, add="+")
        _w.bind("<Button-1>", on_click, add="+")
        _w.bind("<Double-Button-1>", on_double_click, add="+")

    import tempfile
    from pathlib import Path
    _res_file = Path(tempfile.gettempdir()) / "_ahk_cap_result.txt"
    from time import monotonic as _mono
    _HANDOFF_S = 1.5   # ventana en que un FocusOut es consecuencia de CAP_ARM
    _ARM_MAX_S = 7.0   # 5 s de timeout AHK + margen: evita armed colgado

    def _poll_ahk():
        if not st.get("armed"):
            return
        st["poll_job"] = None
        try:
            if _res_file.exists():
                content = _res_file.read_text(encoding="utf-8-sig").strip()
                try:
                    _res_file.unlink(missing_ok=True)
                except Exception:
                    pass
                parts = content.split("|")
                estado = (parts[0] if parts else "").strip().lstrip("\ufeff")
                combo = (parts[1] if len(parts) > 1 else "").strip()
                # 1) Cerrar el estado ANTES de tocar el Entry: así el FocusOut
                #    sintético ya no ve armed=True ni envía CAP_CANCEL.
                st["armed"] = False
                st["handoff_until"] = 0.0
                if estado == "ok" and combo:
                    put(combo)
                    if callable(on_commit):
                        try:
                            on_commit()
                        except Exception:
                            pass
                    try:
                        inner.event_generate("<FocusOut>")  # commit al Draft
                    except Exception:
                        pass
                accent(False)
                return
        except Exception:
            pass
        if _mono() > st.get("arm_deadline", 0.0):
            st["armed"] = False
            st["handoff_until"] = 0.0
            accent(False)
            return
        st["poll_job"] = inner.after(60, _poll_ahk)

    def focus_in(_e=None):
        accent(True)
        # Opción A: ya no se arma AHK al enfocar (causaba el ping-pong de foco)

    def focus_out(_e=None, force=False):
        if (not force and st.get("armed")
                and _mono() < st.get("handoff_until", 0.0)):
            return  # FocusOut esperado: AHK está devolviendo el foco a CSP
        st["handoff_until"] = 0.0
        st["manual"] = False
        reset_state()
        accent(False)
        if st["armed"]:
            st["armed"] = False
            if st.get("poll_job") is not None:
                try:
                    inner.after_cancel(st["poll_job"])
                except Exception:
                    pass
                st["poll_job"] = None
            _cap_send("CAP_CANCEL|focus_out")

    inner.bind("<FocusIn>", focus_in, add="+")
    inner.bind("<FocusOut>", focus_out, add="+")
    inner.bind("<Destroy>", lambda e: focus_out(e, force=True), add="+")

    return ent


class _FlowRowLegacy(ctk.CTkFrame):
    """Celdas en línea; si no caben a lo ancho, continúan en la línea siguiente.

    Uso:  fr = FlowRow(parent); fr.grid(...); fr.add(celda)  /  fr.reflow()
    Las celdas deben ser contenedores con su ancho natural ya definido.
    """
    def __init__(self, parent, gap=14, row_gap=8):
        super().__init__(parent, fg_color="transparent", width=0, height=0)
        self.gap, self.row_gap = gap, row_gap
        self.cells: list = []
        self._pos: list[tuple[int, int]] = []
        self._job = None
        self.bind("<Configure>", self._sched)

    def add(self, widget):
        self.cells.append(widget)
        self._pos.append((-1, -1))
        return widget

    def _sched(self, _e=None):
        if self._job:
            self.after_cancel(self._job)
        self._job = self.after(40, self.reflow)

    def reflow(self):
        self._job = None
        if not self.cells:
            return
        try:
            avail = self._reverse_widget_scaling(self.winfo_width())
        except Exception:
            return
        if avail <= 1:
            return
        for c in self.cells:
            c.update_idletasks()
        row = col = 0
        x = 0
        pos: list[tuple[int, int]] = []
        for c in self.cells:
            cw = c.winfo_reqwidth()
            sep = self.gap if col else 0
            if col and (x + sep + cw) > avail:
                row, col, sep, x = row + 1, 0, 0, 0
            pos.append((row, col))
            x += sep + cw
            col += 1
        if pos == self._pos:
            return
        self._pos = pos
        for c in self.cells:
            c.grid_forget()
        for i in range(max((cc for _, cc in pos), default=0) + 1):
            self.grid_columnconfigure(i, weight=0, minsize=0)
        for i in range(max((r for r, _ in pos), default=0) + 1):
            self.grid_rowconfigure(i, weight=0)
        for c, (r, cc) in zip(self.cells, pos):
            c.grid(row=r, column=cc, sticky="w",
                   padx=(0 if cc == 0 else self.gap, 0),
                   pady=(0 if r == 0 else self.row_gap, 0))


class ResponsiveRow(ctk.CTkFrame):
    """N celdas en fila; por debajo de `breakpoint` (px lógicos) se apilan."""
    def __init__(self, parent, n, breakpoint=640, weights=None, uniform="rr", minsize=190, gap=10):
        super().__init__(parent, fg_color="transparent", width=0, height=0)
        self.n, self.breakpoint, self.weights = n, breakpoint, weights or [1] * n
        self.uniform, self.minsize, self.gap = uniform, minsize, gap
        self.cells = [ctk.CTkFrame(self, fg_color="transparent", width=0, height=0) for _ in range(n)]
        self._mode, self._job = None, None
        self.bind("<Configure>", self._sched)
        self._layout("row")

    def _sched(self, _e=None):
        if self._job:
            self.after_cancel(self._job)
        self._job = self.after(50, self._check)

    def _check(self):
        self._job = None
        try:
            w = self._reverse_widget_scaling(self.winfo_width())
        except Exception:
            return
        self._layout("row" if w >= self.breakpoint else "col")

    def _layout(self, mode):
        if mode == self._mode:
            return
        self._mode = mode
        for c in self.cells:
            c.grid_forget()
        for i in range(self.n):
            self.grid_columnconfigure(i, weight=0, uniform="", minsize=0)
            self.grid_rowconfigure(i, weight=0)
        if mode == "row":
            for i, cell in enumerate(self.cells):
                self.grid_columnconfigure(i, weight=self.weights[i], uniform=self.uniform, minsize=self.minsize)
                cell.grid(row=0, column=i, sticky="nsew",
                          padx=(0 if i == 0 else self.gap, self.gap if i < self.n - 1 else 0))
        else:
            self.grid_columnconfigure(0, weight=1)
            for i, cell in enumerate(self.cells):
                cell.grid(row=i, column=0, sticky="ew", pady=(0 if i == 0 else 8, 0))
                cell.grid_columnconfigure(0, weight=1)
