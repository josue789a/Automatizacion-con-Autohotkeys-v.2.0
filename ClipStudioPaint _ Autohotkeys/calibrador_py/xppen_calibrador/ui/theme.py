"""Tokens visuales (medidos del mockup)."""
import tkinter.font as tkfont
import customtkinter as ctk

BG, CARD, BORDER = "#F5F4F9", "#FFFFFF", "#E8E3F2"
ACCENT, PRIMARY, PRIMARY_HOVER = "#7863A6", "#6E56A4", "#5E4893"
SOFT, SOFT_HOVER = "#F1EDF8", "#E6DFF2"
TXT, TXT2, TXT3 = "#201B38", "#6E6885", "#9D97B0"
FIELD_BORDER, FIELD_OFF = "#DCD6E8", "#C7C0D8"
MUTED_BG, MUTED_TXT = "#F7F5FB", "#B3ACC6"      # cabecera de grupo sin contenido (tenue)
MUTED_TXT2 = "#CFC9DC"                          # subtítulo/chevron atenuados
DANGER, WARN, OK = "#D64545", "#B7791F", "#2F855A"

GAP, PAD, HEADER_H, LEFT_W, FOOTER_H = 8, 12, 38, 272, 56
BADGE_W, BADGE_H = 30, 20        # badge numérico de tarjeta (01..05)
GROUP_BADGE = 26                 # diámetro del badge circular de grupo (A/B)
FAMILY = "Segoe UI"
FAMILY_CAP = "Segoe UI"         # campos de captura de teclas (se resuelve en init_fonts)


def init_fonts(root) -> None:
    global FAMILY, FAMILY_CAP
    fams = set(tkfont.families(root))
    for cand in ("Segoe UI Variable Text", "Segoe UI Variable Display", "Segoe UI", "Helvetica", "DejaVu Sans"):
        if cand in fams:
            FAMILY = cand
            break
    FAMILY_CAP = "Bahnschrift SemiCondensed" if "Bahnschrift SemiCondensed" in fams else FAMILY


def font(size: int = 12, bold: bool = False) -> ctk.CTkFont:
    return ctk.CTkFont(family=FAMILY, size=size, weight="bold" if bold else "normal")


def font_cap(size: int = 11) -> ctk.CTkFont:
    """Fuente angosta de los campos de captura de teclas."""
    return ctk.CTkFont(family=FAMILY_CAP, size=size)
