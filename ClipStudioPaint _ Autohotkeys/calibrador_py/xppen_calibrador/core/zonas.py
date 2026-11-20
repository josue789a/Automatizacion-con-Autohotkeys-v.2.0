"""Zonas y rangos (pestaña 2): tabla de zonas ↔ claves [Rangos<modo>] del INI.

Zonas oficiales de Clip Studio Paint:
  · [Rangos1] = Modo Normal, [Rangos2] = Modo Enfoque
  · En el INI real cada zona es una clave con valor "x,y,ancho,alto".
  · La UI muestra X, Y, Ancho, Alto.
"""
from __future__ import annotations
from dataclasses import dataclass
from .draft import Draft

MODOS = {1: "Normal", 2: "Enfoque"}
COORD_LO, COORD_HI = -20000, 20000       # negativos válidos: monitor secundario a la izquierda/arriba
PANEL_CSP_KEY = "panel_csp_visible"


@dataclass(frozen=True)
class Zona:
    id: str
    nombre: str
    tipo: str            # etiqueta P1 / P2 / P3 o B1 / B2 / B3
    prefijo: str         # clave en [Rangos<modo>] (ej: izqb1, derb1, historial)

    @property
    def zid(self) -> str:
        """Identificador corto Z1..Z10 (vacío para zonas HUD / ventanas)."""
        return ZID_POR_ID.get(self.id, "")


ZID_POR_ID = {
    "izqb1": "Z1", "izqb2": "Z2", "izqb3": "Z3",
    "derb1": "Z4", "derb2": "Z5", "derb3": "Z6",
    "historial": "Z7", "toggleizq": "Z8", "toggleder": "Z9",
    "zonasegura": "Z10",
}


ZONAS = (
    # Paneles laterales (P1 / P2)
    Zona("izqb1", "Panel izq. - B1", "P1", "izqb1"),
    Zona("izqb2", "Panel izq. - B2", "P1", "izqb2"),
    Zona("izqb3", "Panel izq. - B3", "P1", "izqb3"),
    Zona("derb1", "Panel der. - B1", "P2", "derb1"),
    Zona("derb2", "Panel der. - B2", "P2", "derb2"),
    Zona("derb3", "Panel der. - B3", "P2", "derb3"),
    # Historial y controles de interfaz
    Zona("historial", "Historial de color", "P3", "historial"),
    Zona("toggleizq", "Toggle panel izq.", "P1", "toggleizq"),
    Zona("toggleder", "Toggle panel der.", "P2", "toggleder"),
    Zona("zonasegura", "Zona segura cursor", "P29", "zonasegura"),
    # Deslizadores
    Zona("estab", "Deslizador de estabilización", "SL", "estab"),
    Zona("estabfoco", "Deslizador de enfoque (Shift+E)", "SL", "estabfoco"),
    # Avisos HUD
    Zona("hud_alta", "Aviso HUD · Zona 1 (Alta)", "HUD", "hud_alta"),
    Zona("hud_media", "Aviso HUD · Zona 2 (Media)", "HUD", "hud_media"),
    Zona("hud_baja", "Aviso HUD · Zona 3 (Baja)", "HUD", "hud_baja"),
    # Nuevas Ventanas / Lienzos auxiliares (NvZona 1-3)
    Zona("nvzona1", "Nueva ventana 1", "NV", "nvzona1"),
    Zona("nvzona2", "Nueva ventana 2", "NV", "nvzona2"),
    Zona("nvzona3", "Nueva ventana 3", "NV", "nvzona3"),
)
SUFIJOS = ("x1", "y1", "x2", "y2")


def seccion(modo: int, perfil: str = "1") -> str:
    suf = "_Enfoque" if int(modo) == 2 else ""
    return f"Rangos{perfil}{suf}"


def claves(z: Zona) -> list[str]:
    return [z.prefijo]


def _int(txt: str) -> int:
    try:
        return int(float(str(txt).strip()))
    except ValueError:
        return 0


