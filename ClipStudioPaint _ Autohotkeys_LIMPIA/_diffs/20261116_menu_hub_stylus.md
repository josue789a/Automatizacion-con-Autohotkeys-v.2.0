# Especificación — Menú del Companion compatible con stylus

- **Fecha:** 2026-11-16
- **Base:** `lib/companion_flotantes.ahk` del **2026-11-15 19:27** (versión viva de ayer; el estable solo cambió `posiciones_gui.ini` hoy).
- **Parche:** `_diffs/20261116_menu_hub_stylus.diff` — 5 hunks, `+163 / −56`.
- **Estado:** **no aplicado**. El estable actual no se tocó.
- **Validación:** AutoHotkey 2.0.26 `/validate` sobre copia temporal → `EXITCODE=0`; smoke test en runtime (creación de filas, dispatch por `WM_LBUTTONDOWN`, `WindowFromPoint`, cierre y reset de `hubGui.menuTick`).

---

## 1. Problema y causa raíz

En la base, `_MostrarMenuContextualHub()` (línea **1543**) construía un menú nativo:

```ahk
m := Menu()          ; 1550
...
m.Show()             ; 1634 (dentro de try/finally)
```

`Menu.Show()` termina en `TrackPopupMenuEx`, que:

1. Crea un menú **propiedad del sistema** (`#32768`), no ventanas del script.
2. Ejecuta su **propio bucle modal**: mientras está visible, el script no puede interceptar el clic por fila.
3. Solo interpreta `WM_MOUSEMOVE` / `WM_LBUTTONDOWN` / `WM_LBUTTONUP` reales y emite la selección como `WM_COMMAND`.

El lápiz XPPEN entrega **`WM_POINTERDOWN` (0x0246)**. Ese mensaje no se traduce a selección de menú y, al no existir un `HWND` por ítem, tampoco hay dónde hacer hit-test.

WINDOW ya había resuelto exactamente esto: `_NvMostrarMenu()` (949) + panel `Gui` propio `_NvPanel*` (851-947), documentado en el código como *"reemplaza Menu() nativo; compatible con stylus"*.

---

## 2. Alcance

### Cambia
| Elemento | Base | Cambio |
|---|---|---|
| `_MostrarMenuContextualHub()` | 1543 | Construye `filas[]` en vez de `Menu()`; termina en `_HubPanelMostrar(filas)` |
| Submenú Layout | 1612-1621 | `Menu` anidado → segundo panel `_HubPanelLayout` |
| `_HubMenuAbierto()` | 1671 | Consulta también el panel del Hub |
| `_NvMostrarMenu()` | 949 | Cierra el panel del Hub antes de abrir el de WINDOW |
| Nuevas `_HubPanel*` | — | 8 funciones, adaptadas de las `_NvPanel*` |

### No cambia
- **Apertura**: los mismos 10 puntos de entrada (`ContextMenu` + `WM_RBUTTON`).
- `_EjecutarAccionHub()` (1499) y la lógica de cada acción.
- Contenido y orden de los bloques 1/2/3, `hubGui.embebidos`, `_HubRapidaActiva`.
- Antirrebote de 400 ms al inicio de `_MostrarMenuContextualHub`.
- `_NvPanel*` de WINDOW: no se modifica ninguna; solo se **reutilizan** `_NvPanelBoton` (860), `_NvPanelClamp` (867) y `_VentanaDelProceso` (943).

---

## 3. Quién abre el menú (mapa de integración)

| Vía | Ubicación (base) | Nota |
|---|---|---|
| `OnEvent("ContextMenu")` en 9 píldoras | 518 (DS), 557 (CC), 608 (AR), 659 (HC), 1109 (lock), 1163 (frente), 1233 (estab), 1693 (puntos), 1887 (reload p.) | ratón: clic derecho |
| `OnMessage(0x0205, _Companion_WM_RBUTTON)` | 1108, 1392 | botón del lápiz / `WM_RBUTTONDOWN` |
| `_Companion_WM_RBUTTON` | 1479 | valida que `hwnd` (o su padre) sea una de 10 píldoras; si sí → `_MostrarMenuContextualHub()` y `return 0` (traga el mensaje: ni menú nativo ni clic en CSP) |
| `_EjecutarAccionHub("nv")` | 1524 | abre el menú de **WINDOW**, no el del Hub |

Por eso el gesto actual (clic derecho / botón del barril) sigue funcionando igual; el parche solo cambia **cómo se dibuja y se pulsa**.

---

## 4. Contrato de datos de `filas`

```ahk
fila := {t: "texto visible", f: Func, a: true}   ; a es opcional
sep  := {sep: true}                              ; línea de 1 px
```

