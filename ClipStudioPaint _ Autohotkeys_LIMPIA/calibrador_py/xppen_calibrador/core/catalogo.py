"""Catálogo de eventos: AHK es dueño de ids/nombres/grupos (data/catalogo.json).
Si el JSON no existe se reconstruye desde el INI (modo degradado)."""
from __future__ import annotations
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from .ini_store import IniFile

_RE_ID_CUSTOM = re.compile(r"^(custom|nuevo_evento)_\d+$")


def es_id_custom(eid: str, claves_ini=()) -> bool:
    """Borrable si sigue el patrón dinámico o está declarado en [EventosCustom]."""
    return bool(_RE_ID_CUSTOM.match(eid)) or eid in claves_ini


_PART_KEY = re.compile(r"^(?:pildora|cruzar|auto|hover|quick|toggle)_(.+)$", re.I)
_SUFIJOS = ("tam_", "color_", "op_rep_", "op_act_", "borde_", "ms_", "a_", "b_")
GRUPO_CUSTOM = "Personalizados"

_KNOWN_PREFIXES = (
    "cruzar_", "auto_", "hover_", "toggle_", "pildora_", "tam_", "color_",
    "op_rep_", "op_act_", "borde_", "ms_", "a_", "b_", "formato_", "zona_",
    "opacidad_", "texto_", "atajo_", "HUD_ev_", "sonido_"
)
_KNOWN_SUFFIXES = ("_x", "_y", "_w", "_h", "_punto")


def clave_pertenece_a_evento(key: str, eid: str) -> bool:
    if key == eid:
        return True
    for pfx in _KNOWN_PREFIXES:
        if key.startswith(pfx) and key[len(pfx):] == eid:
            return True
    for sfx in _KNOWN_SUFFIXES:
        if key.endswith(sfx) and key[:-len(sfx)] == eid:
            return True
    return False

ATAJO_DEFAULTS: dict[str, str] = {}

REMAP_DEFAULTS: dict[str, str] = {}


@dataclass
class Evento:
    id: str
    nombre: str
    grupo: str
    atajo_def: str = ""
    remap_def: str = ""
    bloques: dict = field(default_factory=dict)     # {"espacial": bool, "tecla": bool, "ventanas": bool}
    custom: bool = False
    pausado: bool = False

    def tiene(self, bloque: str) -> bool:
        if bloque == "slider":
            return self.id == "estab_slider" or bool(self.bloques.get("slider"))
        return bool(self.bloques.get(bloque, True))