def leer(d: Draft, modo: int, z: Zona) -> tuple[int, int, int, int]:
    """(x, y, w, h) tal como está en el borrador/INI."""
    sec = seccion(modo, getattr(d, "perfil", "1"))
    pref = z.prefijo.removeprefix("HUD_ev_")

    if z.tipo == "EV":
        # Aviso HUD del evento: primero busca HUD_ev_<id> de 1 línea
        val = d.get_key(sec, f"HUD_ev_{pref}", None)
        if val is None:
            val = d.get_key(sec, pref, None)
        # Si no tiene clave HUD_ev_ fija, pero tiene zona espacial configurada (<pref>_x..h):
        if val is None and d.get_key(sec, f"{pref}_x", None) is not None:
            return (_int(d.get_key(sec, f"{pref}_x", "0")),
                    _int(d.get_key(sec, f"{pref}_y", "0")),
                    _int(d.get_key(sec, f"{pref}_w", "0")),
                    _int(d.get_key(sec, f"{pref}_h", "0")))
    else:
        # Zona espacial: 4 claves <id>_x.._h (formato 99b6c31); si no, línea "x,y,w,h"
        if d.get_key(sec, f"{pref}_x", None) is not None:
            return (_int(d.get_key(sec, f"{pref}_x", "0")),
                    _int(d.get_key(sec, f"{pref}_y", "0")),
                    _int(d.get_key(sec, f"{pref}_w", "0")),
                    _int(d.get_key(sec, f"{pref}_h", "0")))
        val = d.get_key(sec, z.prefijo, None)

    if val is not None and "," in str(val):
        partes = [p.strip() for p in str(val).split(",")]
        if len(partes) >= 4:
            return (_int(partes[0]), _int(partes[1]), _int(partes[2]), _int(partes[3]))
        elif len(partes) == 2:
            return (_int(partes[0]), _int(partes[1]), 0, 0)
    # Fallback si estuviera en 4 claves individuales
    if any(d.get_key(sec, f"{z.prefijo}_{s}", None) is not None for s in SUFIJOS):
        x1 = _int(d.get_key(sec, f"{z.prefijo}_x1", "0"))
        y1 = _int(d.get_key(sec, f"{z.prefijo}_y1", "0"))
        x2 = _int(d.get_key(sec, f"{z.prefijo}_x2", "0"))
        y2 = _int(d.get_key(sec, f"{z.prefijo}_y2", "0"))
        return (x1, y1, max(0, x2 - x1), max(0, y2 - y1))
    return (0, 0, 0, 0)


def escribir(d: Draft, modo: int, z: Zona, x: int, y: int, w: int, h: int) -> None:
    sec = seccion(modo, getattr(d, "perfil", "1"))
    pref = z.prefijo.removeprefix("HUD_ev_")
    # Si la zona ya existe como disparador espacial de 4 claves (<id>_x..h):
    if d.get_key(sec, f"{pref}_x", None) is not None:
        d.set_key(sec, f"{pref}_x", str(int(x)))
        d.set_key(sec, f"{pref}_y", str(int(y)))
        d.set_key(sec, f"{pref}_w", str(int(w)))
        d.set_key(sec, f"{pref}_h", str(int(h)))
        return

    if x == 0 and y == 0 and w == 0 and h == 0:
        d.set_key(sec, z.prefijo, "0,0,0,0", default="0,0,0,0")
    else:
        d.set_key(sec, z.prefijo, f"{int(x)},{int(y)},{int(w)},{int(h)}")


def configurada(r: tuple[int, int, int, int]) -> bool:
    return any(r) and (r[2] > 0 or r[3] > 0)


def contar(d: Draft, modo: int) -> int:
    return sum(1 for z in ZONAS if configurada(leer(d, modo, z)))


def a_ui(r) -> tuple[int, int, int, int]:
    """(x, y, w, h) para los campos de entrada de la UI."""
    return r[0], r[1], r[2], r[3]


# ── Descripción libre por zona (columna 2 de la tabla) ──────────────────
# Se guarda aparte de [Rangos] para no mezclar texto con las coordenadas que
# lee AHK: [ZonasDesc<perfil>] desc_<prefijo> = texto. Vacía por defecto.
def sec_desc(perfil: str = "1") -> str:
    return f"ZonasDesc{perfil}"


def clave_desc(z: Zona) -> str:
    return f"desc_{z.prefijo}"


def leer_desc(d: Draft, z: Zona) -> str:
    sec = sec_desc(getattr(d, "perfil", "1"))
    return str(d.get_key(sec, clave_desc(z), "") or "")


def escribir_desc(d: Draft, z: Zona, txt: str) -> None:
    """Normaliza espacios; un texto vacío deja la clave en blanco (no la borra)."""
    txt = " ".join(str(txt).split())
    d.set_key(sec_desc(getattr(d, "perfil", "1")), clave_desc(z), txt, default="")


def validar_celda(col: str, txt: str) -> int | None:
    """col ∈ x|y|w|h. None si es inválido."""
    try:
        v = int(str(txt).strip())
    except ValueError:
        return None
    if col in ("w", "h"):
        return v if 0 <= v <= COORD_HI - COORD_LO else None
    return v if COORD_LO <= v <= COORD_HI else None


