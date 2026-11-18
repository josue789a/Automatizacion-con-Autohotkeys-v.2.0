# Respuestas y Precisiones para Claude (Corrida 2)

### 1. Duda sobre el contador de zonas en Pestaña 2:
* **Confirmado:** Sí, el badge "2 zonas configuradas" cuenta **únicamente las zonas que tienen coordenadas reales guardadas en el INI** (es decir, donde `x1 != 0 || x2 != 0 || y1 != 0 || y2 != 0`). Las filas vacías no suman al contador.

### 2. Archivos incluidos en este paquete:
* `calibrador_py/xppen_calibrador/app.py`: Archivo principal actual con los stubs y la pestaña 1 conectada.
* `calibrador_py/xppen_calibrador/core/`:
  - `draft.py`: Gestor de borrador (lectura, set/get, dirty, commit).
  - `ini_store.py`: `IniFile` / `IniStore` con escritura atómica y preservación de BOM.
  - `ini_schema.py`: Definición formal de `FIELDS`.
  - `catalogo.py`: Consulta de eventos.
  - `ahk_bridge.py`: Cliente Win32 IPC con `send(cmd, *args)`.
* `calibrador_py/xppen_calibrador/ui/`:
  - `theme.py`: Colores y fuentes de la pestaña 1.
  - `widgets.py`: Helpers de botones, labels y switches.
  - `panels.py` y `blocks.py`: La implementación aprobada de la Pestaña 1.
* `calibrador_py/data/`:
  - `catalogo.json`: Los eventos reales de CSP.
  - `temas.json`: La lista completa de los **15 temas con sus 5 swatches de colores oficiales** extraídos de `_TemaPerfiles()`.
* `calibrador_py/tests/`: Los 22 tests que pasan al 100%.
* `lib/calibrador_py.ahk`: El puente AHK con todas las anclas ya enlazadas (`SET_MODE`, `DRAW_ZONE`, `SHOW_PILL`, `TEST_HUD`, `TEST_SND`, `OPEN_LEGACY`).
* `theme.ini`: El archivo real de tokens y tema activo.
* `dump_schema.txt`: Salida completa de `--dump-schema`.