class Catalogo:
    def __init__(self, store: IniFile, data_dir: Path, json_path: Path | None = None):
        self.store = store
        self.json_path = Path(json_path) if json_path else (Path(data_dir) / "catalogo.json")
        self.eventos: list[Evento] = []
        self.origen = "json"
        self._json_explicito = json_path is not None

    def load(self) -> "Catalogo":
        try:
            claves_ini = {k for k in self.store.keys("EventosCustom") if k != "lista"}
        except Exception:
            claves_ini = set()
        try:
            eliminados = {k for k in self.store.keys("EventosEliminados") if k != "lista"}
            lista_elim = self.store.get("EventosEliminados", "lista", "") or ""
            for el in [x.strip() for x in lista_elim.split(",") if x.strip()]:
                eliminados.add(el)
        except Exception:
            eliminados = set()
        evs: dict[str, Evento] = {}
        json_cargado = False
        if self.json_path.exists():
            try:
                data = json.loads(self.json_path.read_text(encoding="utf-8-sig"))
                for e in data.get("eventos", []):
                    eid = e["id"]
                    if eid in eliminados:
                        continue
                    at = e.get("atajo") or ATAJO_DEFAULTS.get(eid, "")
                    rm = e.get("remap") or REMAP_DEFAULTS.get(eid, "")
                    es_cust = es_id_custom(eid, claves_ini)
                    grp = (e.get("grupo") or "").strip() or (GRUPO_CUSTOM if es_cust else "Otros")
                    evs[eid] = Evento(eid, e.get("nombre", eid), grp,
                                      at, rm, e.get("bloques", {}), custom=es_cust)
                json_cargado = True
            except (OSError, ValueError, KeyError):
                evs = {}
        if not json_cargado and not self._json_explicito:
            self.origen = "ini"
            for k in self.store.keys("Particularidades"):
                m = _PART_KEY.match(k)
                if m and not m.group(1).startswith(_SUFIJOS):
                    eid = m.group(1)
                    if eid not in eliminados:
                        evs.setdefault(eid, Evento(eid, eid.replace("_", " ").title(), "Eventos"))
            if "estab_slider" not in eliminados:
                evs.setdefault("estab_slider", Evento("estab_slider", "Deslizador de Estabilización", "Herramientas de Precisión"))
        lista = self.store.get("EventosCustom", "lista", "") or ""
        for cid in [c.strip() for c in lista.split(",") if c.strip()]:
            if cid in eliminados:
                continue
            nombre, _, grp_raw = (self.store.get("EventosCustom", cid, "") or cid).partition("|")
            grp_custom = ((self.store.get("EventosGrupo", cid) or "").strip()
                          or grp_raw.strip() or GRUPO_CUSTOM)
            atajo = (self.store.get("Remapeos", "atajo_" + cid, "") or "").strip()
            evs[cid] = Evento(cid, nombre or cid, grp_custom, atajo, custom=True)
        # Aplicar reasignaciones de grupo y estado de pausa desde el INI
        for eid, ev in list(evs.items()):
            if eid in eliminados:
                del evs[eid]
                continue
            grp_ini = (self.store.get("EventosGrupo", eid) or "").strip()
            if grp_ini:
                ev.grupo = grp_ini
            ev.pausado = (self.store.get("EventosPausados", eid, "0") == "1")
        self.eventos = list(evs.values())
        return self

    def eliminar_eventos(self, eids: list[str]) -> None:
        """Elimina uno o más eventos (custom o de fábrica), purgando claves en cascada en INI y catalogo.json."""
        if not eids:
            return
        eids_set = set(eids)

        # 1. Actualizar [EventosEliminados]
        lista_elim = [c for c in (self.store.get("EventosEliminados", "lista", "") or "").split(",") if c.strip()]
        for eid in eids:
            if eid not in lista_elim:
                lista_elim.append(eid)
        patches: list[tuple[str, str, str | None]] = [
            ("EventosEliminados", "lista", ",".join(lista_elim))
        ]
        for eid in eids:
            patches.append(("EventosEliminados", eid, "1"))

        # 2. Quitar de [EventosCustom] si aplica
        lista_custom = [c for c in (self.store.get("EventosCustom", "lista", "") or "").split(",") if c.strip()]
        lista_custom_nueva = [c for c in lista_custom if c not in eids_set]
        if len(lista_custom_nueva) != len(lista_custom):
            patches.append(("EventosCustom", "lista", ",".join(lista_custom_nueva)))
        for eid in eids:
            patches.append(("EventosCustom", eid, None))

        # 3. Purgar metadatos conocidos
        for eid in eids:
            patches.append(("EventosPausados", eid, None))
            patches.append(("EventosGrupo", eid, None))
            patches.append(("EventosPendientes", eid, None))
            patches.append(("Remapeos", f"atajo_{eid}", None))

        # 4. Purgar en cascada claves huérfanas en todas las secciones pertinentes
        sec_afectadas = [
            s for s in self.store.sections()
            if s.startswith(("Rangos", "Puntos", "HudTextos", "HudEventos", "HudSonido", "HudDuracion", "Particularidades", "ZonasEstado"))
        ]
        for sec in sec_afectadas:
            for k in self.store.keys(sec):
                for eid in eids:
                    if clave_pertenece_a_evento(k, eid):
                        patches.append((sec, k, None))
                        break

        # Guardar parches en el INI
        self.store.save_patches(patches)

        # 5. Sincronizar data/catalogo.json removiendo los eventos eliminados
        if self.json_path.exists():
            try:
                data = json.loads(self.json_path.read_text(encoding="utf-8-sig"))
                evs_json = data.get("eventos", [])
                evs_filtrados = [e for e in evs_json if e.get("id") not in eids_set]
                if len(evs_filtrados) != len(evs_json):
                    data["eventos"] = evs_filtrados
                    self.json_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            except Exception:
                pass

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
        if getattr(self, "store", None):
            try:
                ini_list = [c.strip() for c in (self.store.get("EventosCustom", "lista", "") or "").split(",") if c.strip()]
                usados.update(ini_list)
            except Exception:
                pass
        n = 1
        while f"custom_{n}" in usados:
            n += 1
        return f"custom_{n}", f"Nuevo evento {n}"

    def renombrar_custom(self, eid: str, nuevo: str) -> bool:
        nuevo = (nuevo or "").strip()
        if not nuevo or len(nuevo) > 60 or any(c in nuevo for c in "|\r\n"):
            return False
        ev = self.por_id(eid)
        if ev is None or not ev.custom:
            return False
        grp = (self.store.get("EventosCustom", eid, "") or "").partition("|")[2] or GRUPO_CUSTOM
        self.store.save_patches([("EventosCustom", eid, f"{nuevo}|{grp}")])
        self.load()
        return True