- `a` (activo/resaltado) se lee con `f.HasProp("a")`: en AHK v2 acceder a una propiedad inexistente lanza error.
- `sep` se detecta con `f.HasProp("sep") && f.sep`.
- `_HubPanelMostrar` exige `filas.Length > 0`; si no, retorna sin mostrar.
- Invariante verificado: `_MostrarMenuContextualHub` empuja siempre ≥ 3 filas (bloque 2); `_HubPanelLayout` empuja 7.

---

## 5. Funciones nuevas

| Función | Rol | Detalle |
|---|---|---|
| `_HubPanelSt()` | estado singleton | `Map("g", Gui/0, "acc", Map(hwnd→fn), "t", tick)`; separado de `_NvPanelSt()` para no pisar WINDOW |
| `_HubPanelCerrar()` | cierre idempotente | para timer, desregistra `0x0201` y `0x0246` (`OnMessage(...,0)`), limpia `acc`, `Destroy()` con `try`, y pone `hubGui.menuTick := 0` |
| `_HubPanelEjecutarEn(hwnd)` | resolución de fila | si `hwnd` está en `acc`: guarda `fn`, **cierra primero**, `SetTimer(fn, -30)`, `return true` |
| `_HubPanel_WM_LBUTTONDOWN` | ratón | `_HubPanelEjecutarEn(hwnd)`; `return 0` solo si ejecutó |
| `_HubPanel_WM_POINTERDOWN` | lápiz/dedo | decodifica `lParam` a pantalla, `WindowFromPoint`, y resuelve |
| `_HubPanelVigilar()` | vigilante 50 ms | z-order, Esc, clic fuera, timeout 6 s |
| `_HubPanelMostrar(filas)` | construcción + show | antirrebote, exclusión mutua, stylus, medición, clamp, z-order |
| `_HubPanelLayout(*)` | submenú Layout | arma sus 7 filas y llama `_HubPanelMostrar` |

`SetTimer(fn, -30)` es deliberado: la acción corre **después** de destruir el `Gui` y de salir del handler del mensaje, evitando destruir un control dentro de su propio mensaje y evitando reentrancia.

---

## 6. Secuencia de apertura (timeline exacto)

1. **Antirrebote propio (600 ms)** — solo si el panel **sigue abierto** (`IsObject(st0["g"])`). Evita que clic derecho + botón del barril abran dos veces.
2. `_HubPanelCerrar()` + `_NvPanelCerrar()` → **nunca dos paneles propios a la vez**.
3. **Stylus:** `stylus.rButtonHeld := false` y `stylus.comboUsado := true`.
4. `KeyWait("RButton"/"LButton", "T0.25")`: espera ≤ 250 ms a que se suelte el botón físico para que el mismo gesto no active una fila ni el vigilante cierre al instante.
5. `MouseGetPos` → punto de anclaje (cursor).
6. **Medición:** `GP=_E(2)` (gap), `RH=_E(24)` (alto de fila), `PADB=_E(16)`; ancho = `max(_E(120), _AnchoTextoPill(texto) + PADB)` sobre todas las filas. `_AnchoTextoPill` (core_config:132) mide con *Segoe UI 9 bold* en un `Gui` temporal y cachea por texto.
7. **Construcción:** `Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x08000000")`, `BackColor = surface.off`, márgenes 0, fuente `_FS(9)`. `E0x08000000` = `WS_EX_NOACTIVATE` (no roba foco a CSP).
8. Filas: separador = `Text h1 BackgroundWhite`; botón = `_NvPanelBoton` → `Text` con `0x200` (SS_CENTERIMAGE) + `0x100` (SS_NOTIFY, necesario para que el control haga hit-test y reciba el clic) + `Center cWhite Background<bg>`; `bg = accent.on (3D7EDB)` si `a:true`, si no `surface.on (525252)`.
9. `H := y` (incluye el gap inferior). `_NvPanelClamp(&px,&py,W,H)` ajusta al área de trabajo del monitor bajo el cursor.
10. **Guardar estado antes de mostrar** (`g`, `acc`, `t`) para que un `WM_POINTERDOWN` inmediato pueda resolver.
11. `hubGui.menuTick := A_TickCount` (pausa `ResetAlphaStates`).
12. **Show en 3 pasos** (secuencia probada en WINDOW): `Show(... NoActivate Hide)` → `_DwmRedondear` → `SetWindowPos(HWND_TOPMOST=-1, 0x13)` → `Show("NoActivate")` → `SetWindowPos(HWND_TOP=0, 0x13)`. Garantiza que no exista ni un fotograma con una píldora encima y lo deja arriba de la banda topmost.
13. `OnMessage(0x0201, ...)` + `OnMessage(0x0246, ...)` + `SetTimer(_HubPanelVigilar, 50)`.