def _ids_custom(d: Draft) -> list[str]:
    """IDs de [EventosCustom] según lista=custom_1,custom_2,... (orden preservado)."""
    if not hasattr(d, "store"):
        return []
    try:
        raw = d.store.get("EventosCustom", "lista", "") or ""
    except Exception:
        return []
    return [c.strip() for c in str(raw).split(",") if c.strip()]


def _nombre_evento(d: Draft, catalogo, ev_id: str) -> str:
    """Nombre real del evento: catálogo -> [EventosCustom] -> [HudTextos] -> 'Evento: <id>'."""
    if catalogo and hasattr(catalogo, "por_id"):
        try:
            ev = catalogo.por_id(ev_id)
        except Exception:
            ev = None
        if ev and getattr(ev, "nombre", ""):
            return ev.nombre
    if hasattr(d, "store"):
        try:
            custom_raw = d.store.get("EventosCustom", ev_id, "") or ""
        except Exception:
            custom_raw = ""
        nom = str(custom_raw).partition("|")[0].strip()
        if nom:
            return nom
        try:
            p = getattr(d, "perfil", "1")
            nom_hud = d.store.get(f"HudTextos{p}", f"texto_{ev_id}", "").strip()
            if nom_hud:
                return nom_hud
        except Exception:
            pass
    return f"Evento: {ev_id}"


def _ids_catalogo(catalogo) -> list[str]:
    """IDs de todos los eventos del catálogo (acepta dict id->evento o iterable)."""
    if not catalogo:
        return []
    try:
        fuente = catalogo.values() if hasattr(catalogo, "values") else catalogo
        salida: list[str] = []
        for e in fuente:
            cid = e.get("id") if isinstance(e, dict) else getattr(e, "id", None)
            if cid and str(cid) not in salida:
                salida.append(str(cid))
        return salida
    except Exception:
        return []


def obtener_todas_zonas(d: Draft, modo: int, catalogo=None) -> list[Zona]:
    """Zonas fijas + HUD_ev_* persistidas + eventos de [EventosCustom] (aunque aún no tengan zona)."""
    resultado = list(ZONAS)
    p = getattr(d, "perfil", "1")
    sec = seccion(modo, p)
    prefijos_vistos = {z.prefijo for z in ZONAS}
    try:
        keys_sec = d.store.keys(sec) if hasattr(d, "store") else []
    except Exception:
        keys_sec = []

    ids: list[str] = []
    for k in keys_sec:
        if k.startswith("HUD_ev_"):
            ids.append(k[7:])
        elif k.endswith("_x"):
            cid = k[:-2]
            if cid not in ids:
                ids.append(cid)

    candidatas: list[tuple[str, str, str]] = []  # (ev_id, nombre, prefijo)
    cuenta: dict[str, int] = {}
    for ev_id in ids:
        prefijo = f"HUD_ev_{ev_id}"
        if prefijo in prefijos_vistos:
            continue
        prefijos_vistos.add(prefijo)
        nom = _nombre_evento(d, catalogo, ev_id)
        cuenta[nom] = cuenta.get(nom, 0) + 1
        candidatas.append((ev_id, nom, prefijo))

    for ev_id, nom, prefijo in candidatas:
        nom_final = f"{nom} ({ev_id})" if cuenta.get(nom, 0) > 1 else nom
        resultado.append(Zona(id=f"ev_{ev_id}", nombre=nom_final, tipo="EV", prefijo=prefijo))

    return resultado


def editar_celda(d: Draft, modo: int, z: Zona, col: str, v: int) -> None:
    x, y, w, h = leer(d, modo, z)
    x, y, w, h = {"x": (v, y, w, h), "y": (x, v, w, h), "w": (x, y, v, h), "h": (x, y, w, v)}[col]
    escribir(d, modo, z, x, y, w, h)


def desplazar_todas(d: Draft, modo: int, dx: int, dy: int) -> int:
    """Δ sobre todas las zonas configuradas. Devuelve cuántas movió."""
    n = 0
    for z in ZONAS:
        r = leer(d, modo, z)
        if configurada(r):
            escribir(d, modo, z, r[0] + dx, r[1] + dy, r[2], r[3])
            n += 1
    return n


def por_defecto(d: Draft, modo: int, zonas=ZONAS) -> None:
    """Vuelve a «sin configurar» (0,0,0,0)."""
    for z in zonas:
        escribir(d, modo, z, 0, 0, 0, 0)


def descartar(d: Draft, modo: int, z: Zona) -> None:
    sec = seccion(modo, getattr(d, "perfil", "1"))
    d.discard_key(sec, z.prefijo)
    for s in SUFIJOS:
        d.discard_key(sec, f"{z.prefijo}_{s}")
