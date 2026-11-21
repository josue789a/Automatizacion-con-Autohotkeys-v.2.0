import pytest
from pathlib import Path
from xppen_calibrador.core.ini_store import IniFile
from xppen_calibrador.core.draft import Draft
import xppen_calibrador.core.zonas as Z


@pytest.fixture
def draft_vacio(tmp_path):
    ini = tmp_path / "test.ini"
    ini.write_text("[Rangos1]\n[EventosCustom]\n", encoding="utf-8")
    store = IniFile(ini).load()
    return Draft(store, "1")


def test_custom_sin_zona_aparece_en_tabla(draft_vacio):
    d = draft_vacio
    d.store.set("EventosCustom", "lista", "custom_1,custom_2")
    d.store.set("EventosCustom", "custom_1", "Nuevo evento 1|x")
    d.store.set("EventosCustom", "custom_2", "Nuevo evento 2|x")
    zs = Z.obtener_todas_zonas(d, 1)
    pref = {z.prefijo for z in zs}
    assert {"HUD_ev_custom_1", "HUD_ev_custom_2"} <= pref
    assert len(zs) == len(Z.ZONAS) + 2
    assert all(z.tipo == "EV" for z in zs[len(Z.ZONAS):])


def test_custom_no_duplica_si_ya_tiene_hud(draft_vacio):
    d = draft_vacio
    d.store.set("EventosCustom", "lista", "custom_1")
    d.store.set("EventosCustom", "custom_1", "Mi ev|x")
    d.store.set(Z.seccion(1, d.perfil), "HUD_ev_custom_1", "1,2,3,4")
    assert sum(z.prefijo == "HUD_ev_custom_1" for z in Z.obtener_todas_zonas(d, 1)) == 1


def test_desambiguacion_nombres_repetidos(draft_vacio):
    d = draft_vacio
    d.store.set("EventosCustom", "lista", "custom_1,custom_2")
    d.store.set("EventosCustom", "custom_1", "Nuevo evento|")
    d.store.set("EventosCustom", "custom_2", "Nuevo evento|")
    zs = Z.obtener_todas_zonas(d, 1)
    evs = [z for z in zs if z.tipo == "EV"]
    assert len(evs) == 2
    assert evs[0].nombre == "Nuevo evento (custom_1)"
    assert evs[1].nombre == "Nuevo evento (custom_2)"
