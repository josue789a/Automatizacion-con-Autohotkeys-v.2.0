"""Suite de blindaje y contrato: evita regresiones en persistencia dual y coordenadas multimonitor."""
from __future__ import annotations
import tempfile
from pathlib import Path
import pytest
from xppen_calibrador.core.ini_store import IniFile
from xppen_calibrador.core.draft import Draft
from xppen_calibrador.core import zonas as Z


@pytest.fixture
def store_temporal():
    with tempfile.NamedTemporaryFile("w+", delete=False, suffix=".ini", encoding="utf-8") as f:
        f.write(
            "[Rangos2]\n"
            "custom_5_x = -2227\n"
            "custom_5_y = -4\n"
            "custom_5_w = 261\n"
            "custom_5_h = 277\n"
            "HUD_ev_borrador_lazo = -1500,200,300,50\n"
            "[EventosCustom]\n"
            "lista = custom_1,custom_5\n"
            "custom_5 = Nuevo evento 5|\n"
        )
        p = Path(f.name)
    st = IniFile(p).load()
    yield st, p
    p.unlink(missing_ok=True)


def test_lectura_zona_espacial_multimonitor(store_temporal):
    st, _ = store_temporal
    d = Draft(st, "2")
    todas = Z.obtener_todas_zonas(d, 1)
    z_c5 = next((z for z in todas if z.id == "ev_custom_5"), None)
    assert z_c5 is not None, "ev_custom_5 debe ser detectado en la lista de zonas"

    # La lectura debe rescatar las 4 claves espaciales aunque el objeto sea tipo 'EV'
    r = Z.leer(d, 1, z_c5)
    assert r == (-2227, -4, 261, 277), f"Coordenadas leídas incorrectas: {r}"


def test_escritura_preserva_esquema_espacial(store_temporal):
    st, _ = store_temporal
    d = Draft(st, "2")
    todas = Z.obtener_todas_zonas(d, 1)
    z_c5 = next(z for z in todas if z.id == "ev_custom_5")

    # Modificar ancho mediante editar_celda
    Z.editar_celda(d, 1, z_c5, "w", 350)
    assert Z.leer(d, 1, z_c5) == (-2227, -4, 350, 277)

    # Debe haber actualizado las 4 claves en el borrador y no una línea HUD_ev_custom_5
    sec = "Rangos2"
    assert d.get_key(sec, "custom_5_w", None) == "350"
    assert d.get_key(sec, "HUD_ev_custom_5", None) is None


def test_discriminacion_hud_de_una_linea(store_temporal):
    st, _ = store_temporal
    d = Draft(st, "2")
    todas = Z.obtener_todas_zonas(d, 1)
    z_lazo = next((z for z in todas if "borrador_lazo" in z.id), None)
    assert z_lazo is not None, "HUD_ev_borrador_lazo debe ser detectado"

    r = Z.leer(d, 1, z_lazo)
    assert r == (-1500, 200, 300, 50)
