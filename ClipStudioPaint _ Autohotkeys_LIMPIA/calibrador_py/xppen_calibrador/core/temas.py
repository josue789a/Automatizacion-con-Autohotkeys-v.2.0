"""Paleta de temas (pestaña 4): lectura de data/temas.json y aplicación a theme.ini.

Mapeo swatch → token de theme.ini (comprobado con el tema activo «13. Violeta de Acento (Ciruela)»,
cuyos 5 colores coinciden 1:1 con estos 5 tokens en el theme.ini real):
  Color 1 → surface.on · Color 2 → surface.off · Color 3 → accent.estabSoft
  Color 4 → accent.estab · Color 5 → surface.estabOpen      y  [meta] nombre = nombre del tema
"""
from __future__ import annotations
import json
import re
from dataclasses import dataclass
from pathlib import Path
from .ini_store import IniFile

TOKENS = (("color", "surface.on"), ("color", "surface.off"), ("color", "accent.estabSoft"),
          ("color", "accent.estab"), ("color", "surface.estabOpen"))
META = ("meta", "nombre")
_HEX = re.compile(r"^[0-9A-Fa-f]{6}$")


@dataclass(frozen=True)
class Tema:
    nombre: str
    desc: str
    swatches: tuple[str, ...]


def cargar(data_dir: Path) -> list[Tema]:
    p = Path(data_dir) / "temas.json"
    out: list[Tema] = []
    try:
        for t in json.loads(p.read_text(encoding="utf-8-sig")).get("temas", []):
            sw = tuple(str(c).lstrip("#").upper() for c in t.get("swatches", []))
            if len(sw) == 5 and all(_HEX.match(c) for c in sw):
                out.append(Tema(t["nombre"], t.get("desc", ""), sw))
    except (OSError, ValueError, KeyError):
        return []
    return out


def parches(tema: Tema) -> list[tuple[str, str, str]]:
    return [(s, k, c) for (s, k), c in zip(TOKENS, tema.swatches)] + [(*META, tema.nombre)]


def activo(store: IniFile, temas: list[Tema]) -> int | None:
    """Índice del tema aplicado: por [meta] nombre; si falta, por coincidencia de los 5 tokens."""
    nombre = (store.get(*META) or "").strip()
    for i, t in enumerate(temas):
        if t.nombre == nombre:
            return i
    vals = tuple((store.get(s, k) or "").strip().upper() for s, k in TOKENS)
    for i, t in enumerate(temas):
        if t.swatches == vals:
            return i
    return None


# ── color ────────────────────────────────────────────────
def _rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def mezclar(a: str, b: str, t: float) -> str:
    ra, rb = _rgb(a), _rgb(b)
    return "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(ra, rb))


def texto_sobre(h: str) -> str:
    """Color de texto legible (#1F2428 / #FFFFFF) sobre el fondo h."""
    r, g, b = _rgb(h)
    return "#1F2428" if (0.299 * r + 0.587 * g + 0.114 * b) > 150 else "#FFFFFF"


def muestras(t: Tema) -> list[str]:
    """8 muestras: los 5 colores del tema + 3 derivados deterministas."""
    c1, c2, c3, c4, c5 = t.swatches
    return [c4, c1, mezclar(c1, "FFFFFF", .45), c3, c2, mezclar(c4, "FFFFFF", .5), mezclar(c3, c4, .5), c5]
