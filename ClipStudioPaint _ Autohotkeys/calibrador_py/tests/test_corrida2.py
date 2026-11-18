"""Corrida 2: Draft por clave, zonas, temas, backups y las 3 pestañas nuevas (UI solo si hay pantalla)."""
import shutil, sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pytest
from xppen_calibrador.core import temas as TM
from xppen_calibrador.core import zonas as Z
from xppen_calibrador.core.draft import Draft
from xppen_calibrador.core.ini_schema import FIELDS, to_ini, to_ui
from xppen_calibrador.core.ini_store import IniFile

G = Path(__file__).parent / "golden"
DATA = Path(__file__).resolve().parents[1] / "data"


@pytest.fixture(params=["posiciones_gui_utf16.ini", "posiciones_gui_ansi.ini"])
def ini(tmp_path, request):
    p = tmp_path / "posiciones_gui.ini"
    shutil.copy(G / request.param, p)
    return p


@pytest.fixture
def theme(tmp_path):
    p = tmp_path / "theme.ini"
    shutil.copy(G / "theme.ini", p)
    return p


# ── Draft por clave ────────────────────────────────────────
def test_draft_key_sucio_y_limpio(ini):
    st = IniFile(ini).load(); d = Draft(st, "1")
    d.set_key("Estab_p1", "paso", "9")
    assert d.count == 1 and d.get_key("Estab_p1", "paso") == "9"
    d.set_key("Estab_p1", "paso", "5")                       # vuelve al valor guardado → ya no está sucio
    assert d.count == 0


def test_draft_key_ausente_con_default_no_ensucia(ini):
    d = Draft(IniFile(ini).load(), "1")
    d.set_key("Rangos1", "p1_x1", 0, default="0")
    assert d.count == 0
    d.set_key("Rangos1", "p1_x1", 5, default="0")
    assert d.count == 1


# ── zonas ──────────────────────────────────────────────────
def test_zonas_guardar_y_leer(ini):
    st = IniFile(ini).load(); d = Draft(st, "1"); z = Z.ZONAS[0]
    Z.editar_celda(d, 1, z, "x", 35); Z.editar_celda(d, 1, z, "w", 820); Z.editar_celda(d, 1, z, "h", 70)
    assert Z.contar(d, 1) == 1 and Z.contar(d, 2) == 0
    st.save_patches(d.patches()); d.clear()
    st2 = IniFile(ini).load()
    assert st2.get("Rangos1", z.prefijo) == "35,0,820,70"
    assert Z.leer(Draft(st2, "1"), 1, z) == (35, 0, 820, 70)
    assert Z.a_ui(Z.leer(Draft(st2, "1"), 1, z)) == (35, 0, 820, 70)


def test_zonas_delta_solo_configuradas_y_por_defecto(ini):
    st = IniFile(ini).load(); d = Draft(st, "1")
    Z.escribir(d, 1, Z.ZONAS[0], 10, 10, 110, 60)
    assert Z.desplazar_todas(d, 1, 5, -3) == 1
    assert Z.leer(d, 1, Z.ZONAS[0]) == (15, 7, 110, 60) and Z.leer(d, 1, Z.ZONAS[1]) == (0, 0, 0, 0)
    Z.por_defecto(d, 1)
    assert Z.contar(d, 1) == 0


def test_zonas_validacion():
    assert Z.validar_celda("x", "-2118") == -2118
    assert Z.validar_celda("w", "-1") is None and Z.validar_celda("x", "abc") is None and Z.validar_celda("h", "70") == 70


# ── temas ──────────────────────────────────────────────────
def test_15_temas_con_5_swatches():
    t = TM.cargar(DATA)
    assert len(t) == 15 and all(len(x.swatches) == 5 for x in t) and len(TM.muestras(t[0])) == 8


def test_tema_activo_detectado_del_theme_ini_real(theme):
    t = TM.cargar(DATA); i = TM.activo(IniFile(theme).load(), t)
    assert t[i].nombre.startswith("13.")


def test_aplicar_tema_cambia_solo_sus_6_lineas(theme):
    t = TM.cargar(DATA); st = IniFile(theme).load(); antes = st.lines[:]
    st.save_patches(TM.parches(t[2]))                          # «3. Slate Blue»
    despues = IniFile(theme).load().lines
    cambiadas = [(a, b) for a, b in zip(antes, despues) if a != b]
    assert len(antes) == len(despues) and len(cambiadas) == 6
    assert TM.activo(IniFile(theme).load(), t) == 2


