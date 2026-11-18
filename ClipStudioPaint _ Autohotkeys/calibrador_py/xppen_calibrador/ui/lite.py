"""ui/lite.py - ayudantes ligeros basados en tk.Canvas (sin un CTk* por celda)."""
import tkinter as tk
import tkinter.font as tkfont

import customtkinter as ctk


def c(col):
    """Resuelve un color (str o tupla (claro, oscuro)) según el modo actual."""
    if isinstance(col, (tuple, list)):
        return col[1] if ctk.get_appearance_mode() == "Dark" else col[0]
    return col


def scale(widget, px):
    """Píxeles lógicos -> reales. tk.Canvas / tk.Entry NO heredan el escalado de CTk."""
    try:
        from customtkinter.windows.widgets.scaling.scaling_tracker import ScalingTracker
        f = ScalingTracker.get_widget_scaling(widget)
    except Exception:
        try:
            f = widget.winfo_fpixels("1i") / 96.0
        except Exception:
            f = 1.0
    return int(round(px * f))


def tk_font(widget, ctkfont):
    """CTkFont (o tupla) -> tkinter.font.Font escalado. Conservar la referencia."""
    try:
        fam, size, wt = ctkfont.cget("family"), ctkfont.cget("size"), ctkfont.cget("weight")
    except AttributeError:
        fam, size = ctkfont[0], ctkfont[1]
        wt = ctkfont[2] if len(ctkfont) > 2 else "normal"
    return tkfont.Font(root=widget, family=fam, size=-scale(widget, abs(size)), weight=wt)


# --- Rueda del mouse: UN solo bind_all para toda la app, con despacho por puntero ---
# (no se usa unbind_all: borraría el bind_all de CatalogoPanel)
_REG = {}
_HOOKED = False


def _dispatch(e):
    try:
        w = e.widget.winfo_containing(e.x_root, e.y_root)
    except Exception:
        return
    while w is not None:
        ls = _REG.get(str(w))
        if ls is not None:
            ls._wheel(e)
            return
        w = getattr(w, "master", None)


class LiteScroll(tk.Frame):
    """tk.Canvas + CTkScrollbar nativa. scrollregion con debounce.
    - Contenido dibujado: usar .cv y llamar set_height(px_reales).
    - Contenido con widgets: usar .cv.create_window(...) y set_height().
    """
    SB_W = 12  # px lógicos

    def __init__(self, master, bg, unit_px=12, sb_kw=None):
        global _HOOKED
        super().__init__(master, bg=c(bg), bd=0, highlightthickness=0)
        self.grid_rowconfigure(0, weight=1)
        self.grid_columnconfigure(0, weight=1)
        self.cv = tk.Canvas(self, bg=c(bg), highlightthickness=0, bd=0, takefocus=0,
                            yscrollincrement=max(1, scale(self, unit_px)))
        kw = dict(orientation="vertical", width=self.SB_W, corner_radius=6, fg_color="transparent")
        kw.update(sb_kw or {})
        self.sb = ctk.CTkScrollbar(self, command=self.cv.yview, **kw)
        self.cv.configure(yscrollcommand=self.sb.set)
        self.cv.grid(row=0, column=0, sticky="nsew")
        self.sb.grid(row=0, column=1, sticky="ns")
        self._h = 0
        self._job = None
        self.cv.bind("<Configure>", lambda _e: self._sched(), add="+")
        _REG[str(self)] = self
        _REG[str(self.cv)] = self
        self.bind("<Destroy>", self._on_destroy, add="+")
        if not _HOOKED:
            tk.Misc.bind_all(self, "<MouseWheel>", _dispatch, add="+")
            _HOOKED = True

    def sb_px(self):
        """Ancho real reservado por la barra (para alinear cabeceras fijas)."""
        return scale(self, self.SB_W)

    def set_height(self, h):
        self._h = int(h)
        self._sched()

    def _sched(self):
        if self._job is None:
            self._job = self.after_idle(self._apply)

    def _apply(self):
        self._job = None
        if not self.cv.winfo_exists():
            return
        w, vh = max(self.cv.winfo_width(), 1), self.cv.winfo_height()
        self.cv.configure(scrollregion=(0, 0, w, max(self._h, vh)))

    def _wheel(self, e):
        lo, hi = self.cv.yview()
        if lo <= 0.0 and hi >= 1.0:
            return
        self.cv.yview_scroll((-3 if e.delta > 0 else 3), "units")

    def _on_destroy(self, e):
        if e.widget is self:
            _REG.pop(str(self), None)
            _REG.pop(str(self.cv), None)
