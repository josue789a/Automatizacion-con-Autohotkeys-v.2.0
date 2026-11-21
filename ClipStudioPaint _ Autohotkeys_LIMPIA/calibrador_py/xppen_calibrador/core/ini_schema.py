"""Contrato de datos con posiciones_gui.ini (única fuente de verdad).

Ningún widget conoce claves del INI: todo pasa por los nombres lógicos de FIELDS.
Plantillas: {id} = idEv, {p} = perfil activo.
section == "@auto": la clave se busca en todas las secciones; si no existe se usa `fallback`.
"""
from __future__ import annotations
import re
from dataclasses import dataclass

HOVER_OP_SCALE = 100          # AHK guarda % directo (muestra real: 2 y 100). VERIFICAR en pruebas.
PILDORA_TAMS = {"Pequeño": 70, "Mediano": 100, "Grande": 140}
PERFILES = {"1": "PC (1 monitor)", "2": "Laptop", "3": "PC (2 monitores)"}                  # valor INI → etiqueta
PILDORAS = (("bloquear", "Bloquear"), ("calibrador", "Calibrador"), ("recargar", "Recargar"),
            ("hist_color", "Hist. Color"), ("ventana", "Ventana"), ("acceso_r", "Acceso R."),
            ("slider", "Slider"), ("circle", "CIRCLE"))                # (clave, etiqueta); nacen ocultas
ACCESOS = (("frente", "Frente", 1), ("estabilizador", "Estabilizador", 1), ("voltear", "Voltear lienzo", 0),
           ("modo_enfoque", "Modo Enfoque", 0), ("layout_paneles", "Layout Paneles", 0),
           ("acciones_rapidas", "Acciones Rápidas", 0), ("restaurar_audio", "Restaurar audio", 0))

PIL_KEY_MAP = {
    "bloquear": "mostrar_lock",
    "calibrador": "mostrar_puntos",
    "recargar": "mostrar_reload",
    "hist_color": "mostrar_hc",
    "ventana": "mostrar_nv",
    "acceso_r": "mostrar_ar",
    "slider": "mostrar_ds",
    "circle": "mostrar_cc",
}
ACC_KEY_MAP = {
    "frente": "rapida_frente",
    "estabilizador": "rapida_estab",
    "voltear": "rapida_flip",
    "modo_enfoque": "rapida_enfoque",
    "layout_paneles": "rapida_layout",
    "acciones_rapidas": "rapida_rapidas",
    "restaurar_audio": "rapida_audio",
}


@dataclass(frozen=True)
class Field:
    section: str
    key: str
    kind: str                       # bool | int | str | hex | choice
    default: object = ""
    lo: int | None = None
    hi: int | None = None
    choices: tuple = ()
    fallback: str = ""              # sección si section == "@auto" y la clave no existe


