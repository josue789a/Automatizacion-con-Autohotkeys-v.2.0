# Mapa Estructural de XPPEN AHK VERSION ESTABLE.ahk (6,118 líneas)

- L1 - L128: Variables globales, inicialización de timers y GUIs de acompañamiento.
- L129 - L1700: Hotkeys de Clip Studio Paint, combinaciones del stylus (~RButton & tecla), sanitize de modificadores, control del Dial.
- L1701 - L1860: Motor acústico (_SonarUI, _SonarFast, _CrearTonoRAM con winmm\PlaySoundW en RAM a 0ms).
- L1861 - L2350: Motor visual de HUD y Badges (MostrarAvisoUI, zonas Alta/Media/Baja, watchdog anti-atasco SW_HIDE, _AvisoBadgesActivos).
- L2351 - L4616: Companion GUI (botones flotantes arGui, hcGui, ccGui, dsGui, lockGui, frenteGui, estabBtnGui, layouts de paneles CSP).
- L4617 - L6058: Calibrador F1 / 📍 (4 pestañas: zonas/rangos, eventos/HUD, sistema/perfiles, paleta de temas, y lienzo interactivo).
- L6059 - L6118: Módulo de estabilización universal.

Reglas del proyecto:
- AutoHotkey v2 obligatorio.
- Código de salida 0 con AutoHotkey64.exe /validate.
- Zero-rewrite: preservar los métodos internos de cada módulo.
