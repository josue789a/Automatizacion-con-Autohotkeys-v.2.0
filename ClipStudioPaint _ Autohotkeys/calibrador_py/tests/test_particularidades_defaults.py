from xppen_calibrador.core.particularidades_defaults import (
    PARTICULARIDADES_DEFAULTS, particularidad_default, tiene_particularidad_nativa)


def test_borrador_suave_quick_l():
    assert particularidad_default("borrador_suave", "quick") == 1
    assert particularidad_default("borrador_suave", "quick_b") == "l"
    assert particularidad_default("borrador_suave", "quick_ms") == 300


def test_toggle_deseleccion():
    assert particularidad_default("deseleccion", "toggle_a") == "x"
    assert particularidad_default("reseleccion", "toggle_b") == "F10"


def test_evento_nuevo_sin_defaults():
    assert not tiene_particularidad_nativa("nuevo_evento_1")
    assert particularidad_default("nuevo_evento_1", "quick", 0) == 0


def test_todos_los_quick_tienen_umbral_valido():
    for ev, d in PARTICULARIDADES_DEFAULTS.items():
        if d.get("quick") and "quick_ms" in d:
            assert 50 <= d["quick_ms"] <= 2000, ev


def test_draft_get_particularidades_default(tmp_path):
    from xppen_calibrador.core.ini_store import IniFile
    from xppen_calibrador.core.draft import Draft

    p = tmp_path / "test.ini"
    p.write_text("[Particularidades]\n", encoding="utf-8")
    store = IniFile(p)
    draft = Draft(store, perfil="1")

    # Clave ausente en el INI -> toma el default nativo
    assert draft.get("quick", "borrador_suave") == 1
    assert draft.get("quick_b", "borrador_suave") == "l"
    assert draft.get("quick_ms", "borrador_suave") == 300
    assert draft.get("toggle", "deseleccion") == 1
    assert draft.get("toggle_a", "deseleccion") == "x"

    # Si se edita en draft a 0, el cambio en draft gana sobre el default
    draft.set("quick", "borrador_suave", 0)
    assert draft.get("quick", "borrador_suave") == 0


def test_draft_schema_hud_y_snd(tmp_path):
    from xppen_calibrador.core.ini_store import IniFile
    from xppen_calibrador.core.draft import Draft

    p = tmp_path / "test.ini"
    p.write_text("[HudEventos1]\nformato_shift=moderno\nzona_shift=alta\n[HudTextos1]\ntexto_pincel_duro=Hard Brush Custom\n", encoding="utf-8")
    store = IniFile(p).load()
    draft = Draft(store, perfil="1")

    # Lectura de claves existentes en secciones de AHK
    assert draft.get("hud_formato", "shift") == "moderno"
    assert draft.get("hud_zona", "shift") == "alta"
    assert draft.get("hud_texto", "pincel_duro") == "Hard Brush Custom"

    # Resolución de sección cuando la clave no existe aún
    sec_hud, key_hud = draft.resolve("hud_formato", "nuevo_evento")
    assert sec_hud == "HudEventos1"
    assert key_hud == "formato_nuevo_evento"

    sec_txt, key_txt = draft.resolve("hud_texto", "nuevo_evento")
    assert sec_txt == "HudTextos1"
    assert key_txt == "texto_nuevo_evento"

    sec_snd, key_snd = draft.resolve("snd_activo", "nuevo_evento")
    assert sec_snd == "HudSonido1"
    assert key_snd == "ev_nuevo_evento_activo"

