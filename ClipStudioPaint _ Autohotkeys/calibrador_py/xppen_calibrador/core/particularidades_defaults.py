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

PARTICULARIDADES_DEFAULTS: dict[str, dict[str, object]] = {}


def particularidad_default(evento_id: str, campo: str, fallback=None):
    """Valor de fábrica de `campo` para `evento_id`, o `fallback` si no existe."""
    return PARTICULARIDADES_DEFAULTS.get(evento_id, {}).get(campo, fallback)


def tiene_particularidad_nativa(evento_id: str) -> bool:
    return evento_id in PARTICULARIDADES_DEFAULTS
