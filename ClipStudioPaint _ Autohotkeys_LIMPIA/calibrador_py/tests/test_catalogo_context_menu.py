import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pytest
from xppen_calibrador.core.ini_store import IniFile
from xppen_calibrador.core.catalogo import Catalogo

def test_pausar_activar_catalogo(tmp_path):
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Particularidades]\n[EventosPausados]\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    data_dir = Path(__file__).resolve().parents[1] / "data"
    cat = Catalogo(store, data_dir).load()

    borr = cat.por_id("borrador")
    assert borr is not None
    assert borr.pausado is False

    # Pausar evento
    store.save_patches([("EventosPausados", "borrador", "1")])
    cat.load()
    assert cat.por_id("borrador").pausado is True

    # Activar evento (eliminar clave)
    store.save_patches([("EventosPausados", "borrador", None)])
    cat.load()
    assert cat.por_id("borrador").pausado is False

def test_mover_grupo_catalogo(tmp_path):
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Particularidades]\n[EventosGrupo]\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    data_dir = Path(__file__).resolve().parents[1] / "data"
    cat = Catalogo(store, data_dir).load()

    borr = cat.por_id("borrador")
    orig_grupo = borr.grupo
    assert orig_grupo == "Borradores y Mezcla"

    # Mover al grupo "Pinceles y Trazos"
    store.save_patches([("EventosGrupo", "borrador", "Pinceles y Trazos")])
    cat.load()
    assert cat.por_id("borrador").grupo == "Pinceles y Trazos"

def test_duplicar_y_eliminar_custom(tmp_path):
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Particularidades]\n[EventosCustom]\nlista=\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    data_dir = Path(__file__).resolve().parents[1] / "data"
    cat = Catalogo(store, data_dir).load()

    cid, _ = cat.siguiente_custom()
    # Duplicar
    patches = [
        ("EventosCustom", "lista", cid),
        ("EventosCustom", cid, "Copia de Borrador|E"),
        ("EventosGrupo", cid, "Borradores y Mezcla")
    ]
    store.save_patches(patches)
    cat.load()
    clon = cat.por_id(cid)
    assert clon is not None
    assert clon.nombre == "Copia de Borrador"
    assert clon.grupo == "Borradores y Mezcla"
    assert clon.custom is True

    # Eliminar
    cat.eliminar_eventos([cid])
    cat.load()
    assert cat.por_id(cid) is None


def test_eliminar_evento_existente_y_purga_cascada(tmp_path):
    import shutil
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text(
        "[HudEventos1]\n"
        "formato_deshacer=moderno\n"
        "zona_deshacer=alta\n"
        "formato_rehacer=moderno\n"
        "[HudTextos1]\n"
        "texto_deshacer=ATRAS\n"
        "texto_rehacer=ADELANTE\n"
        "[Rangos1]\n"
        "deshacer_x=100\n"
        "deshacer_y=200\n"
        "deshacer_w=50\n"
        "deshacer_h=60\n"
        "HUD_ev_deshacer=100,200,50,60\n"
        "rehacer_x=300\n"
        "[Particularidades]\n"
        "cruzar_deshacer=1\n"
        "cruzar_rehacer=1\n"
        "[Remapeos]\n"
        "atajo_deshacer=^z\n",
        encoding="utf-8"
    )
    store = IniFile(ini_path).load()
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    orig_data_dir = Path(__file__).resolve().parents[1] / "data"
    if (orig_data_dir / "catalogo.json").exists():
        shutil.copy2(orig_data_dir / "catalogo.json", data_dir / "catalogo.json")

    cat = Catalogo(store, data_dir).load()
    assert cat.por_id("deshacer") is not None
    assert cat.por_id("rehacer") is not None

    # Eliminar evento existente ("deshacer")
    cat.eliminar_eventos(["deshacer"])
    cat.load()

    # Verificar que "deshacer" ya no existe en el catálogo
    assert cat.por_id("deshacer") is None
    # "rehacer" debe seguir intacto
    assert cat.por_id("rehacer") is not None

    # Verificar registro en [EventosEliminados]
    assert store.get("EventosEliminados", "deshacer") == "1"
    assert "deshacer" in (store.get("EventosEliminados", "lista") or "")

    # Verificar purga en cascada en INI
    assert store.get("HudEventos1", "formato_deshacer") is None
    assert store.get("HudTextos1", "texto_deshacer") is None
    assert store.get("Rangos1", "deshacer_x") is None
    assert store.get("Rangos1", "deshacer_w") is None
    assert store.get("Rangos1", "HUD_ev_deshacer") is None
    assert store.get("Particularidades", "cruzar_deshacer") is None
    assert store.get("Remapeos", "atajo_deshacer") is None

    # Verificar que los datos de "rehacer" no se tocaron
    assert store.get("HudEventos1", "formato_rehacer") == "moderno"
    assert store.get("HudTextos1", "texto_rehacer") == "ADELANTE"
    assert store.get("Rangos1", "rehacer_x") == "300"
    assert store.get("Particularidades", "cruzar_rehacer") == "1"

