"""Lectura y escritura segura de posiciones_gui.ini.

- Modelo de líneas: todo lo que no se parchea se conserva byte a byte
  (comentarios, orden, mayúsculas, secciones ajenas, claves desconocidas).
- Codificación por BOM (UTF-16 LE / UTF-8 BOM / ANSI) y saltos de línea originales.
- Escritura atómica: tmp en el mismo directorio + os.replace, con comparar-y-reemplazar.
- Claves y secciones se comparan sin distinguir mayúsculas (igual que IniRead).
"""
from __future__ import annotations
import os
import re
import shutil
import time
from datetime import datetime
from pathlib import Path

_SEC = re.compile(r"^\s*\[([^\]]*)\]\s*$")
_PREFIX = re.compile(r"^(\s*[^=;\[][^=]*=\s*)")


class IniFile:
    def __init__(self, path: str | os.PathLike):
        self.path = Path(path)
        self.lines: list[str] = []
        self.encoding = "utf-16"
        self.bom = b""
        self.eol = "\r\n"
        self.trailing_eol = True
        self.signature: tuple | None = None
        self._backed_up = False

    # ── lectura ────────────────────────────────────────────
    def load(self) -> "IniFile":
        if not self.path.exists():
            self.lines, self.signature = [], None
            self.encoding, self.bom = "utf-16-le", b"\xff\xfe"
            return self
        data = self.path.read_bytes()
        st = self.path.stat()
        self.signature = (st.st_mtime_ns, st.st_size)
        if data.startswith(b"\xff\xfe"):
            self.encoding, self.bom, body = "utf-16-le", b"\xff\xfe", data[2:]
        elif data.startswith(b"\xfe\xff"):
            self.encoding, self.bom, body = "utf-16-be", b"\xfe\xff", data[2:]
        elif data.startswith(b"\xef\xbb\xbf"):
            self.encoding, self.bom, body = "utf-8", b"\xef\xbb\xbf", data[3:]
        else:
            self.bom, body = b"", data
            try:
                body.decode("utf-8")
                self.encoding = "utf-8"
            except UnicodeDecodeError:
                self.encoding = "cp1252"
        text = body.decode(self.encoding, errors="surrogateescape" if self.encoding == "utf-8" else "strict")
        self.eol = "\r\n" if "\r\n" in text else ("\n" if "\n" in text else "\r\n")
        self.trailing_eol = text.endswith("\n") or text == ""
        self.lines = text.splitlines()
        return self

    # ── consulta ───────────────────────────────────────────
    def _locate(self, section: str, key: str):
        """(índice_línea_clave | None, inicio_sección | None, fin_sección)."""
        sec_l, key_l = section.lower(), key.lower()
        start = end = None
        for i, ln in enumerate(self.lines):
            m = _SEC.match(ln)
            if m:
                if start is not None:
                    end = i
                    break
                if m.group(1).strip().lower() == sec_l:
                    start = i
                continue
            if start is not None and ln.strip() and not ln.lstrip().startswith(";") and "=" in ln:
                if ln.split("=", 1)[0].strip().lower() == key_l:
                    return i, start, None
        if start is not None and end is None:
            end = len(self.lines)
        return None, start, end

    def get(self, section: str, key: str, default=None):
        idx, _, _ = self._locate(section, key)
        if idx is None:
            return default
        return self.lines[idx].split("=", 1)[1].strip()

    def find_section_of(self, key: str) -> str | None:
        """Primera sección donde existe `key` (para claves de ubicación incierta)."""
        key_l, cur = key.lower(), None
        for ln in self.lines:
            m = _SEC.match(ln)
            if m:
                cur = m.group(1).strip()
            elif cur and "=" in ln and not ln.lstrip().startswith(";"):
                if ln.split("=", 1)[0].strip().lower() == key_l:
                    return cur
        return None

    def sections(self) -> list[str]:
        return [m.group(1).strip() for ln in self.lines if (m := _SEC.match(ln))]

    def keys(self, section: str) -> list[str]:
        out, cur = [], None
        for ln in self.lines:
            m = _SEC.match(ln)
            if m:
                cur = m.group(1).strip().lower()
            elif cur == section.lower() and "=" in ln and not ln.lstrip().startswith(";"):
                out.append(ln.split("=", 1)[0].strip())
        return out

    # ── parcheo en memoria ─────────────────────────────────
    def set(self, section: str, key: str, value: str) -> None:
        value = "" if value is None else str(value).replace("\r", " ").replace("\n", " ")
        idx, start, end = self._locate(section, key)
        if idx is not None:
            m = _PREFIX.match(self.lines[idx])
            prefix = m.group(1) if m else f"{key}="
            self.lines[idx] = prefix + value
            return
        new = f"{key}={value}"
        if start is None:                       # sección nueva al final
            if self.lines and self.lines[-1].strip():
                self.lines.append("")
            self.lines += [f"[{section}]", new]
            return
        pos = end                               # tras la última línea con contenido de la sección
        while pos > start + 1 and not self.lines[pos - 1].strip():
            pos -= 1
        self.lines.insert(pos, new)

    def delete(self, section: str, key: str) -> bool:
        """Elimina una clave si existe en la sección especificada."""
        idx, _, _ = self._locate(section, key)
        if idx is not None:
            del self.lines[idx]
            return True
        return False

    # ── serialización y guardado atómico ───────────────────
    def to_bytes(self) -> bytes:
        text = self.eol.join(self.lines) + (self.eol if self.trailing_eol and self.lines else "")
        enc = self.encoding
        return self.bom + text.encode(enc, errors="surrogateescape" if enc == "utf-8" else "strict")

    def _backup(self, keep: int = 5) -> None:
        if self._backed_up or not self.path.exists():
            return
        d = self.path.parent / "respaldos"
        try:
            d.mkdir(exist_ok=True)
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            shutil.copy2(self.path, d / f"{self.path.name}.{stamp}.bak")
            olds = sorted(d.glob(f"{self.path.name}.*.bak"))
            for o in olds[:-keep]:
                o.unlink(missing_ok=True)
            self._backed_up = True
        except OSError:
            pass

    # ── backups manuales (pestaña Sistema) ─────────────────
    @property
    def backup_dir(self) -> Path:
        return self.path.parent / "respaldos"

    def backups(self) -> list[Path]:
        d = self.backup_dir
        return sorted(d.glob(f"{self.path.name}.*.bak")) if d.exists() else []

    def backup_now(self, keep: int = 10) -> Path:
        """Copia el archivo ACTUAL en respaldos/ (independiente del respaldo automático de sesión)."""
        if not self.path.exists():
            raise OSError(f"{self.path.name} no existe")
        d = self.backup_dir
        d.mkdir(exist_ok=True)
        dst = d / f"{self.path.name}.{datetime.now().strftime('%Y%m%d-%H%M%S')}.bak"
        shutil.copy2(self.path, dst)
        for o in self.backups()[:-keep]:
            o.unlink(missing_ok=True)
        return dst

    def restore_last(self) -> Path:
        """Reemplaza el INI por el último .bak (atómico). Guarda antes el estado actual como 'prerestore'."""
        last = (self.backups() or [None])[-1]
        if last is None:
            raise OSError("Sin backups todavía")
        d = self.backup_dir
        if self.path.exists():
            shutil.copy2(self.path, d / f"{self.path.name}.prerestore-{datetime.now().strftime('%Y%m%d-%H%M%S')}")
        tmp = self.path.with_name(f"{self.path.name}.tmp-{os.getpid()}")
        shutil.copyfile(last, tmp)
        os.replace(tmp, self.path)
        self.load()
        return last

    def save_patches(self, patches: list[tuple[str, str, str | None]], retries: int = 6) -> None:
        """Aplica parches (sección, clave, valor) sobre el archivo ACTUAL y lo reemplaza atómicamente.
        Si valor es None, la clave es eliminada."""
        if not patches:
            return
        last_err: Exception | None = None
        for attempt in range(retries):
            self.load()                                   # siempre sobre lo último en disco
            for sec, key, val in patches:
                if val is None:
                    self.delete(sec, key)
                else:
                    self.set(sec, key, val)
            self._backup()
            tmp = self.path.with_name(f"{self.path.name}.tmp-{os.getpid()}")
            try:
                with open(tmp, "wb") as fh:
                    fh.write(self.to_bytes())
                    fh.flush()
                    os.fsync(fh.fileno())
                if self.path.exists():                    # comparar-y-reemplazar
                    st = self.path.stat()
                    if self.signature and (st.st_mtime_ns, st.st_size) != self.signature:
                        tmp.unlink(missing_ok=True)
                        time.sleep(0.04)
                        continue                          # AHK escribió entremedio: reintento
                os.replace(tmp, self.path)
                self.load()
                return
            except PermissionError as e:                  # AHK con el archivo abierto un instante
                last_err = e
                tmp.unlink(missing_ok=True)
                time.sleep(0.04 * (attempt + 1))
        raise OSError(f"No se pudo guardar {self.path.name}: {last_err or 'cambios concurrentes'}")
