from types import SimpleNamespace as NS
from xppen_calibrador.ui.widgets import _acorde_txt, _tok_de

def _ev(ks, kc, ch=""):
    return NS(keysym=ks, keycode=kc, char=ch, state=0)

def test_orden_canonico():
    assert _acorde_txt(["H", "Alt", "Shift", "Ctrl"]) == "Ctrl+Alt+Shift+H"
    assert _acorde_txt(["W", "RButton", "Ctrl"]) == "Ctrl+RButton+W"
    assert _acorde_txt(["B", "W", "Alt", "Ctrl"]) == "Ctrl+Alt+B+W"

def test_tokens():
    assert _tok_de(_ev("Control_L", 17)) == "Ctrl"
    assert _tok_de(_ev("Super_L", 91)) == "Win"
    assert _tok_de(_ev("space", 32, " ")) == "Space"
    assert _tok_de(_ev("exclam", 49, "!")) == "1"
    assert _tok_de(_ev("Escape", 27)) == "Esc"
    assert _tok_de(_ev("Caps_Lock", 20)) == ""

def test_badge_cursor():
    import customtkinter as ctk
    from xppen_calibrador.ui.widgets import attach_keycapture
    r = ctk.CTk()
    try:
        e = ctk.CTkEntry(r)
        attach_keycapture(e)
        inner = getattr(e, "_entry", e)
        assert inner.cget("cursor") == "hand2"
    finally:
        r.destroy()
