"""Defaults de fábrica de las particularidades nativas de cada evento.

Análogo a ATAJO_DEFAULTS / REMAP_DEFAULTS: se usa cuando [Particularidades]
del INI no tiene la clave. Una clave presente en el INI (incluso con 0 o vacío)
SIEMPRE gana sobre estos defaults.

Claves de campo = las del INI sin el sufijo _<evento>:
  quick, quick_ms, quick_a, quick_b -> Pulsación rápida (toque corto/largo)
  toggle, toggle_a, toggle_b        -> Alternador A <-> B
  pildora, hover, slider            -> casillas de Presencia / Disparador / Deslizador
"""
from __future__ import annotations

_QUICK_MS = 300

PARTICULARIDADES_DEFAULTS: dict[str, dict[str, object]] = {
    # ── Borradores y Mezcla ──
    "borrador_suave":  {"quick": 1, "quick_a": "e", "quick_b": "l", "quick_ms": _QUICK_MS},
    "borrador":        {"quick": 1, "quick_a": "e", "quick_b": "l", "quick_ms": _QUICK_MS},
    "smudge":          {"quick": 1, "quick_a": "d", "quick_b": "p", "quick_ms": _QUICK_MS},
    "smear_soft":      {"quick": 1, "quick_a": "b", "quick_b": "NumpadEnd", "quick_ms": _QUICK_MS},

    # ── Pinceles y Trazos ──
    "pluma":           {"quick": 1, "quick_a": "q", "quick_b": "Ctrl+2", "quick_ms": _QUICK_MS},
    "aerografo":       {"quick": 1, "quick_a": "w", "quick_b": "k", "quick_ms": _QUICK_MS},
    "aerografo_alpha": {"quick": 1, "quick_a": "w", "quick_b": "k", "quick_ms": _QUICK_MS},

    # ── Color y Paleta ──
    "color_primario":   {"quick": 1, "quick_a": "q", "quick_b": "Ctrl+2", "quick_ms": _QUICK_MS},
    "color_secundario": {"quick": 1, "quick_a": "q", "quick_b": "Ctrl+2", "quick_ms": _QUICK_MS},
    "area_color":       {"quick": 1, "quick_a": "s", "quick_b": "Ctrl+X", "quick_ms": 400},

    # ── Selección ──
    "lazo":            {"quick": 1, "quick_a": "s", "quick_b": "Ctrl+X", "quick_ms": 400},
    "deseleccion":     {"toggle": 1, "toggle_a": "x", "toggle_b": "F10"},
    "reseleccion":     {"toggle": 1, "toggle_a": "x", "toggle_b": "F10"},

    # ── Lienzo y Reglas ──
    "shift_sostenido": {"hover": 1},
    "rotar_lienzo":    {"quick": 1, "quick_a": "z", "quick_b": "r", "quick_ms": _QUICK_MS},
    "zoom_lienzo":     {"quick": 1, "quick_a": "z", "quick_b": "r", "quick_ms": _QUICK_MS},

    # ── Deslizador y Píldoras ──
    "estab_slider":    {"slider": 1, "pildora": 1},
    "history_lock":    {"pildora": 1, "hover": 1},
    "panel_ds":        {"pildora": 1, "hover": 1},
    "panel_cc":        {"pildora": 1, "hover": 1},
    "gui_frente":      {"pildora": 1, "hover": 1},
    "reload":          {"pildora": 1, "hover": 1},
}


def particularidad_default(evento_id: str, campo: str, fallback=None):
    """Valor de fábrica de `campo` para `evento_id`, o `fallback` si no existe."""
    return PARTICULARIDADES_DEFAULTS.get(evento_id, {}).get(campo, fallback)


def tiene_particularidad_nativa(evento_id: str) -> bool:
    return evento_id in PARTICULARIDADES_DEFAULTS
