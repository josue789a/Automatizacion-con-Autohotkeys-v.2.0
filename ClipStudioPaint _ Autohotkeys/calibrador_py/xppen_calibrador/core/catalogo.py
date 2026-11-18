"""Catálogo de eventos: AHK es dueño de ids/nombres/grupos (data/catalogo.json).
Si el JSON no existe se reconstruye desde el INI (modo degradado)."""
from __future__ import annotations
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from .ini_store import IniFile

_PART_KEY = re.compile(r"^(?:pildora|cruzar|auto|hover|quick|toggle)_(.+)$", re.I)
_SUFIJOS = ("tam_", "color_", "op_rep_", "op_act_", "borde_", "ms_", "a_", "b_")
GRUPO_CUSTOM = "Personalizados"

ATAJO_DEFAULTS: dict[str, str] = {
    "pluma": "Q", "aerografo": "W", "aerografo_alpha": "K", "pincel_suave": "Alt+Q",
    "pincel_duro": "F6", "difu_mixer": "Ñ", "opc_presion": "<", "borrador": "E",
    "borrador_suave": "L", "borrador_lazo": "F12", "smudge": "P", "smear": "B",
    "smear_soft": "NumpadEnd", "color_mix": "D", "color_primario": "—", "color_secundario": "—",
    "relleno": "V", "area_color": "—", "lazo": "S", "deseleccion": "X", "reseleccion": "F10",
    "inv_seleccion": "C", "shift_sostenido": "Shift", "flip_horizontal": "Alt+G",
    "rotar_lienzo": "R", "zoom_lienzo": "Z", "regla_ocultar": "!t", "capa_visibilidad": "Shift+D",
    "guardar": "^s", "deshacer": "^z", "rehacer": "^y", "copiar": "^c", "enfoque": "Tab",
    "history_lock": "—", "panel_ds": "—", "panel_cc": "—", "gui_frente": "—",
    "estab_slider": "—", "layout": "—", "reload": "^!+r"
}

REMAP_DEFAULTS: dict[str, str] = {
    "pluma": "Q", "aerografo": "W", "aerografo_alpha": "W (doble tap)", "pincel_suave": "Alt+Q",
    "pincel_duro": "Stylus+Q", "difu_mixer": "Stylus+W", "opc_presion": "Alt+W", "borrador": "E",
    "borrador_suave": "E (doble tap)", "borrador_lazo": "Stylus+E", "smudge": "Alt+B + F (rápido)",
    "smear": "Alt+B + F", "smear_soft": "Alt+B + X (rápido)", "color_mix": "Alt+B + X (rápido)",
    "color_primario": "Q (doble tap)", "color_secundario": "Q (doble alt)", "relleno": "Stylus+1",
    "area_color": "S (doble tap)", "lazo": "S", "deseleccion": "X (toggle 0)", "reseleccion": "X (toggle 1)",
    "inv_seleccion": "C", "shift_sostenido": "Stylus+F / Space+-", "flip_horizontal": "Space + Alt+B",
    "rotar_lienzo": "Z (doble tap)", "zoom_lienzo": "Z", "regla_ocultar": "Stylus+T (rápido)",
    "capa_visibilidad": "Space+E", "guardar": "Ctrl+S", "deshacer": "Ctrl+Z", "rehacer": "Ctrl+Y",
    "copiar": "Ctrl+C", "enfoque": "Tab / F3", "history_lock": "Píldora lock", "panel_ds": "Píldora ds / Hover",
    "panel_cc": "Píldora cc / Hover", "gui_frente": "Píldora frente", "estab_slider": "Slider estab",
    "layout": "Menú Companion", "reload": "Píldora reload"
}


@dataclass
class Evento:
    id: str
    nombre: str
    grupo: str
    atajo_def: str = ""
    remap_def: str = ""
    bloques: dict = field(default_factory=dict)     # {"espacial": bool, "tecla": bool, "ventanas": bool}
    custom: bool = False

    def tiene(self, bloque: str) -> bool:
        if bloque == "slider":
            return self.id == "estab_slider" or bool(self.bloques.get("slider"))
        return bool(self.bloques.get(bloque, True))


class Catalogo:
    def __init__(self, store: IniFile, data_dir: Path):
        self.store, self.json_path = store, Path(data_dir) / "catalogo.json"
        self.eventos: list[Evento] = []
        self.origen = "json"

    def load(self) -> "Catalogo":
        evs: dict[str, Evento] = {}
        if self.json_path.exists():
            try:
                for e in json.loads(self.json_path.read_text(encoding="utf-8-sig")).get("eventos", []):
                    eid = e["id"]
                    at = e.get("atajo") or ATAJO_DEFAULTS.get(eid, "")
                    rm = e.get("remap") or REMAP_DEFAULTS.get(eid, "")
                    evs[eid] = Evento(eid, e.get("nombre", eid), e.get("grupo", "Otros"),
                                      at, rm, e.get("bloques", {}))
            except (OSError, ValueError, KeyError):
                evs = {}
        if not evs:
            self.origen = "ini"
            for k in self.store.keys("Particularidades"):
                m = _PART_KEY.match(k)
                if m and not m.group(1).startswith(_SUFIJOS):
                    evs.setdefault(m.group(1), Evento(m.group(1), m.group(1).replace("_", " ").title(), "Eventos"))
            evs.setdefault("estab_slider", Evento("estab_slider", "Deslizador de Estabilización", "Herramientas de Precisión"))
        lista = self.store.get("EventosCustom", "lista", "") or ""
        for cid in [c.strip() for c in lista.split(",") if c.strip()]:
            nombre, _, atajo = (self.store.get("EventosCustom", cid, "") or cid).partition("|")
            evs[cid] = Evento(cid, nombre or cid, GRUPO_CUSTOM, atajo.strip(), custom=True)
        self.eventos = list(evs.values())
        return self

    def por_id(self, id_ev: str) -> Evento | None:
        return next((e for e in self.eventos if e.id == id_ev), None)

    def grupos(self) -> list[str]:
        out: list[str] = []
        for e in self.eventos:
            if e.grupo not in out:
                out.append(e.grupo)
        return out

    def siguiente_custom(self) -> tuple[str, str]:
        usados = {e.id for e in self.eventos}
        n = 1
        while f"custom_{n}" in usados:
            n += 1
        return f"custom_{n}", f"Nuevo evento {n}"