# ── backups y esquema ──────────────────────────────────────
def test_backup_manual_y_restaurar(ini):
    f = IniFile(ini).load(); orig = ini.read_bytes()
    assert f.backups() == []
    f.backup_now()
    f.save_patches([("NvConfig", "modo", "total")])
    assert ini.read_bytes() != orig
    f.restore_last()
    assert ini.read_bytes() == orig


def test_campos_sistema_roundtrip():
    assert to_ini("escala_botones", "70") == "70" and to_ini("escala_botones", "10") is None
    assert to_ui("pil_bloquear", None) == 0 and to_ui("acc_frente", None) == 1
    assert to_ini("pil_slider", 1) == "1" and "acc_estabilizador" in FIELDS


# ── UI (necesita pantalla; xvfb-run en CI) ─────────────────
@pytest.fixture
def app(tmp_path):
    ctk = pytest.importorskip("customtkinter")
    p = tmp_path / "posiciones_gui.ini"
    shutil.copy(G / "posiciones_gui_utf16.ini", p); shutil.copy(G / "theme.ini", tmp_path / "theme.ini")
    try:
        from xppen_calibrador.app import CalibradorApp
        a = CalibradorApp(p)
    except Exception as e:                                       # sin DISPLAY o colisión de Tcl
        if "display" in str(e).lower() or "tcl" in str(e).lower():
            pytest.skip(f"UI test saltado: {e}")
        raise
    yield a
    a.destroy()


def test_ui_edicion_de_celda_y_footer(app):
    app.show_tab(1); app.update()
    zt = app.page_tabs[0]; z = Z.ZONAS[0]
    e = zt.rows[z.id]["ents"]["w"]; e.delete(0, "end"); e.insert(0, "820"); zt._commit(z, "w")
    assert app.draft.count == 1 and "sin guardar" in app.footer.info.cget("text")
    e.delete(0, "end"); e.insert(0, "-5"); zt._commit(z, "w")
    assert app.draft.count == 1 and e.cget("border_color") != "#EBEBF0"       # inválido: no registra


def test_ui_sistema_guarda_checks_y_escalas(app):
    st = app.page_tabs[1]
    st.pil.vars["bloquear"].set(1); st.pil._click("bloquear", st.pil.vars["bloquear"])
    st.perfil.ents["escala_botones"].delete(0, "end"); st.perfil.ents["escala_botones"].insert(0, "85"); st.perfil._commit("escala_botones")
    assert app.draft.count == 2 and app.save()
    s = IniFile(app.store.path).load()
    assert s.get("Pildoras_p1", "bloquear") == "1" and s.get("Escalas_p1", "botones") == "85"


def test_ui_temas_aplicar_escribe_theme_ini(app):
    tt = app.page_tabs[2]; tt.select(5); tt._aplicar()
    assert TM.activo(IniFile(app.theme_store.path).load(), tt.temas) == 5
    assert "6." in tt.card.title.cget("text")


def test_ui_cadena_de_zonas_con_ahk_simulado(app):
    zt = app.page_tabs[0]; app.show_tab(1)

    class Fake:
        conectado = True
        def __init__(self): self.sent = []
        def send(self, cmd, *a):
            self.sent.append((cmd, *a))
            if cmd == "DRAW_ZONE":                               # AHK «dibuja» y escribe el INI
                z = next(x for x in Z.ZONAS if x.prefijo == a[0])
                IniFile(app.store.path).save_patches([("Rangos1", z.prefijo, "1,2,30,40")])
            return True
    app.tc.bridge = Fake()
    zt.select(Z.ZONAS[-2].id); zt._cadena()
    t0 = time.time()
    while zt._chain and time.time() - t0 < 6:
        app.update(); time.sleep(.05)
    assert zt._chain is None and [s[1] for s in app.tc.bridge.sent if s[0] == "DRAW_ZONE"] == [Z.ZONAS[-2].prefijo, Z.ZONAS[-1].prefijo]
    assert Z.contar(app.draft, 1) == 2
