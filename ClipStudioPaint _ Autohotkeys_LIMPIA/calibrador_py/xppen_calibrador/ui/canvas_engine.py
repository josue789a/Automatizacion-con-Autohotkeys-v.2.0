"""canvas_engine.py: Motor de renderizado Canvas windowless para el calibrador.

Dibuja tarjetas, cabeceras, botones, campos, checkboxes y menús en una sola superficie
(1 ventana Tk), eliminando cientos de widgets CTk.
Usa 1 Entry flotante reutilizable para edición y 1 tk.Menu para desplegables.
"""
from __future__ import annotations
import math
import sys
import time
import tkinter as tk
import tkinter.font as tkfont
from typing import Callable, Any

from . import theme as T
from .blocks import Ctx

def round_poly(x: float, y: float, w: float, h: float, r: float) -> list[float]:
    """Genera coordenadas para un polígono redondeado con antialiasing suave en tk.Canvas."""
    r = max(2, min(r, w / 2, h / 2))
    return [
        x + r, y,
        x + w - r, y,
        x + w, y,
        x + w, y + r,
        x + w, y + h - r,
        x + w, y + h,
        x + w - r, y + h,
        x + r, y + h,
        x, y + h,
        x, y + h - r,
        x, y + r,
        x, y
    ]


class CanvasForm(tk.Canvas):
    def __init__(self, master, ctx: Ctx, **kwargs):
        kwargs.setdefault("bg", T.BG)
        kwargs.setdefault("highlightthickness", 0)
        kwargs.setdefault("bd", 0)
        super().__init__(master, **kwargs)
        self.ctx = ctx
        self._items: dict[str, dict[str, Any]] = {}
        self._cards: list[dict[str, Any]] = []
        self._hovered_tag: str | None = None
        self._last_width = 800
        self._debounce_job = None
        self.compact_mode = False

        # Fuentes nativas
        self.font_title = tkfont.Font(family=T.FAMILY, size=11, weight="bold")
        self.font_sub = tkfont.Font(family=T.FAMILY, size=9)
        self.font_label = tkfont.Font(family=T.FAMILY, size=9, weight="bold")
        self.font_val = tkfont.Font(family=T.FAMILY, size=10)
        self.font_cap = tkfont.Font(family=T.FAMILY_CAP, size=10, weight="bold")
        self.font_badge = tkfont.Font(family=T.FAMILY, size=10, weight="bold")
        self.font_chev = tkfont.Font(family=T.FAMILY, size=12, weight="bold")

        # 1 Entry flotante reutilizable para todos los campos de texto
        self._active_field_id: str | None = None
        self._entry = tk.Entry(self, font=self.font_val, bg="#FFFFFF", fg=T.TXT,
                              bd=1, relief="solid", highlightthickness=1,
                              highlightcolor=T.PRIMARY, highlightbackground=T.PRIMARY)
        self._entry_win = self.create_window(-1000, -1000, window=self._entry, anchor="nw", state="hidden")
        self._entry.bind("<Return>", self._commit_entry)
        self._entry.bind("<FocusOut>", self._commit_entry)
        self._entry.bind("<Escape>", self._cancel_entry)

        # 1 Menú desplegable reutilizable
        self._menu = tk.Menu(self, tearoff=0, font=self.font_val, bg=T.CARD, fg=T.TXT,
                             activebackground=T.SOFT, activeforeground=T.PRIMARY)

        # Binds unificados en la superficie del Canvas
        self.bind("<Button-1>", self._on_click)
        self.bind("<Motion>", self._on_motion)
        self.bind("<Leave>", self._on_leave)
        self.bind("<MouseWheel>", self._on_mousewheel)
        self.bind("<Configure>", self._on_configure)

    # ── HIT-TESTING & EVENTOS UNIFICADOS ────────────────────────────────────
    def _find_item_data(self) -> tuple[str | None, dict[str, Any] | None]:
        cur = self.find_withtag("current")
        if not cur:
            return None, None
        tags = self.gettags(cur[0])
        for t in tags:
            if t in self._items:
                return t, self._items[t]
        return None, None

    def _on_click(self, event):
        self.focus_set()
        # Si el entry estaba activo, confirmarlo
        if self._active_field_id:
            self._commit_entry()

        tag, item = self._find_item_data()
        if not item:
            return

        kind = item["kind"]
        if kind == "button":
            cmd = item.get("command")
            if cmd:
                cmd()
        elif kind == "checkbox":
            cur_v = bool(item.get("value", False))
            new_v = not cur_v
            item["value"] = new_v
            self._update_checkbox_visual(item)
            cb = item.get("on_change")
            if cb:
                cb(new_v)
        elif kind == "field":
            self._activate_entry(item)
        elif kind == "menu":
            self._open_menu(item, event)
        elif kind == "chevron" or kind == "card_header":
            card_id = item.get("card_id")
            if card_id:
                self.toggle_card(card_id)

    def _on_motion(self, event):
        tag, item = self._find_item_data()
        if tag == self._hovered_tag:
            return
        if self._hovered_tag and self._hovered_tag in self._items:
            prev = self._items[self._hovered_tag]
            self._apply_hover(prev, False)
        self._hovered_tag = tag
        if item:
            self._apply_hover(item, True)
            self.configure(cursor="hand2" if item["kind"] in ("button", "checkbox", "menu", "field", "card_header") else "")
        else:
            self.configure(cursor="")

    def _on_leave(self, _event):
        if self._hovered_tag and self._hovered_tag in self._items:
            self._apply_hover(self._items[self._hovered_tag], False)
            self._hovered_tag = None
        self.configure(cursor="")

    def _apply_hover(self, item: dict[str, Any], is_hover: bool):
        kind = item["kind"]
        tag_bg = item.get("tag_bg")
        if not tag_bg:
            return
        if kind == "button":
            col = T.PRIMARY_HOVER if is_hover else T.PRIMARY
            self.itemconfig(tag_bg, fill=col)
        elif kind in ("field", "menu"):
            col = T.PRIMARY if is_hover else T.FIELD_BORDER
            self.itemconfig(tag_bg, outline=col)

    def _on_mousewheel(self, event):
        self.yview_scroll(int(-1 * (event.delta / 120)), "units")

    def _on_configure(self, event):
        if event.width == self._last_width:
            return
        self._last_width = event.width
        if self._debounce_job:
            self.after_cancel(self._debounce_job)
        self._debounce_job = self.after(150, lambda: self._apply_layout(event.width))

    # ── ENTRY FLOTANTE (Overlay) ────────────────────────────────────────────
    def _activate_entry(self, item: dict[str, Any]):
        self._active_field_id = item["id"]
        x, y, w, h = item["x"], item["y"], item["w"], item["h"]
        val = str(item.get("value", ""))
        self.coords(self._entry_win, x + 2, y + 2)
        self.itemconfig(self._entry_win, state="normal", width=w - 4, height=h - 4)
        self._entry.delete(0, "end")
        self._entry.insert(0, val)
        self._entry.select_range(0, "end")
        self._entry.focus_set()

    def _commit_entry(self, _event=None):
        if not self._active_field_id or self._active_field_id not in self._items:
            self._cancel_entry()
            return
        item = self._items[self._active_field_id]
        new_val = self._entry.get()
        item["value"] = new_val
        self.itemconfig(item["tag_txt"], text=new_val)
        cb = item.get("on_change")
        if cb:
            cb(new_val)
        self._cancel_entry()

    def _cancel_entry(self, _event=None):
        self._active_field_id = None
        self.coords(self._entry_win, -1000, -1000)
        self.itemconfig(self._entry_win, state="hidden")

    # ── MENÚ FLOTANTE ───────────────────────────────────────────────────────
    def _open_menu(self, item: dict[str, Any], event):
        self._menu.delete(0, "end")
        options = item.get("options", [])
        for label, val in options:
            def _choose(v=val, l=label):
                item["value"] = v
                self.itemconfig(item["tag_txt"], text=l)
                cb = item.get("on_change")
                if cb:
                    cb(v)
            self._menu.add_command(label=f"  {label}", command=_choose)
        try:
            root_x = self.winfo_rootx() + item["x"]
            root_y = self.winfo_rooty() + item["y"] + item["h"]
            self._menu.tk_popup(root_x, root_y)
        finally:
            self._menu.grab_release()

    # ── PRIMITIVAS DE DIBUJO Y CREACIÓN ─────────────────────────────────────
    def add_card(self, card_id: str, num: str, title: str, subtitle: str, master_var: str | None = None) -> dict[str, Any]:
        card = {
            "id": card_id,
            "num": num,
            "title": title,
            "subtitle": subtitle,
            "master_var": master_var,
            "expanded": True,
            "y": 0,
            "h": 0,
            "fields": []
        }
        self._cards.append(card)
        return card

    def add_field(self, card_id: str, field_id: str, label: str, default_val: str = "", on_change: Callable | None = None):
        item = {
            "id": field_id,
            "card_id": card_id,
            "kind": "field",
            "label": label,
            "value": default_val,
            "on_change": on_change,
            "x": 0, "y": 0, "w": 140, "h": 28
        }
        self._items[field_id] = item
        card = next((c for c in self._cards if c["id"] == card_id), None)
        if card:
            card["fields"].append(item)
        return item

    def add_menu(self, card_id: str, menu_id: str, label: str, options: list[tuple[str, str]], default_val: str = "", on_change: Callable | None = None):
        item = {
            "id": menu_id,
            "card_id": card_id,
            "kind": "menu",
            "label": label,
            "options": options,
            "value": default_val,
            "on_change": on_change,
            "x": 0, "y": 0, "w": 120, "h": 28
        }
        self._items[menu_id] = item
        card = next((c for c in self._cards if c["id"] == card_id), None)
        if card:
            card["fields"].append(item)
        return item

    def add_checkbox(self, card_id: str, chk_id: str, label: str, default_val: bool = False, on_change: Callable | None = None):
        item = {
            "id": chk_id,
            "card_id": card_id,
            "kind": "checkbox",
            "label": label,
            "value": default_val,
            "on_change": on_change,
            "x": 0, "y": 0, "w": 20, "h": 20
        }
        self._items[chk_id] = item
        card = next((c for c in self._cards if c["id"] == card_id), None)
        if card:
            card["fields"].append(item)
        return item

    def toggle_card(self, card_id: str):
        card = next((c for c in self._cards if c["id"] == card_id), None)
        if not card:
            return
        card["expanded"] = not card["expanded"]
        self.itemconfig(f"chev_{card_id}", text="⌃" if card["expanded"] else "⌄")
        # Ocultar o mostrar elementos hijos
        state = "normal" if card["expanded"] else "hidden"
        self.itemconfig(f"body_{card_id}", state=state)
        self._apply_layout(self.winfo_width() or self._last_width)

    def _update_checkbox_visual(self, item: dict[str, Any]):
        tag_chk = item.get("tag_chk")
        tag_box = item.get("tag_box")
        val = bool(item.get("value", False))
        if tag_chk:
            self.itemconfig(tag_chk, state="normal" if val else "hidden")
        if tag_box:
            self.itemconfig(tag_box, fill=T.PRIMARY if val else T.CARD, outline=T.PRIMARY if val else T.FIELD_BORDER)

    # ── RENDERIZADO INICIAL Y RESPONSIVIDAD (BREAKPOINTS) ───────────────────
    def build_form(self):
        """Construye todos los elementos gráficos en el Canvas por una sola vez."""
        self.delete("all")
        # Volver a crear la ventana del entry flotante
        self._entry_win = self.create_window(-1000, -1000, window=self._entry, anchor="nw", state="hidden")

        for card in self._cards:
            cid = card["id"]
            # Tags de la tarjeta
            t_card = f"card_{cid}"
            t_hdr = f"hdr_{cid}"
            t_body = f"body_{cid}"

            # Fondo de tarjeta
            self.create_polygon([0, 0, 10, 10], fill=T.CARD, outline=T.BORDER, smooth=True, tags=(t_card, f"card_bg_{cid}"))

            # Cabecera interactiva
            self.create_rectangle(0, 0, 10, 10, fill="", outline="", tags=(t_card, t_hdr, f"hdr_hit_{cid}"))
            self._items[f"hdr_hit_{cid}"] = {"kind": "card_header", "card_id": cid}

            # Badge numérico
            self.create_polygon([0, 0, 10, 10], fill=T.SOFT, outline="", smooth=True, tags=(t_card, f"badge_bg_{cid}"))
            self.create_text(0, 0, text=card["num"], fill=T.PRIMARY, font=self.font_badge, tags=(t_card, f"badge_txt_{cid}"))

            # Título y subtítulo
            self.create_text(0, 0, text=card["title"], fill=T.TXT, font=self.font_title, anchor="w", tags=(t_card, f"title_{cid}"))
            self.create_text(0, 0, text=card["subtitle"], fill=T.TXT2, font=self.font_sub, anchor="w", tags=(t_card, f"sub_{cid}"))

            # Chevron
            self.create_text(0, 0, text="⌃", fill=T.TXT2, font=self.font_chev, anchor="center", tags=(t_card, f"chev_{cid}"))
            self._items[f"chev_{cid}"] = {"kind": "chevron", "card_id": cid}

            # Master checkbox (si tiene)
            if card.get("master_var"):
                m_id = f"master_{cid}"
                self.create_polygon([0, 0, 10, 10], fill=T.CARD, outline=T.FIELD_BORDER, smooth=True, tags=(t_card, f"m_box_{cid}", m_id))
                self.create_text(0, 0, text="✓", fill="#FFFFFF", font=self.font_badge, state="hidden", tags=(t_card, f"m_chk_{cid}", m_id))
                self._items[m_id] = {
                    "id": m_id,
                    "kind": "checkbox",
                    "card_id": cid,
                    "value": False,
                    "tag_box": f"m_box_{cid}",
                    "tag_chk": f"m_chk_{cid}",
                    "on_change": lambda v, c=cid: self._on_master_toggle(c, v)
                }

            # Campos del cuerpo
            for item in card["fields"]:
                fid = item["id"]
                t_lbl = f"lbl_{fid}"
                t_bg = f"bg_{fid}"
                t_txt = f"txt_{fid}"
                item["tag_bg"] = t_bg
                item["tag_txt"] = t_txt

                if item["kind"] in ("field", "menu"):
                    self.create_text(0, 0, text=item["label"], fill=T.TXT2, font=self.font_label, anchor="w", tags=(t_card, t_body, t_lbl))
                    self.create_polygon([0, 0, 10, 10], fill=T.CARD, outline=T.FIELD_BORDER, smooth=True, tags=(t_card, t_body, t_bg, fid))
                    disp_text = str(item.get("value", ""))
                    if item["kind"] == "menu":
                        opts = dict(item.get("options", []))
                        disp_text = opts.get(disp_text, disp_text)
                    self.create_text(0, 0, text=disp_text, fill=T.TXT, font=self.font_val, anchor="w", tags=(t_card, t_body, t_txt, fid))
                    if item["kind"] == "menu":
                        self.create_text(0, 0, text="▾", fill=T.TXT3, font=self.font_sub, anchor="center", tags=(t_card, t_body, f"arr_{fid}", fid))
                elif item["kind"] == "checkbox":
                    t_box = f"box_{fid}"
                    t_chk = f"chk_{fid}"
                    item["tag_box"] = t_box
                    item["tag_chk"] = t_chk
                    self.create_polygon([0, 0, 10, 10], fill=T.CARD, outline=T.FIELD_BORDER, smooth=True, tags=(t_card, t_body, t_box, fid))
                    self.create_text(0, 0, text="✓", fill="#FFFFFF", font=self.font_badge, state="hidden", tags=(t_card, t_body, t_chk, fid))
                    self.create_text(0, 0, text=item["label"], fill=T.TXT, font=self.font_val, anchor="w", tags=(t_card, t_body, t_lbl, fid))

        self._apply_layout(self.winfo_width() or self._last_width)

    def _apply_layout(self, total_w: int):
        """Recalcula coordenadas puras con canvas.coords(). Cero destrucción de widgets."""
        pad_x = 14
        content_w = max(400, total_w - pad_x * 2)
        compact = content_w < 680
        self.compact_mode = compact

        curr_y = 12
        for card in self._cards:
            cid = card["id"]
            card_x = pad_x
            card_y = curr_y

            # Dimensiones de cabecera
            hdr_h = 44
            self.coords(f"hdr_hit_{cid}", card_x, card_y, card_x + content_w, card_y + hdr_h)

            # Badge 01..05
            bw, bh = 28, 20
            self.coords(f"badge_bg_{cid}", *round_poly(card_x + 12, card_y + 12, bw, bh, 6))
            self.coords(f"badge_txt_{cid}", card_x + 12 + bw / 2, card_y + 12 + bh / 2)

            # Título y subtítulo
            tx = card_x + 12 + bw + 10
            self.coords(f"title_{cid}", tx, card_y + 16)
            self.coords(f"sub_{cid}", tx, card_y + 32)

            # Chevron a la derecha
            self.coords(f"chev_{cid}", card_x + content_w - 20, card_y + 22)

            # Checkbox maestro
            if card.get("master_var"):
                mx = card_x + content_w - 48
                my = card_y + 13
                self.coords(f"m_box_{cid}", *round_poly(mx, my, 18, 18, 4))
                self.coords(f"m_chk_{cid}", mx + 9, my + 9)
                item = self._items.get(f"master_{cid}")
                if item:
                    item.update({"x": mx, "y": my, "w": 18, "h": 18})

            # Cuerpo
            body_y = card_y + hdr_h + 4
            if card["expanded"]:
                if compact:
                    # En modo compacto apila en filas verticales
                    row_y = body_y
                    for item in card["fields"]:
                        fid = item["id"]
                        if item["kind"] in ("field", "menu"):
                            self.coords(f"lbl_{fid}", card_x + 16, row_y + 8)
                            fw = min(content_w - 32, item.get("w", 140))
                            fh = 28
                            fx = card_x + 16
                            fy = row_y + 20
                            self.coords(f"bg_{fid}", *round_poly(fx, fy, fw, fh, 6))
                            self.coords(f"txt_{fid}", fx + 10, fy + fh / 2)
                            if item["kind"] == "menu":
                                self.coords(f"arr_{fid}", fx + fw - 12, fy + fh / 2)
                            item.update({"x": fx, "y": fy, "w": fw, "h": fh})
                            row_y += 56
                        elif item["kind"] == "checkbox":
                            bx, by = card_x + 16, row_y + 4
                            self.coords(f"box_{fid}", *round_poly(bx, by, 18, 18, 4))
                            self.coords(f"chk_{fid}", bx + 9, by + 9)
                            self.coords(f"lbl_{fid}", bx + 26, by + 9)
                            item.update({"x": bx, "y": by, "w": 18, "h": 18})
                            row_y += 32
                    body_y = row_y + 8
                else:
                    # En modo normal distribuye en filas horizontales fluidas
                    row_x = card_x + 16
                    row_y = body_y
                    line_h = 36
                    for item in card["fields"]:
                        fid = item["id"]
                        if item["kind"] in ("field", "menu"):
                            lbl_w = self.font_label.measure(item["label"]) + 8
                            fw = item.get("w", 140)
                            fh = 28
                            if row_x + lbl_w + fw > card_x + content_w - 16:
                                row_x = card_x + 16
                                row_y += line_h + 4
                            self.coords(f"lbl_{fid}", row_x, row_y + fh / 2)
                            fx = row_x + lbl_w
                            fy = row_y
                            self.coords(f"bg_{fid}", *round_poly(fx, fy, fw, fh, 6))
                            self.coords(f"txt_{fid}", fx + 10, fy + fh / 2)
                            if item["kind"] == "menu":
                                self.coords(f"arr_{fid}", fx + fw - 12, fy + fh / 2)
                            item.update({"x": fx, "y": fy, "w": fw, "h": fh})
                            row_x += lbl_w + fw + 20
                        elif item["kind"] == "checkbox":
                            bx = row_x
                            by = row_y + 4
                            self.coords(f"box_{fid}", *round_poly(bx, by, 18, 18, 4))
                            self.coords(f"chk_{fid}", bx + 9, by + 9)
                            self.coords(f"lbl_{fid}", bx + 26, by + 9)
                            item.update({"x": bx, "y": by, "w": 18, "h": 18})
                            row_x += self.font_val.measure(item["label"]) + 48
                    body_y = row_y + line_h + 10

            card_h = (body_y - card_y) if card["expanded"] else hdr_h
            self.coords(f"card_bg_{cid}", *round_poly(card_x, card_y, content_w, card_h, 12))
            curr_y += card_h + T.GAP

        self.configure(scrollregion=(0, 0, total_w, curr_y + 20))

    def _on_master_toggle(self, card_id: str, val: bool):
        card = next((c for c in self._cards if c["id"] == card_id), None)
        if not card or not card.get("master_var"):
            return
        m_var = card["master_var"]
        self.ctx.set(m_var, 1 if val else 0)
        self.refresh_values()

    # ── CARGA Y SINCRONIZACIÓN DE VALORES (REFRESCO < 10 ms) ───────────────
    def refresh_values(self):
        """Actualiza el estado de los items visuales con itemconfig (sin recrear nada)."""
        ev_id = getattr(self.ctx, "event_id", None)
        if not ev_id:
            return

        for card in self._cards:
            cid = card["id"]
            if card.get("master_var"):
                m_val = bool(self.ctx.get(card["master_var"]))
                m_item = self._items.get(f"master_{cid}")
                if m_item:
                    m_item["value"] = m_val
                    self._update_checkbox_visual(m_item)

            for item in card["fields"]:
                fid = item["id"]
                val = self.ctx.get(fid)
                item["value"] = val
                if item["kind"] in ("field", "menu"):
                    disp = str(val if val is not None else "")
                    if item["kind"] == "menu":
                        opts = dict(item.get("options", []))
                        disp = opts.get(disp.lower(), opts.get(disp, disp))
                    self.itemconfig(item["tag_txt"], text=disp)
                elif item["kind"] == "checkbox":
                    self._update_checkbox_visual(item)


