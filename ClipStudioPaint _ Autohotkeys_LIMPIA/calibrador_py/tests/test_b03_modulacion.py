"""Pruebas unitarias para la modulación de tecla B03 y letra por defecto."""
import pytest
from xppen_calibrador.core.ini_store import IniFile
from xppen_calibrador.core.draft import Draft
from xppen_calibrador.core.catalogo import Catalogo, Evento
from xppen_calibrador.ui.blocks import B03Modulacion


class DummyApp:
    def __init__(self, draft, catalogo):
        self.draft = draft
        self.catalogo = catalogo
        self.event_id = "aerografo"
        self.blocks = []

    def get(self, name):
        return self.draft.get(name, self.event_id)

    def set(self, name, val):
        return self.draft.set(name, self.event_id, val)

    def explicito(self, name):
        return self.draft.explicito(name, self.event_id)

    def refresh_all(self):
        for b in self.blocks:
            b.refresh()


def test_b03_master_on_requiere_tecla_b(tmp_path):
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Particularidades]\nquick_aerografo=1\nquick_b_aerografo=\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    draft = Draft(store, "1")
    cat = Catalogo(ini_path, tmp_path / "cat.json")
    ev = Evento(id="aerografo", nombre="Aerógrafo", grupo="Pinceles", atajo_def="W")
    cat.eventos = [ev]

    app = DummyApp(draft, cat)
    b03 = B03Modulacion(None, app, lambda _b: None)
    app.blocks.append(b03)

    # Con quick_b vacío, master_on debe ser False
    assert not b03.master_on()

    # Si se asigna quick_b, master_on se vuelve True
    app.set("quick_b", "K")
    assert b03.master_on()

    # Si se vacía quick_b, master_on vuelve a ser False
    app.set("quick_b", "")
    assert not b03.master_on()


def test_b03_tecla_base_fallback(tmp_path):
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Remapeos]\natajo_aerografo=W\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    draft = Draft(store, "1")
    cat = Catalogo(ini_path, tmp_path / "cat.json")
    ev = Evento(id="aerografo", nombre="Aerógrafo", grupo="Pinceles", atajo_def="W")
    cat.eventos = [ev]

    app = DummyApp(draft, cat)
    b03 = B03Modulacion(None, app, lambda _b: None)

    # La tecla base debe resolver a W
    assert b03._tecla_base() == "W"


def test_b03_uncheck_al_vaciar_b(tmp_path):
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Particularidades]\nquick_aerografo=1\nquick_b_aerografo=K\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    draft = Draft(store, "1")
    cat = Catalogo(ini_path, tmp_path / "cat.json")
    ev = Evento(id="aerografo", nombre="Aerógrafo", grupo="Pinceles", atajo_def="W")
    cat.eventos = [ev]

    app = DummyApp(draft, cat)
    b03 = B03Modulacion(None, app, lambda _b: None)
    app.blocks.append(b03)

    assert b03.master_on()

    # Simulamos el callback de vaciado que dispara f_key_entry
    b03._on_key_commit("quick_b", "")

    # Debe haber desmarcado quick a 0 en el draft
    assert app.get("quick") == 0
    # Y master_on debe apagarse
    assert not b03.master_on()