def test_operaciones_en_lote(tmp_path):
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Particularidades]\n[EventosPausados]\n[EventosGrupo]\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    data_dir = Path(__file__).resolve().parents[1] / "data"
    cat = Catalogo(store, data_dir).load()

    lote = ["borrador", "pluma", "lazo"]
    # Pausar lote
    store.save_patches([("EventosPausados", eid, "1") for eid in lote])
    cat.load()
    for eid in lote:
        assert cat.por_id(eid).pausado is True

    # Mover lote a grupo nuevo
    store.save_patches([("EventosGrupo", eid, "Favoritos") for eid in lote])
    cat.load()
    for eid in lote:
        assert cat.por_id(eid).grupo == "Favoritos"

    # Despausar lote
    store.save_patches([("EventosPausados", eid, None) for eid in lote])
    cat.load()
    for eid in lote:
        assert cat.por_id(eid).pausado is False


def test_stylus_context_menu_ui(tmp_path):
    import customtkinter as ctk
    from xppen_calibrador.ui.panels import StylusContextMenu, CatalogoPanel

    app = ctk.CTk()
    app.geometry("500x400")
    menu = StylusContextMenu(app, 50, 50)
    executed = []
    menu.add_command("Test Cmd", lambda: executed.append(1))
    menu.add_separator()
    def build_sub(sub):
        sub.add_command("Sub Cmd", lambda: executed.append(2))
    menu.add_cascade("Sub ▸", build_sub)
    menu.show(50, 50)
    app.update()

    assert StylusContextMenu._active is menu
    menu._exec(lambda: executed.append(99))
    app.update()
    assert 99 in executed
    assert StylusContextMenu._active is None

    # Test anti-flicker y no-on_select en clic derecho
    ini_path = tmp_path / "posiciones_gui.ini"
    ini_path.write_text("[Particularidades]\n[EventosPausados]\n", encoding="utf-8")
    store = IniFile(ini_path).load()
    data_dir = Path(__file__).resolve().parents[1] / "data"
    cat = Catalogo(store, data_dir).load()

    selected_events = []
    panel = CatalogoPanel(app, cat, lambda eid: selected_events.append(eid), lambda: None)
    panel.pack(fill="both", expand=True)
    app.update()

    # Selección normal con click izquierdo
    panel.select("borrador")
    app.update()
    assert selected_events == ["borrador"]

    # Simular clic derecho sobre otro evento (ej. "pluma")
    class DummyEvent:
        x_root = 100
        y_root = 100
        y = 50

    panel._on_context_menu(DummyEvent(), id_ev="pluma")
    app.update()

    # Verificar que el clic derecho NO dispara on_select (evita recarga y salto del editor)
    assert selected_events == ["borrador"]
    assert panel.selected == "pluma"
    app.destroy()


def test_stylus_pointer_hit_ejecuta_comando():
    import time
    import customtkinter as ctk
    from xppen_calibrador.ui.panels import StylusContextMenu
    app = ctk.CTk()
    app.geometry("300x200")
    done = []
    menu = StylusContextMenu(app, 40, 40)
    menu.add_command("Uno", lambda: done.append(1))
    menu.add_command("Off", lambda: done.append(9), state="disabled")
    menu.show(40, 40)
    app.update()
    assert len(menu._ptr_rows) == 1          # la fila deshabilitada no se registra
    b = menu._ptr_rows[0][0]
    cx = b.winfo_rootx() + b.winfo_width() // 2
    cy = b.winfo_rooty() + b.winfo_height() // 2
    assert menu._pointer_hit(cx, cy) is True
    assert menu._pointer_hit(-5, -5) is True  # _ptr_busy activo: no re-agenda
    t0 = time.time()
    while time.time() - t0 < 0.3:
        app.update()
        time.sleep(0.01)
    assert done == [1]
    assert StylusContextMenu._active is None
    app.destroy()