class CanvasGroupA(CanvasForm):
    """Piloto Canvas: Renderizador windowless de alto rendimiento para el Grupo A (A01, A02, A03)."""
    def __init__(self, master, ctx: Ctx, **kwargs):
        super().__init__(master, ctx, **kwargs)
        self._setup_blocks_a()
        self.build_form()

    def _setup_blocks_a(self):
        # A01 Base
        self.add_card("A01", "01", "Base", "Identidad, apariencia y comportamiento general del evento.")
        self.add_field("A01", "atajo", "Atajo CSP", on_change=lambda v: self.ctx.set("atajo", v))
        self.add_field("A01", "remap", "Remapeo Companion", on_change=lambda v: self.ctx.set("remap", v))

        # A02 HUD
        self.add_card("A02", "02", "Feedback visual (HUD)", "Aviso en pantalla al ejecutar el evento.", master_var="hud_formato")
        self.add_menu("A02", "hud_formato", "Formato", [("Moderno", "moderno"), ("Bruto", "bruto"), ("Desactivado", "desactivado")],
                      on_change=lambda v: (self.ctx.set("hud_formato", v), self.ctx.refresh_all()))
        self.add_menu("A02", "hud_zona", "Zona", [("Alta", "alta"), ("Media", "media"), ("Baja", "baja")],
                      on_change=lambda v: self.ctx.set("hud_zona", v))
        self.add_menu("A02", "hud_opac", "Opacidad", [("50 %", "50"), ("70 %", "70"), ("90 %", "90"), ("100 %", "100")],
                      on_change=lambda v: self.ctx.set("hud_opac", v))
        self.add_field("A02", "hud_texto", "Texto del evento", on_change=lambda v: self.ctx.set("hud_texto", v))
        self.add_field("A02", "hud_dur", "Duración (ms)", on_change=lambda v: self.ctx.set("hud_dur", v))

        # A03 Sonido
        self.add_card("A03", "03", "Feedback sonoro", "Sonido al ejecutar el evento.", master_var="snd_activo")
        self.add_menu("A03", "snd_ambito", "Ámbito", [("Global", "global"), ("Este evento", "este_evento")],
                      on_change=lambda v: self.ctx.set("snd_ambito", v))
        SND_OPCIONES = [
            ("Clic suave", "suave"),
            ("Clic", "clic"),
            ("Beep agudo", "agudo"),
            ("Beep grave", "grave"),
            ("Doble beep", "doble"),
            ("Plumilla (Q)", "pluma"),
            ("Aerógrafo (W)", "aerografo"),
            ("Color Primario", "color_primario"),
            ("Color Secundario", "color_secundario"),
            ("Borrador", "borrador"),
            ("Lazo / Sel", "lazo"),
            ("Relleno", "relleno"),
            ("Guardar", "guardar"),
            ("Silencio", "mute")
        ]
        self.add_menu("A03", "snd_tipo", "Sonido", SND_OPCIONES,
                      on_change=lambda v: self.ctx.set("snd_tipo", v))
        self.add_field("A03", "snd_vol", "Volumen (%)", on_change=lambda v: self.ctx.set("snd_vol", int(v) if str(v).isdigit() else 60))
