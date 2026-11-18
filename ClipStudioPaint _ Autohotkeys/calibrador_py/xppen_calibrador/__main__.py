"""python -m xppen_calibrador --ini <posiciones_gui.ini> --perfil N --modo normal|enfoque --ahk-hwnd H"""
from __future__ import annotations
import argparse
import logging
import sys
import tempfile
from pathlib import Path


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="xppen_calibrador")
    ap.add_argument("--ini", required=True)
    ap.add_argument("--perfil", default="1")
    ap.add_argument("--modo", default="normal")
    ap.add_argument("--ahk-hwnd", type=int, default=0)
    ap.add_argument("--selftest", action="store_true", help="construye la ventana, la cierra y devuelve 0 si todo OK")
    ap.add_argument("--dump-schema", action="store_true", help="imprime dónde vive cada clave del contrato en el INI real")
    a = ap.parse_args(argv)

    logging.basicConfig(filename=str(Path(tempfile.gettempdir()) / "_calibrador_py.log"), level=logging.INFO,
                        format="%(asctime)s %(name)s %(levelname)s %(message)s", encoding="utf-8")
    if a.dump_schema:
        return dump_schema(a)

    from .core import single_instance
    if not a.selftest and not single_instance.adquirir():
        return 0
    try:
        from .app import CalibradorApp
        app = CalibradorApp(a.ini, a.perfil, a.modo, a.ahk_hwnd)
        if a.selftest:
            app.update_idletasks()
            app.update()
            app.destroy()
            print("SELFTEST OK")
            return 0
        app.mainloop()
        return 0
    except Exception:
        logging.getLogger("calibrador").exception("fallo fatal")
        raise


def dump_schema(a) -> int:
    from .core.catalogo import Catalogo
    from .core.draft import Draft
    from .core.ini_schema import FIELDS
    from .core.ini_store import IniFile
    from .app import DATA_DIR
    st = IniFile(a.ini).load()
    d = Draft(st, a.perfil)
    cat = Catalogo(st, DATA_DIR).load()
    print(f"INI: {st.path}  codificación={st.encoding} bom={st.bom!r} eol={st.eol!r}  catálogo={cat.origen} ({len(cat.eventos)} eventos)")
    ev = next((e.id for e in cat.eventos if e.id == "estab_slider"), cat.eventos[0].id if cat.eventos else "")
    for name, f in FIELDS.items():
        sec, key = d.resolve(name, "" if "{id}" not in f.key else ev)
        raw = st.get(sec, key)
        print(f"{name:14s} [{sec}] {key} = {raw!r}" + ("" if raw is not None else "   <-- NO EXISTE (se creará al guardar)"))
    # ── Corrida 2: zonas ([Rangos<modo>]) y theme.ini ──────────
    from .core import zonas as Z
    from .core import temas as TM
    for modo in Z.MODOS:
        sec = Z.seccion(modo)
        print(f"\n[{sec}] claves reales en el INI: {st.keys(sec) or '(sección inexistente)'}")
        for z in Z.ZONAS:
            vals = [st.get(sec, k) for k in Z.claves(z)]
            print(f"  zona {z.id:10s} {z.tipo} {', '.join(Z.claves(z))} = {vals!r}" + ("" if any(v is not None for v in vals) else "   <-- NO EXISTE"))
        print(f"  panel_csp      {Z.PANEL_CSP_KEY} = {st.get(sec, Z.PANEL_CSP_KEY)!r}")
    tpath = Path(a.ini).with_name("theme.ini")
    th = IniFile(tpath).load()
    temas = TM.cargar(Path(DATA_DIR))
    ap = TM.activo(th, temas)
    print(f"\ntheme.ini: {tpath}  existe={tpath.exists()}  tema activo={temas[ap].nombre if ap is not None else None}")
    for (sec, key) in (*TM.TOKENS, TM.META):
        print(f"  [{sec}] {key} = {th.get(sec, key)!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