F = Field
FIELDS: dict[str, Field] = {
    # ── A · Configuración básica ────────────────────────────
    "atajo":       F("Remapeos", "atajo_{id}", "str", ""),
    "remap":       F("Remapeos", "remap_{id}", "str", ""),
    "hud_formato": F("@auto", "formato_{id}", "choice", "moderno", choices=("moderno", "bruto", "desactivado"), fallback="HudEventos{p}"),
    "hud_zona":    F("@auto", "zona_{id}", "choice", "baja", choices=("baja", "media", "alta"), fallback="HudEventos{p}"),
    "hud_opac":    F("@auto", "opacidad_{id}", "choice", "70", choices=("50", "70", "90", "100"), fallback="HudEventos{p}"),
    "hud_texto":   F("@auto", "texto_{id}", "str", "", fallback="HudTextos{p}"),
    "hud_dur":     F("@auto", "duracion_{id}", "str", "auto", fallback="HudEventos{p}"),   # "auto" o ms
    "snd_ambito":  F("@auto", "snd_ambito_{id}", "choice", "global", choices=("global", "este_evento"), fallback="HudSonido{p}"),
    "snd_activo":  F("@auto", "ev_{id}_activo", "bool", 1, fallback="HudSonido{p}"),
    "snd_tipo":    F("@auto", "ev_{id}_tipo", "choice", "clic", choices=("clic", "suave", "agudo", "grave", "doble", "pluma", "aerografo", "color_primario", "color_secundario", "borrador", "lazo", "relleno", "guardar", "mute"), fallback="HudSonido{p}"),
    "snd_vol":     F("@auto", "ev_{id}_vol", "int", 60, 0, 100, fallback="HudSonido{p}"),
    # ── B1 · Presencia y Superficie ─────────────────────────
    "pildora":       F("Particularidades", "pildora_{id}", "bool", 0),
    "pildora_tam":   F("Particularidades", "pildora_tam_{id}", "int", 100, 60, 250),
    "pildora_color": F("Particularidades", "pildora_color_{id}", "hex", "7863A6"),
    "pildora_nombre":   F("Particularidades", "pildora_nombre_{id}", "str", ""),
    "pildora_modo_tam": F("Particularidades", "pildora_modo_tam_{id}", "str", "auto"),
    "pildora_icono":    F("Particularidades", "pildora_icono_{id}", "str", ""),
    # ── B2 · Disparador Espacial ────────────────────────────
    "cruzar":      F("Particularidades", "cruzar_{id}", "bool", 0),
    "auto":        F("Particularidades", "auto_{id}", "bool", 0),
    "hover":       F("Particularidades", "hover_{id}", "bool", 0),
    "hover_rep":   F("Particularidades", "hover_op_rep_{id}", "int", 2, 1, HOVER_OP_SCALE),
    "hover_act":   F("Particularidades", "hover_op_act_{id}", "int", 100, 1, HOVER_OP_SCALE),
    "hover_borde": F("Particularidades", "hover_borde_{id}", "bool", 1),
    # ── B3 · Modulación de Tecla ────────────────────────────
    "quick":       F("Particularidades", "quick_{id}", "bool", 0),
    "quick_a":     F("Particularidades", "quick_a_{id}", "str", ""),
    "quick_b":     F("Particularidades", "quick_b_{id}", "str", ""),
    "quick_ms":    F("Particularidades", "quick_ms_{id}", "int", 250, 50, 2000),
    "quick_ms_max": F("Particularidades", "quick_ms_max_{id}", "int", 500, 50, 2000),
    "toggle":      F("Particularidades", "toggle_{id}", "bool", 0),
    "toggle_a":    F("Particularidades", "toggle_a_{id}", "str", ""),
    "toggle_b":    F("Particularidades", "toggle_b_{id}", "str", ""),
    # ── B4 · Deslizador Virtual (perfil activo, no por evento) ─
    "sl_modo":     F("Estab_p{p}", "modo", "choice", "Horizontal", choices=("Horizontal", "Vertical")),
    "sl_rmin":     F("Estab_p{p}", "rmin", "int", 0, 0, 100),
    "sl_rmax":     F("Estab_p{p}", "rmax", "int", 100, 0, 100),
    "sl_paso_on":  F("Estab_p{p}", "paso_on", "bool", 1),
    "sl_paso":     F("Estab_p{p}", "paso", "int", 5, 1, 50),
    "sl_tecla_bajar": F("Estab_p{p}", "tecla_bajar", "str", "j"),
    "sl_tecla_subir": F("Estab_p{p}", "tecla_subir", "str", "-"),
    "sl_snap_1":   F("Estab_p{p}", "snap_1", "int", 7, 0, 100),
    "sl_snap_2":   F("Estab_p{p}", "snap_2", "int", 15, 0, 100),
    "sl_snap_3":   F("Estab_p{p}", "snap_3", "int", 35, 0, 100),
    "sl_snap_4":   F("Estab_p{p}", "snap_4", "int", 55, 0, 100),
    "sl_snap_5":   F("Estab_p{p}", "snap_5", "int", 75, 0, 100),
    # ── B5 · Nuevas Ventanas y Lienzos (global) ─────────────
    "nv_modo":     F("NvConfig", "modo", "choice", "hover", choices=("hover", "total")),
    "nv_franja":   F("NvConfig", "ventanas_franja_ubic", "choice", "sup", choices=("sup", "inf")),
    "nv_visibles": F("NvConfig", "ventanas_visibles", "choice", "Todas", choices=("Todas",)),
    "nv_lienzos":  F("NvConfig", "mostrar_lienzos", "bool", 1),
    "nv_opc_hover": F("NvConfig", "opc_hover", "int", 50, 0, 100),
    "nv_opc_off":   F("NvConfig", "opc_off", "int", 50, 0, 100),
    # ── C2 · Sistema y perfiles (Mapeo a posiciones_gui.ini real) ──
    "perfil_equipo":  F("Perfil", "actual", "choice", "1", choices=tuple(PERFILES)),
    "escala_botones": F("Puntos{p}", "escala", "int", 70, 30, 200),
    "escala_avisos":  F("Puntos{p}", "escalaavisos", "int", 77, 30, 200),
    **{f"pil_{k}": F("Hub_p{p}", PIL_KEY_MAP[k], "bool", 0) for k, _ in PILDORAS},
    **{f"acc_{k}": F("Hub_p{p}", ACC_KEY_MAP[k], "bool", d) for k, _, d in ACCESOS},
}
GLOBAL_FIELDS = {n for n, f in FIELDS.items() if "{id}" not in f.key}   # sin idEv

_HEX = re.compile(r"^[0-9A-Fa-f]{6}$")


def to_ui(name: str, raw) -> object:
    """Texto del INI → valor tipado para la UI."""
    f = FIELDS[name]
    raw = "" if raw is None else str(raw).strip()
    if f.kind == "bool":
        if raw in ("1", "true", "True"):
            return 1
        if raw in ("0", "false", "False"):
            return 0
        return int(bool(f.default))
    if f.kind == "int":
        try:
            return max(f.lo, min(f.hi, int(float(raw))))
        except ValueError:
            return f.default
    if f.kind == "hex":
        h = raw.lstrip("#")
        return h.upper() if _HEX.match(h) else f.default
    if f.kind == "choice":
        low = raw.lower()
        for c in f.choices:
            if c.lower() == low:
                return c
        return raw if raw else f.default
    if name == "hud_dur":
        return raw if raw else "auto"
    return raw


def to_ini(name: str, value) -> str | None:
    """Valor de la UI → texto del INI normalizado; None si es inválido."""
    f = FIELDS[name]
    if f.kind == "bool":
        return "1" if value in (1, True, "1") else "0"
    if f.kind == "int":
        try:
            v = int(str(value).strip())
        except ValueError:
            return None
        return str(v) if f.lo <= v <= f.hi else None
    if f.kind == "hex":
        v = str(value).lstrip("#")
        return v.upper() if _HEX.match(v) else None
    if name == "hud_dur":
        v = str(value).strip().lower()
        if v in ("", "auto"):
            return "auto"
        return v if v.isdigit() and 100 <= int(v) <= 10000 else None
    return str(value).strip()
