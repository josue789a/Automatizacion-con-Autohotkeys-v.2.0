"""CalibradorApp: ventana principal (980×640 lógicos) con las 4 pestañas migradas."""
from __future__ import annotations
import logging
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox
import customtkinter as ctk
from .core.ahk_bridge import AhkBridge
from .core.catalogo import Catalogo
from .core.draft import Draft
from .core.ini_store import IniFile
from .core.single_instance import TITULO, mtime_codigo
from .ui import theme as T
from .ui.blocks import Ctx
from .ui.cards import TabCtx
from .ui.panels import CatalogoPanel, EditorPanel, Footer
from .ui.widgets import set_captura_bridge
from .ui.tab_sistema import SistemaTab
from .ui.tab_temas import TemasTab
from .ui.tab_zonas import ZonasTab
from .ui import ctk_patches  # noqa: F401  (debe importarse antes de crear widgets)

log = logging.getLogger("calibrador.app")
DATA_DIR = Path(__file__).resolve().parents[1] / "data"


_SIG_CODIGO = mtime_codigo()       # firma del código ya cargado en este proceso

TABS = (("⚡", "Eventos y particularidades"), ("✎", "Zonas y rangos"), ("⚙", "Sistema y perfiles"), ("⬢", "Paleta de temas"))


