"""Borrador de cambios: solo las claves sucias se parchean en el INI."""
from __future__ import annotations
from .ini_schema import FIELDS, to_ui, to_ini
from .ini_store import IniFile


class Draft:
    def __init__(self, store: IniFile, perfil: str):
        self.store, self.perfil = store, str(perfil)
        self.pending: dict[tuple[str, str], tuple[str, str, str]] = {}   # (sec_l, key_l) → (sec, key, val)

    def resolve(self, name: str, id_ev: str) -> tuple[str, str]:
        f = FIELDS[name]
        key = f.key.format(id=id_ev)
        if f.section == "@auto":
            sec = self.store.find_section_of(key)
            if sec:
                return sec, key
            fb = f.fallback.format(p=self.perfil) if "{p}" in f.fallback else f.fallback
            return fb, key
        return f.section.format(p=self.perfil), key

    def _default_raw(self, name: str, sec: str, key: str, id_ev: str) -> str | None:
        if id_ev and sec.lower().startswith("particularidades"):
            from .particularidades_defaults import particularidad_default
            sufijo = "_" + id_ev.lower()
            k = key.lower()
            campo = k[:-len(sufijo)] if k.endswith(sufijo) else name
            dv = particularidad_default(id_ev, campo)
            if dv is None:
                dv = particularidad_default(id_ev, name)
            if dv is not None:
                return str(dv)
        return None

    def _stored(self, name: str, sec: str, key: str, id_ev: str = "") -> str:
        raw = self.store.get(sec, key)
        if raw is None and id_ev:
            raw = self._default_raw(name, sec, key, id_ev)
        return to_ini(name, to_ui(name, raw)) or ""

    def get(self, name: str, id_ev: str):
        sec, key = self.resolve(name, id_ev)
        hit = self.pending.get((sec.lower(), key.lower()))
        raw = hit[2] if hit else self.store.get(sec, key)
        if raw is None and id_ev:
            dv = self._default_raw(name, sec, key, id_ev)
            if dv is not None:
                raw = dv
        return to_ui(name, raw)

    def set(self, name: str, id_ev: str, value) -> bool:
        """False si el valor es inválido (no se registra)."""
        val = to_ini(name, value)
        if val is None:
            return False
        sec, key = self.resolve(name, id_ev)
        k = (sec.lower(), key.lower())
        if val == self._stored(name, sec, key, id_ev):
            self.pending.pop(k, None)
        else:
            self.pending[k] = (sec, key, val)
        return True

    # ── claves dinámicas (zonas, temas…): mismo borrador, sin pasar por FIELDS ──
    def get_key(self, sec: str, key: str, default: str = "") -> str:
        hit = self.pending.get((sec.lower(), key.lower()))
        if hit:
            return hit[2]
        raw = self.store.get(sec, key)
        return default if raw is None else raw

    def set_key(self, sec: str, key: str, val, default: str | None = None) -> None:
        """Registra el cambio; si equivale a lo guardado (o al `default` de una clave ausente) lo descarta."""
        val = str(val).strip()
        k = (sec.lower(), key.lower())
        stored = self.store.get(sec, key)
        eff = default if stored is None else stored
        if eff is not None and eff.strip() == val:
            self.pending.pop(k, None)
        else:
            self.pending[k] = (sec, key, val)

    def discard_key(self, sec: str, key: str) -> None:
        self.pending.pop((sec.lower(), key.lower()), None)

    @property
    def count(self) -> int:
        return len(self.pending)

    def patches(self) -> list[tuple[str, str, str]]:
        return list(self.pending.values())

    def clear(self) -> None:
        self.pending.clear()