---

## 7. Selección: ratón vs lápiz

### Ratón — `WM_LBUTTONDOWN` (0x0201)
El `hwnd` del mensaje **es el control `Text`** de la fila (por `SS_NOTIFY`). `_HubPanelEjecutarEn(hwnd)` busca en `acc` y ejecuta.

### Lápiz/dedo — `WM_POINTERDOWN` (0x0246)
El `hwnd` del mensaje puede ser el `Gui` o la ventana bajo el puntero, no necesariamente el control. Por eso:

```ahk
px := lParam << 48 >> 48          ; bits 0-15, con signo
py := lParam << 32 >> 48          ; bits 16-31, con signo
hw := DllCall("WindowFromPoint", "Int64", (py << 32) | (px & 0xFFFFFFFF), "Ptr")
```

`WindowFromPoint` devuelve el control real bajo la punta → mismo lookup.

### Doble disparo
Un toque de lápiz puede generar `WM_POINTERDOWN` **y** un `WM_LBUTTONDOWN` sintetizado. No hay doble ejecución porque el primero cierra el panel y vacía `acc`; el segundo ya no encuentra el `hwnd` y retorna vacío (deja pasar el mensaje).

### Interacción con otros handlers
`0x0201` ya lo usa `_PuntosGUI_WM_LBUTTONDOWN` (1692). Nuestro handler devuelve vacío cuando la fila no es suya, así que **no bloquea** a los demás. `0x0246` solo lo registra el panel abierto (Hub o WINDOW, nunca ambos).

---

## 8. Cierre y estados

Cuatro disparadores, todos terminan en `_HubPanelCerrar()`:

1. **Fila pulsada** (`_HubPanelEjecutarEn`).
2. **Esc** físico (`GetKeyState("Escape","P")`).
3. **Clic fuera** con `LButton`/`RButton` físicamente abajo.
4. **6 s** sin interacción (`A_TickCount - st["t"] > 6000`); el contador se refresca mientras el cursor está sobre el panel.

Al cerrar: timer off, handlers off, `acc` limpio, `Gui.Destroy()`, `hubGui.menuTick := 0` (reanuda `ResetAlphaStates`). `_HubMenuAbierto()` (1671) devuelve `true` si hay panel del Hub **o** de WINDOW **o** `menuTick` reciente (<30 s).

---

## 9. Submenú Layout

La fila `📐 Layout Paneles CSP (Modo 1 y 2)  ▸` no abre un `Menu` nativo: su `f` es `_HubPanelLayout`, que 30 ms después (cuando el primer panel ya se destruyó) abre un segundo panel con:

| Fila | Acción | Resaltado |
|---|---|---|
| 🖥 Modo 1 · Normal | `EstablecerModoTrabajo("Normal")` | `a: !enfoque.activo` |
| 🔍 Modo 2 · Enfoque | `EstablecerModoTrabajo("Enfoque")` | `a: enfoque.activo` |
| — separador — | | |
| 🎛 Selector flotante | `ModoSel_Alternar()` | |
| 💾 Guardar ubicaciones activo | `_ModoGuardarActivo()` | |
| 💾 Guardar como Modo 1 | `_CapturarLayout("Normal")` | |
| 💾 Guardar como Modo 2 | `_CapturarLayout("Enfoque")` | |

El modo activo se marca con **fondo azul** (`a:true`, `accent.on`) en lugar del check nativo. El antirrebote de 600 ms no estorba porque exige `IsObject(st["g"])` y el panel ya se cerró.

---

## 10. Integración con el stylus (reglas del proyecto)

- `stylus.comboUsado := true` al abrir: cumple la regla de combos y, sobre todo, evita que el `RButton up` de `hotkeys_csp.ahk:391-400` emita `SendInput("{RButton}")` al levantar el lápiz (lo que reabriría el menú o haría clic en CSP).
- `stylus.rButtonHeld := false`: el `RButton` de `hotkeys_csp.ahk:386-389` lo había puesto en `true`; si quedara así, `_MaskRButton` (536-544) seguiría en modo gesto.
- `KeyWait(..., "T0.25")` evita que el mismo contacto active una fila o cierre el panel por "clic fuera".

---

## 11. Diferencias de comportamiento vs menú nativo

