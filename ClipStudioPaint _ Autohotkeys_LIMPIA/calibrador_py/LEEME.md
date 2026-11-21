# XPPEN Companion · Calibrador Python — Corrida 1

## Instalar (una vez)
```
cd calibrador_py
py -3.14 -m venv .venv
.venv\Scripts\pip install -r requirements.txt
```
Copiar `lib\calibrador_py.ahk` junto a tus otros `lib\` y en el script principal:
```
#Include lib\calibrador_py.ahk
CalPyInit()            ; una vez, al arrancar
; abrir:  AbrirCalibradorPy()   (hotkey o ítem de menú)
```

## Verificar (en este orden)
1. `.venv\Scripts\python -m xppen_calibrador --ini "<ruta>\posiciones_gui.ini" --selftest`  → `SELFTEST OK`
2. `.venv\Scripts\python -m xppen_calibrador --ini "<ruta>\posiciones_gui.ini" --dump-schema`  → pegar la salida completa en el chat
3. `.venv\Scripts\pip install pytest` y `.venv\Scripts\python -m pytest tests` → 22 pruebas
4. Round-trip real: copiar el INI, abrir, cambiar UN valor, Guardar, y comparar con `fc /b` (solo debe cambiar esa línea)
5. Abrir desde AHK con `AbrirCalibradorPy()` y revisar `%TEMP%\_calibrador_py_ahk.log` y `%TEMP%\_calibrador_py.log`

## Anclas que debe completar Antigravity (en lib\calibrador_py.ahk)
SET_MODE, DRAW_ZONE, SHOW_PILL, TEST_HUD, TEST_SND, OPEN_LEGACY: el log dice `SIN ANCLA: <nombre>` mientras falte alguna.
