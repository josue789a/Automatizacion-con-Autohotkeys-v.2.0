import shutil, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pytest
from xppen_calibrador.core.ini_store import IniFile

G = Path(__file__).parent / "golden"

@pytest.fixture(params=["posiciones_gui_utf16.ini", "posiciones_gui_ansi.ini"])
def ini(tmp_path, request):
    p = tmp_path / "posiciones_gui.ini"
    shutil.copy(G / request.param, p)
    return p

def test_roundtrip_identico(ini):
    orig = ini.read_bytes()
    f = IniFile(ini).load()
    assert f.to_bytes() == orig

def test_guardar_sin_parches_no_toca(ini):
    orig = ini.read_bytes(); IniFile(ini).load().save_patches([]); assert ini.read_bytes() == orig

def test_un_parche_cambia_solo_su_linea(ini):
    orig = IniFile(ini).load().lines[:]
    f = IniFile(ini); f.save_patches([("Particularidades", "pildora_tam_estab_slider", "140")])
    new = IniFile(ini).load().lines
    diff = [(a, b) for a, b in zip(orig, new) if a != b]
    assert diff == [("pildora_tam_estab_slider=100", "pildora_tam_estab_slider=140")] and len(orig) == len(new)

def test_bom_y_crlf_preservados(ini):
    before = ini.read_bytes()
    IniFile(ini).save_patches([("NvConfig", "modo", "total")])
    after = ini.read_bytes()
    assert after[:2] == before[:2] or before[:2] != b"\xff\xfe"
    assert after.count(b"\r\x00\n\x00") + after.count(b"\r\n") >= 10

def test_clave_nueva_va_al_final_de_su_seccion(ini):
    f = IniFile(ini); f.save_patches([("Particularidades", "hover_estab_slider", "1")])
    f.load(); L = f.lines
    i = L.index("hover_estab_slider=1")
    assert L[i-1] == "toggle_b_estab_slider=" and L[i+1] == ""

def test_seccion_nueva_y_claves_ajenas_intactas(ini):
    f = IniFile(ini); f.save_patches([("Avisos", "formato_x", "bruto")])
    f.load()
    assert f.get("Avisos", "formato_x") == "bruto"
    assert f.get("Estab_p1", "snaps") == "20,40,60,80,100"
    assert f.get("Posiciones", "x_panel") == "%100%"
    assert f.lines[0] == "; comentario del usuario"

def test_claves_sin_distinguir_mayusculas(ini):
    f = IniFile(ini); f.save_patches([("particularidades", "PILDORA_estab_slider", "0")])
    f.load(); assert f.get("Particularidades", "pildora_estab_slider") == "0"
    assert sum(1 for l in f.lines if l.lower().startswith("pildora_estab_slider")) == 1

def test_valor_vacio_se_conserva(ini):
    f = IniFile(ini).load(); assert f.get("Particularidades", "toggle_a_estab_slider") == ""

def test_find_section_of(ini):
    assert IniFile(ini).load().find_section_of("snaps") == "Estab_p1"

def test_cambio_externo_durante_guardado(ini, monkeypatch):
    f = IniFile(ini).load()
    # AHK escribe otra clave justo antes del reemplazo: el parche debe convivir con ella
    ext = IniFile(ini); ext.save_patches([("NvConfig", "modoGlobal", "h_off")])
    f.save_patches([("Estab_p1", "paso", "10")])
    g = IniFile(ini).load()
    assert g.get("NvConfig", "modoGlobal") == "h_off" and g.get("Estab_p1", "paso") == "10"

def test_respaldo_creado(ini):
    IniFile(ini).save_patches([("NvConfig", "modo", "total")])
    assert list((ini.parent / "respaldos").glob("*.bak"))