| Aspecto | `Menu()` nativo | Panel nuevo |
|---|---|---|
| Lápiz / táctil | ❌ solo ratón | ✅ `WM_POINTERDOWN` |
| Ratón | ✅ | ✅ `WM_LBUTTONDOWN` |
| Teclado (flechas/Enter/Esc) | ✅ | ❌ solo Esc para cerrar |
| Checkmark | ✅ | ✅ fondo azul (`a:true`) |
| Submenú | ✅ anidado | ⚠️ segundo panel (misma UX, sin flecha nativa) |
| Ancho | por ítem | uniforme (el mayor) |
| Scroll si no cabe | ✅ | ❌ (solo clamp; sin scroll) |
| Roba foco | ✅ | ❌ `WS_EX_NOACTIVATE` |
| Clic fuera | lo consume el menú | **pasa a la app de abajo** (igual que WINDOW) |
| Reapertura inmediata | permitida | bloqueada 600 ms |
| Auto-cierre | ❌ | ✅ 6 s |

---

## 12. Límites y riesgos conocidos

1. **Sin navegación por teclado** (flechas/Enter). Es una decisión de paridad con WINDOW; si se necesita, hay que añadir `WM_KEYDOWN`.
2. **Sin scroll**: con `ESC≈2` (200 %) y todas las rápidas activas (~13 filas × 52 px ≈ 676 px) cabe en 1080p, pero en pantallas pequeñas podría recortarse por abajo; el clamp solo evita salir por arriba/izquierda.
3. **DPI por `ESC` global**, no per-monitor (misma limitación que WINDOW).
4. **Primera apertura algo más lenta** si hay textos nuevos: `_AnchoTextoPill` crea/destruye un `Gui` de medición (luego cachea).
5. **Auto-cierre a 6 s**: si el usuario duda, el panel desaparece; basta reabrirlo.
6. **El clic fuera atraviesa** a CSP (comportamiento aceptado e idéntico a WINDOW). Con lápiz, un toque fuera puede pintar un trazo en el lienzo.
7. **Z-order**: si una píldora se re-eleva, el vigilante re-sube el panel con throttle de 250 ms; podría verse un parpadeo mínimo.
8. **Dos `OnMessage(0x0201)`** globales conviven porque el nuestro retorna vacío cuando no le corresponde.

---

## 13. Matriz de pruebas (XPPEN_NO_ADMIN.ahk)

| # | Caso | Esperado |
|---|---|---|
| 1 | Clic derecho en píldora DS | Panel con las mismas opciones que el menú anterior |
| 2 | Toque de lápiz en "Bloquear Companion" | Bloquea/desbloquea y cierra el panel |
| 3 | Toque en cualquier fila de extras | Ejecuta y cierra; sin doble ejecución |
| 4 | Toque en "Layout…" | Cierra el primero y abre el segundo panel |
| 5 | En Layout, tocar "Modo 2" | Cambia modo; el resaltado azul sigue al modo activo al reabrir |
| 6 | Esc | Cierra sin ejecutar |
| 7 | Toque fuera | Cierra; el toque sigue a CSP (aceptado) |
| 8 | Dejar 6 s sin tocar | Se cierra solo |
| 9 | Abrir menú del Hub y luego WINDOW | Solo queda WINDOW (exclusión mutua) |
| 10 | Abrir WINDOW y luego clic derecho en píldora | Solo queda el del Hub |
| 11 | Con panel abierto, mover cursor sobre él | No se cierra por timeout |
| 12 | Levantar el lápiz tras abrir | No se emite clic derecho sintético (`comboUsado`) |
| 13 | Clic derecho repetido rápido | No parpadea ni se duplica (600 ms) |
| 14 | Guardar `.bak`, aplicar y `/validate` | `EXITCODE=0` |

---

## 14. Aplicar / rollback

Desde `ClipStudioPaint _ Autohotkeys\`:

```powershell
Copy-Item "lib\companion_flotantes.ahk" "lib\companion_flotantes.ahk.bak"
git apply --check "_diffs\20261116_menu_hub_stylus.diff"
git apply "_diffs\20261116_menu_hub_stylus.diff"
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "XPPEN_NO_ADMIN.ahk"
```

Rollback: `git apply -R "_diffs\20261116_menu_hub_stylus.diff"` o restaurar el `.bak`.

Los anclajes del parche son **funciones**, no números de línea: si el estable actual ya cambió esas zonas, usar los bloques como guía.

---

## 15. Nota sobre la apertura

Este parche cambia la **selección de opciones**, no el gesto de apertura. El menú se sigue abriendo con clic derecho / botón del lápiz / `ContextMenu` (como hasta ahora).

Si con la **punta** del lápiz el menú ni siquiera aparece, hace falta un parche aparte para el gesto: doble toque estilo WINDOW o pulsación larga sobre la píldora, reutilizando `_Companion_WM_RBUTTON` o añadiendo un `WM_POINTERDOWN` sobre la píldora que llame a `_MostrarMenuContextualHub()`.