class CalibradorApp(ctk.CTk):
    def __init__(self, ini_path, perfil="1", modo="Normal", ahk_hwnd=0):
        ctk.set_appearance_mode("light")
        super().__init__(fg_color=T.BG)
        T.init_fonts(self)
        self.title(TITULO)
        self.minsize(940, 600)
        self.store = IniFile(ini_path).load()
        self.draft = Draft(self.store, perfil)
        self.catalogo = Catalogo(self.store, DATA_DIR).load()
        self.bridge = AhkBridge(ahk_hwnd, self._own_hwnd)
        set_captura_bridge(self.bridge.send)
        self.ctx = Ctx(self.draft, self.bridge, self.catalogo, self._on_dirty)
        self.modo = modo.capitalize()
        self.theme_store = IniFile(Path(ini_path).with_name("theme.ini")).load()
        self.tc = TabCtx(self.draft, self.store, self.bridge, self.theme_store, DATA_DIR, lambda: self.modo,
                         self._on_dirty, lambda t, ok=True: self.footer.flash(t, ok), self.reload_all)
        self.current = 0
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        self._tabbar()
        self.page_tabs: list = []                      # solo pestañas ya instanciadas (refresh / on_external_change)
        self._tab_clases = {1: ZonasTab, 2: SistemaTab, 3: TemasTab}
        self.current = 0

        # Contenedor principal de pestañas con fondo sólido idéntico a la app (elimina transparencias)
        self.content = ctk.CTkFrame(self, fg_color=T.BG, corner_radius=0)
        self.content.grid(row=1, column=0, sticky="nsew", padx=14, pady=(8, 10))

        self.pages: list = [self._page_eventos(), None, None, None]
        self.footer = Footer(self, self.save, self.save_and_close, self._on_restart,
                             self._set_modo, self.modo)
        self.footer.grid(row=2, column=0, sticky="ew")
        val = str(self.store.get("Calibrador", "alwaysOnTop", "1")).strip()
        self.attributes("-topmost", val != "0")
        try:
            self.attributes("-alpha", 1.0)
        except Exception:
            pass
        self.show_tab(0)
        self.after(700, self._prebuild_pages)
        self._refrescar_btn_anclar()
        self._center()
        self.protocol("WM_DELETE_WINDOW", self._close)
        first = self.catalogo.por_id("estab_slider") or (self.catalogo.eventos[0] if self.catalogo.eventos else None)
        if first:
            self.cat_panel.select(first.id)
        self.after(600, self._poll)

    # ── estructura ─────────────────────────────────────────
    def _tabbar(self):
        bar = ctk.CTkFrame(self, fg_color="transparent", height=44)
        bar.grid(row=0, column=0, sticky="ew", padx=14, pady=(10, 0))
        self.tabs = []
        for i, (ic, tx) in enumerate(TABS):
            b = ctk.CTkButton(bar, text=f"{ic}  {tx}", height=32, corner_radius=8, font=T.font(12, True),
                              command=lambda k=i: self.show_tab(k), border_width=1)
            b.grid(row=0, column=i, padx=(0, 6))
            self.tabs.append(b)
        bar.grid_columnconfigure(len(TABS), weight=1)
        self.btn_top = ctk.CTkButton(bar, text="📌 Anclar", height=28, corner_radius=6,
                                     font=T.font(10, True), fg_color="transparent", hover_color=T.SOFT,
                                     text_color=T.TXT2, border_width=1, border_color=T.BORDER,
                                     command=self._toggle_anclar)
        self.btn_top.grid(row=0, column=len(TABS) + 1, sticky="e")
        self._refrescar_btn_anclar()
        # self._instalar_switch_sin_barrido()      # retirado: WM_SETREDRAW dejaba artefactos de pintado
        self.after(400, self._poll_recarga)      # punto 1

    def _refrescar_btn_anclar(self):
        anclado = bool(self.attributes("-topmost"))
        self.btn_top.configure(text="📌 Desanclar" if anclado else "📌 Anclar",
                               text_color=T.PRIMARY if anclado else T.TXT2,
                               border_color=T.PRIMARY if anclado else T.BORDER)

    def _toggle_anclar(self):
        nuevo = not bool(self.attributes("-topmost"))
        self.attributes("-topmost", nuevo)
        self._refrescar_btn_anclar()
        try:
            self.store.save_patches([("Calibrador", "alwaysOnTop", "1" if nuevo else "0")])
            if hasattr(self, "footer"):
                self.footer.flash(f"📌 Ventana: {'Anclada' if nuevo else 'Desanclada'}")
        except Exception:
            pass

    def _on_restart(self):
        try:
            self.bridge.send("RESTART_SCRIPT")
        finally:
            self.after(150, self.destroy)

    def _poll_recarga(self):
        """Consulta (sin bloquear) si otra instancia pidió recargar."""
        try:
            from .core import single_instance
            if single_instance.consumir_recarga():
                if mtime_codigo() != _SIG_CODIGO:
                    self._reiniciar_proceso()      # el .py cambió: hace falta proceso nuevo
                    return
                self.deiconify()
                self.attributes("-topmost", bool(self.attributes("-topmost")))
                self.lift()
                self.focus_force()
                if hasattr(self, "reload_all"):
                    self.reload_all()
        except Exception:
            pass
        try:
            if self.winfo_exists():
                self.after(250, self._poll_recarga)
        except Exception:
            pass

    def _reiniciar_proceso(self):
        """Relanza el calibrador para cargar el código Python modificado en disco."""
        import subprocess
        from .core import single_instance
        try:
            exe = sys.executable
            base = Path(__file__).resolve().parents[1]
            args = [exe, "-m", "xppen_calibrador", *sys.argv[1:]]
            single_instance.liberar()                       # suelta el mutex para el sucesor
            flags = 0x08000000 if exe.lower().endswith("pythonw.exe") else 0   # CREATE_NO_WINDOW
            subprocess.Popen(args, cwd=str(base), creationflags=flags, close_fds=True)
        except Exception:
            log.exception("reinicio tras recarga")
            return
        self.after(120, self.destroy)

    def _instalar_switch_sin_barrido(self):
        """Punto 3: congela el redibujo durante show_tab para evitar el barrido vertical."""
        import sys
        if sys.platform != "win32" or getattr(self, "_show_tab_raw", None):
            return
        import ctypes
        u32 = ctypes.windll.user32
        orig = self.show_tab
        self._show_tab_raw = orig

        def show_tab_congelado(k, *a, **kw):
            hwnd = 0
            try:
                hwnd = u32.GetParent(self.winfo_id()) or self.winfo_id()
                u32.SendMessageW(hwnd, 0x000B, 0, 0)          # WM_SETREDRAW = FALSE
            except Exception:
                hwnd = 0
            try:
                orig(k, *a, **kw)
                self.update_idletasks()                        # layout completo con redibujo congelado
            finally:
                if hwnd:
                    u32.SendMessageW(hwnd, 0x000B, 1, 0)       # WM_SETREDRAW = TRUE
                    # INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW
                    u32.RedrawWindow(hwnd, None, None, 0x0001 | 0x0004 | 0x0080 | 0x0100)

        self.show_tab = show_tab_congelado

    def _show_placeholder(self):
        """Cubre el contenido con 'Cargando…' y fuerza el pintado antes de una construcción larga."""
        ph = getattr(self, "_ph", None)
        if ph is None:
            ph = ctk.CTkFrame(self.content, fg_color=T.BG, corner_radius=0)
            ctk.CTkLabel(ph, text="Cargando…", font=T.font(14),
                         text_color=T.TXT2).place(relx=0.5, rely=0.5, anchor="center")
            self._ph = ph
        ph.place(relx=0.0, rely=0.0, relwidth=1.0, relheight=1.0)
        ph.lift()
        ph.update_idletasks()
        return ph

    def show_tab(self, i):
        prev = getattr(self, "_shown", None)
        if prev == i:
            return
        self._shown = i
        self.current = i
        for k in (range(len(self.tabs)) if prev is None else (prev, i)):
            on = k == i
            self.tabs[k].configure(fg_color=T.CARD if on else "transparent",
                                   text_color=T.PRIMARY if on else T.TXT2,
                                   hover_color=T.SOFT, border_color=T.BORDER if on else T.BG)
        # 1. Traer inmediatamente al frente la página que entra (sin unmap / sin delay)
        ph = self._show_placeholder() if self.pages[i] is None else None
        try:
            activa = self._ensure_page(i)
            activa.update_idletasks()  # layout resuelto mientras la anterior sigue visible
            activa.lift()
            activa.place(relx=0.0, rely=0.0, relwidth=1.0, relheight=1.0)
        finally:
            if ph is not None:
                ph.place_forget()
        # 2. Retirar las demás fuera de pantalla para que no capturen eventos ni tapen
        for k, p in enumerate(self.pages):
            if p is not None and k != i:
                p.place(relx=2.0, rely=0.0, relwidth=1.0, relheight=1.0)
        if hasattr(self, "footer"):
            self._on_dirty()

    _PREBUILD = (1, 2)   # TemasTab (~5 s) se construye solo bajo demanda

    def _prebuild_pages(self, n=0):
        """Construye en idle las pestañas ligeras, una por tick, sin bloquear la UI."""
        if n >= len(self._PREBUILD) or not self.winfo_exists():
            return
        k = self._PREBUILD[n]
        if self.pages[k] is None and k != getattr(self, "_shown", None):
            p = self._ensure_page(k)
            p.update_idletasks()
        self.after(60, self._prebuild_pages, n + 1)

    def _ensure_page(self, i):
        """Devuelve la página i; si aún no existe la construye y la ubica fuera de vista."""
        pg = self.pages[i]
        if pg is None:
            pg = self._page_tab(self._tab_clases[i])
            self.pages[i] = pg
            pg.place(relx=2.0, rely=0.0, relwidth=1.0, relheight=1.0)
        return pg

    def _precargar(self, k=1):
        """No-op: precarga completa en __init__."""
        pass

    def _page_eventos(self):
        pg = ctk.CTkFrame(self.content, fg_color=T.BG, corner_radius=0)
        pg.place(relx=0.0, rely=0.0, relwidth=1.0, relheight=1.0)
        pg.grid_columnconfigure(1, weight=1)
        pg.grid_rowconfigure(0, weight=1)
        self.cat_panel = CatalogoPanel(pg, self.catalogo, self._select, self._add_event)
        self.cat_panel.grid(row=0, column=0, sticky="ns", padx=(0, 12))
        self.editor = EditorPanel(pg, self.ctx)
        self.editor.grid(row=0, column=1, sticky="nsew")
        return pg

    def _page_tab(self, cls):
        pg = cls(self.content, self.tc)
        pg.configure(fg_color=T.BG, corner_radius=0)
        pg.place(relx=2.0, rely=0.0, relwidth=1.0, relheight=1.0)
        self.page_tabs.append(pg)
        return pg

    # ── eventos de UI ──────────────────────────────────────
    def _select(self, id_ev):
        ev = self.catalogo.por_id(id_ev)
        if ev:
            self.editor.show_event(ev)
            self._on_dirty()

    def _on_dirty(self):
        if not hasattr(self, "footer"):
            return
        if self.current == 1 and self.page_tabs:
            self.footer.set_info(self.page_tabs[0].info_text(), self.draft.count, icon="✓")
            return
        ev = self.catalogo.por_id(self.ctx.event_id) if self.current == 0 and self.ctx.event_id else None
        self.footer.set_info(ev.nombre if ev else None, self.draft.count)

    def _set_modo(self, modo):
        self.modo = modo
        self.bridge.send("SET_MODE", modo.lower())
        self._refresh_tabs()

    def _add_event(self):
        cid, nombre = self.catalogo.siguiente_custom()
        lista = [c for c in (self.store.get("EventosCustom", "lista", "") or "").split(",") if c.strip()]
        try:
            self.store.save_patches([("EventosCustom", "lista", ",".join([*lista, cid])), ("EventosCustom", cid, f"{nombre}|")])
        except OSError as e:
            self.footer.flash(str(e), False)
            return
        self.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        self.cat_panel.rebuild()
        self.cat_panel.select(cid)

    # ── guardado ───────────────────────────────────────────
    def save(self) -> bool:
        try:
            top = self.winfo_toplevel()
            top.focus_set()          # saca el foco del entry activo -> dispara <FocusOut>/commit
            top.update_idletasks()   # procesa los eventos pendientes sin reentrar al mainloop
        except Exception:
            log.exception("commit previo al guardado")
        patches = self.draft.patches()
        if not patches:
            self.footer.flash("Sin cambios que guardar")
            return True
        try:
            self.store.save_patches(patches)
        except OSError as e:
            log.exception("guardar")
            self.footer.flash(f"✗ {e}", False)
            return False
        self.draft.clear()
        self._refresh_tabs()
        self.bridge.send("RELOAD_INI")
        self.footer.flash(f"✓ {len(patches)} cambio{'s' if len(patches) != 1 else ''} guardado{'s' if len(patches) != 1 else ''}")
        self._on_dirty()
        return True

    def save_and_close(self):
        if self.save():
            self.after(120, self._ocultar_residente)

    def _ocultar_residente(self):
        """Modo residente: ocultar ventana para reapertura instantánea (<0.1s)."""
        self.withdraw()

    def _close(self):
        if self.draft.count:
            r = messagebox.askyesnocancel("Cambios sin guardar", f"Hay {self.draft.count} cambios sin guardar.\n¿Guardarlos antes de cerrar?", parent=self)
            if r is None:
                return
            if r and not self.save():
                return
        self._ocultar_residente()

    # ── cambios externos (AHK escribe el INI) ──────────────
    def _refresh_tabs(self, external=False):
        for t in self.page_tabs:
            (getattr(t, "on_external_change", None) if external and hasattr(t, "on_external_change") else t.refresh)()

    def reload_all(self):
        """Relee posiciones_gui.ini y theme.ini del disco y refresca todas las pestañas."""
        self.store.load()
        self.theme_store.load()
        self.catalogo.load()
        self.ctx.refresh_all()
        self._refresh_tabs(external=True)

    def _poll(self):
        try:
            for st in (self.store, self.theme_store):
                p = st.path
                if p.exists():
                    s_ = p.stat()
                    if st.signature and (s_.st_mtime_ns, s_.st_size) != st.signature:
                        self.reload_all()
                        break
        except OSError:
            pass
        self.after(600, self._poll)

    # ── utilidades ─────────────────────────────────────────
    def _own_hwnd(self) -> int:
        if sys.platform != "win32":
            return 0
        import ctypes
        return ctypes.windll.user32.GetParent(self.winfo_id()) or self.winfo_id()

    def _nac_rect(self):
        """Lee [Calibrador] nacRect=x,y,w,h (px; x/y pueden ser negativos).
        Devuelve (x, y, w, h) o None si falta, es inválido o queda fuera del escritorio virtual."""
        try:
            raw = str(self.store.get("Calibrador", "nacRect") or "").strip()
            if not raw:
                return None
            x, y, rw, rh = [int(float(p)) for p in raw.replace(";", ",").split(",")[:4]]
            if rw < 200 or rh < 200:
                return None
            import ctypes
            gm = ctypes.windll.user32.GetSystemMetrics
            vx, vy, vw, vh = gm(76), gm(77), gm(78), gm(79)  # SM_X/Y/CX/CYVIRTUALSCREEN
            if x + rw <= vx or x >= vx + vw or y + rh <= vy or y >= vy + vh:
                return None  # perfil cambiado / monitor desconectado
            return x, y, rw, rh
        except Exception:
            return None

    def _center(self):
        try:
            s = self._get_window_scaling()
            w, h = int(980 * s), int(640 * s)
            r = self._nac_rect()
            if r:
                rx, ry, rw, rh = r
                x = rx + max(0, (rw - w) // 2)
                y = ry + max(0, (rh - h) // 3)
                self.geometry("980x640")
                self.wm_geometry(f"+{x}+{y}")  # Tk puro: admite negativos (+-2442+-...)
                return
            x = max(0, (self.winfo_screenwidth() - w) // 2)
            y = max(0, (self.winfo_screenheight() - h) // 3)
            self.geometry(f"980x640+{x}+{y}")
        except Exception:
            self.geometry("980x640")
