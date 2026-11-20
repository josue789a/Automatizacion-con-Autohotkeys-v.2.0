# Reporte técnico — Companion: menú y apertura compatibles con lápiz

- **Fecha:** 2026-11-16
- **Proyecto:** ClipStudioPaint _ Autohotkeys (AutoHotkey v2)
- **Archivo afectado:** `lib/companion_flotantes.ahk`
- **Base:** versión del **2026-11-15 19:27** (SHA-256 `4A46745A…78FA9`), que es la que sigue viva en el estable.
- **Estado:** **nada aplicado**. Todo se entrega como parches en `_diffs/`.
- **Alcance del documento:** reúne en un solo lugar el problema, las dos implementaciones y las mejoras propuestas. Sustituye, como contexto global, a las notas parciales de cada parche (que quedan como anexos).

---

## 1. Resumen ejecutivo

El menú de opciones del Companion tenía **dos fallos de uso con el lápiz**, independientes entre sí:

1. **Dentro del menú**: al tocar una opción con la punta, no se activaba. Solo respondía al ratón.
2. **Para abrirlo**: solo se abría con clic derecho o con el botón del barril del lápiz. Quien no tiene ese botón configurado debía coger el ratón.

Causa común: el menú era el `Menu()` nativo de Windows, pensado para ratón. WINDOW ya lo había resuelto con un panel propio que sí entiende los eventos del lápiz.

Se entregan **dos parches independientes**:

| Parche | Qué resuelve | Tamaño |
|---|---|---|
| `20261116_menu_hub_stylus.diff` | El menú se dibuja como panel propio y **responde a la punta** | 6 hunks, +176 / −29 |
| `20261116_stylus_longpress.diff` | **Mantener la punta** sobre una píldora abre el menú | 18 hunks, +118 / −2 |

Ambos aplican limpio sobre la base, en cualquier orden, y el resultado combinado valida sintaxis (`EXITCODE=0`). Nada se ha aplicado al estable.

---

## 2. Problema

### 2.1 Síntoma reportado

- **Imagen 1**: menú contextual del Companion (`_MostrarMenuContextualHub`). Se abre, pero las opciones no responden al lápiz.
- **Imagen 2**: menú de WINDOW (`_NvMostrarMenu`), que sí responde al lápiz. Es la referencia de comportamiento deseado.

A esto se sumó una limitación de acceso: sin botón de barril, el menú solo se podía abrir con el ratón.

### 2.2 Causa raíz del fallo dentro del menú

En la base, `_MostrarMenuContextualHub()` (línea **1543**) hacía:

```ahk
m := Menu()      ; 1550
...
m.Show()         ; ~1634
```

`Menu.Show()` termina en `TrackPopupMenuEx`, que:

1. crea un menú **propiedad del sistema** (`#32768`), no ventanas del script;
2. ejecuta su **propio bucle modal**, así que el script no puede interceptar la pulsación por fila;
3. solo interpreta los mensajes de ratón (`WM_MOUSEMOVE`, `WM_LBUTTONDOWN`, `WM_LBUTTONUP`) y devuelve la elección como `WM_COMMAND`.

La tableta entrega la pulsación como **`WM_POINTERDOWN` (0x0246)**. Ese mensaje no se traduce a selección de menú y, al no existir un `HWND` por ítem, tampoco hay dónde hacer hit-test. Resultado: el menú se ve, pero la punta no elige nada.

### 2.3 Causa raíz del fallo de apertura

El menú se abría por dos vías:

- `OnEvent("ContextMenu")` en las píldoras (clic derecho del ratón);
- `_Companion_WM_RBUTTON` sobre `WM_RBUTTONDOWN` (0x0205), que cubre el botón del barril.

Ninguna de las dos usa la punta. Sin barril configurado, no hay forma de abrirlo sin ratón.

### 2.4 Precedente que se reutilizó

WINDOW ya tenía la solución al primer problema: `_NvMostrarMenu()` (949) y el conjunto `_NvPanel*` (851-947), documentado en el propio código como *“reemplaza Menu() nativo; compatible con stylus”*. En lugar de inventar un mecanismo nuevo, se extrajo ese comportamiento probado.

---

## 3. Objetivos y no objetivos

### Objetivos

1. Que las **opciones** del menú del Companion se puedan elegir con la punta.
2. Que el menú se pueda **abrir** con la punta, sin ratón ni barril.
3. No cambiar el comportamiento de ratón ni el de los atajos existentes.
4. Dejar preparada la posibilidad de **convertir el gesto en opción** configurable.
5. Entregar solo diffs, sobre la base de ayer, sin tocar el estable.

### No objetivos

- Rediseñar el menú ni sus acciones.
- Añadir navegación por teclado al panel.
- Cambiar el orden o el contenido de las opciones.
- Soportar dedo/táctil como gesto (se decidió **solo lápiz**).
- Aplicar los cambios.

---

## 4. Restricciones de trabajo

Tomadas de `AGENTS.md` y respetadas en la entrega:

- Base = versión de ayer (el estable solo cambió `posiciones_gui.ini` hoy).
- Cambios atómicos y por bloques, sin reescrituras.
- Validación con AutoHotkey `/validate` antes de entregar.
- Entrega por diffs exactos; nada aplicado.
- Combos de lápiz deben marcar `stylus.comboUsado := true`.
- Respaldo `.bak` previsto en las instrucciones de aplicación.
- Límite de reintentos: no se entró en bucles de prueba.

---

## 5. Entregables

| Archivo | Contenido |
|---|---|
| `_diffs/20261116_menu_hub_stylus.diff` | Panel de menú compatible con lápiz |
| `_diffs/20261116_menu_hub_stylus.md` | Especificación detallada de ese parche |
| `_diffs/20261116_stylus_longpress.diff` | Pulsación larga para abrir el menú |
| `_diffs/20261116_stylus_longpress.md` | Especificación detallada de ese parche |
| `_diffs/20261116_reporte_companion_stylus.md` | **Este reporte** (contexto único) |

Hashes de referencia:

| Elemento | SHA-256 |
|---|---|
| Base (`lib/companion_flotantes.ahk` actual) | `4A46745AE264C292E8E037CD6AFD34DFC1EFFBA58C17FB86AB1CB7C74D878FA9` |
| Base + parche de menú + parche de gesto (validado) | `D41FA333181929012C21358D46B508515FFA295D776E2C3F956FDE76E518DF10` |
| `20261116_menu_hub_stylus.diff` | `8405518B95A71BFC17AA071482E8A9F43FC4766356A42E955153AAF77B23E2DA` |
| `20261116_stylus_longpress.diff` | `78A50E8E6E54642D1D02BD82439C683CF2014F48F45B1A8489167F09D6FA5B07` |

---

## 6. Implementación A — menú compatible con lápiz

### 6.1 Idea

Sustituir el `Menu()` nativo por un **panel `Gui` propio**, con una fila por opción, y ejecutar la acción directamente al recibir:

- `WM_LBUTTONDOWN` (0x0201) para ratón;
- `WM_POINTERDOWN` (0x0246) para lápiz/dedo, resolviendo la fila con `WindowFromPoint`.

Es exactamente la mecánica de WINDOW, con estado propio (`_HubPanelSt`) para que ambos paneles no se pisen.

### 6.2 Mapa de cambios

| Zona | Línea base | Cambio |
|---|---|---|
| `_MostrarMenuContextualHub` | 1543 | `Menu()` → `filas[]`; termina en `_HubPanelMostrar(filas)` |
| Bloque 1 (píldoras visibles) | 1570-1580 | `m.Add(texto, fn)` → `filas.Push({t, f})` |
| Bloque 2 (siempre) | 1583-1585 | 3 × `filas.Push` |
| Bloque 3 (extras) | 1588-1616 | separador → `{sep:true}`; 8 filas convertidas |
| Submenú Layout | 1612-1621 | `Menu` anidado → segundo panel `_HubPanelLayout` |
| `_NvMostrarMenu` | 949 | añade `_HubPanelCerrar()` (exclusión mutua) |
| `_HubMenuAbierto` | 1671 | consulta también `_HubPanelSt()` |

No se toca: `_EjecutarAccionHub` (1499), antirrebote de 400 ms (1545-1548), contenido y orden de bloques, ni ninguna `_NvPanel*`.

### 6.3 Contrato de datos

```ahk
{t: "texto", f: Func}            ; fila normal
{t: "texto", f: Func, a: true}   ; fila resaltada (modo activo)
{sep: true}                      ; separador de 1 px
```

`a` y `sep` se consultan con `HasProp` porque en AHK v2 leer una propiedad inexistente lanza error.

### 6.4 Funciones nuevas

| Función | Responsabilidad |
|---|---|
| `_HubPanelSt()` | Estado: `g` (Gui/0), `acc` (hwnd → función), `t` (último uso) |
| `_HubPanelCerrar()` | Cierre idempotente: timer, `OnMessage` ×2, `acc`, `Destroy()`, `menuTick := 0` |
| `_HubPanelEjecutarEn(hwnd)` | Resuelve la fila, **cierra primero** y difiere la acción 30 ms |
| `_HubPanel_WM_LBUTTONDOWN` | Ratón |
| `_HubPanel_WM_POINTERDOWN` | Lápiz/dedo vía `WindowFromPoint` |
| `_HubPanelVigilar()` | Cada 50 ms: z-order, Esc, clic fuera, timeout |
| `_HubPanelMostrar(filas)` | Construcción, medición, clamp, show y registro |
| `_HubPanelLayout(*)` | Submenú Layout como segundo panel |

### 6.5 Ciclo de vida

**Apertura**

1. Antirrebote propio de 600 ms (solo si el panel sigue abierto).
2. Cierra el panel del Hub y el de WINDOW (nunca dos).
3. Marca `stylus.rButtonHeld := false` y `stylus.comboUsado := true`.
4. `KeyWait` ≤ 250 ms para que el mismo gesto no active una fila.
5. Mide con `_AnchoTextoPill` (Segoe UI 9 bold, cacheado).
6. Construye `Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x08000000")`; `E0x08000000` evita robar foco a CSP.
7. Filas con `Text` `0x200` (centrado vertical) y `0x100` (`SS_NOTIFY`, necesario para el hit-test).
8. Ajusta al área de trabajo del monitor del cursor (`_NvPanelClamp`).
9. Guarda estado, marca `hubGui.menuTick`, muestra oculto → topmost → visible → topmost de banda.

**Selección**

- Ratón: el `hwnd` del mensaje ya es el control de la fila.
- Lápiz: se decodifica `lParam` (x/y con signo), `WindowFromPoint` y mismo lookup.
- Doble disparo: el primero cierra y vacía `acc`; el segundo ya no encuentra fila.

**Cierre**

Fila pulsada · Esc · clic fuera · 6 s sin interacción. Siempre por `_HubPanelCerrar()`.

### 6.6 Submenú Layout

La fila `📐 Layout Paneles CSP (Modo 1 y 2) ▸` abre un segundo panel con las mismas 7 opciones. El modo activo se marca con fondo azul (`a: true`, `accent.on`) en lugar del check nativo.

### 6.7 Integración

- 10 puntos de entrada siguen intactos: 9 `ContextMenu` + `_Companion_WM_RBUTTON`.
- `_HubMenuAbierto()` ahora cubre ambos paneles; `ResetAlphaStates` sigue pausándose mientras hay menú.
- Convive con el `OnMessage(0x0201)` de `_PuntosGUI_WM_LBUTTONDOWN` porque el handler del panel retorna vacío cuando no le corresponde.

### 6.8 Diferencias asumidas frente al menú nativo

| Aspecto | Nativo | Panel |
|---|---|---|
| Lápiz | ❌ | ✅ |
| Teclado (flechas/Enter) | ✅ | ❌ (solo Esc) |
| Checkmark | ✅ | ✅ fondo azul |
| Submenú | anidado | segundo panel |
| Ancho | por ítem | uniforme |
| Scroll | ✅ | ❌ (solo clamp) |
| Foco | lo roba | no lo roba |
| Clic fuera | lo consume el menú | pasa a la app (igual que WINDOW) |
| Auto-cierre | ❌ | 6 s |

---

## 7. Implementación B — abrir el menú con la punta

### 7.1 Decisión de gesto

Se evaluaron dos opciones:

| Gesto | Ventaja | Coste |
|---|---|---|
| **Pulsación larga** | no retrasa nada; el toque corto sigue instantáneo | requiere ~0,55 s y no tiene señal visual |
| Doble toque | natural en táctil | obliga a **retrasar todos** los toques ~400 ms para esperar el segundo |

Se eligió **pulsación larga**. El doble toque haría que todas las píldoras respondieran con retraso permanente, además de chocar con el doble clic que WINDOW ya usa para su propio menú.

### 7.2 Reglas

| Regla | Valor |
|---|---|
| Dispositivo | solo lápiz (`PT_PEN = 3`) |
| Tiempo | 550 ms |
| Movimiento tolerado | 4 px |
| Apertura | al **soltar** |
| Acción de la píldora | se cancela si el gesto se completa |
| Toque corto | acción normal, sin retraso |

### 7.3 Cómo se distingue el lápiz

`WM_POINTERDOWN` marca el instante solo si `GetPointerType` devuelve 3 (lápiz). Ratón (1) y dedo (2) quedan fuera. La marca caduca a los 150 ms, así que un clic de ratón nunca la aprovecha.

### 7.4 Cobertura

| Píldora | Camino |
|---|---|
| DS, CC, AR, HC, Lock, Frente, Estab | `_ArrastrarPanelBloque` → `_ClickOArrastre` |
| Lock / bloqueadas | rama especial y barrido de `_SweepToggle` |
| Puntos | `_PuntosGUI_WM_LBUTTONDOWN` |
| Reload | `_ReloadGUI_WM_LBUTTONDOWN` |
| WINDOW | `_NvGUI_WM_LBUTTONDOWN` → `_NvClicPoll` |
| Dinámicas | `_PillClickOArrastre` |

### 7.5 Por qué se abre al soltar

Si se abriera al cumplirse los 550 ms, el panel nacería con el botón aún pulsado. El vigilante lo interpretaría como “clic fuera” y lo cerraría, y la píldora podría seguir arrastrándose. Abriendo al soltar, el menú nace en un estado limpio.

### 7.6 Implementación

Sin timers nuevos: la detección usa `A_TickCount` **dentro de los bucles de pulsación que ya existían** (`while _LBtnAbajo()`). En el caso de WINDOW, que usa sondeo por timer, se marca y se abre al soltar.

Funciones nuevas (junto a `_LBtnAbajo`):

| Función | Papel |
|---|---|
| `_HubLPSt()` | instante del último `pointerdown` de lápiz |
| `_HubLP_WM_POINTERDOWN` | registrado en `IniciarHubGUI`; filtra lápiz y proceso |
| `_HubLPFueLapiz()` | ¿la pulsación actual empezó con la punta? |
| `_HubLPHecha(t0, movido, esLapiz)` | 550 ms + quieto + interruptor activo |
| `_HubLPDisparar()` | abre el menú 10 ms después |

### 7.7 Interruptor (servido para Opciones)

```ahk
_HubLPActivo() {
    global hubGui
    if (IsObject(hubGui) && hubGui.HasOwnProp("lpLapiz"))
        return hubGui.lpLapiz
    return true          ; activo por defecto
}
```

Un solo punto de verdad. Otra persona/agente puede exponerlo en Opciones sin tocar los gestos.

---

## 8. Mejora propuesta

Ordenada por relación impacto/esfuerzo.

### 8.1 Señal visual durante la pulsación (propuesta principal)

Hoy el gesto no da feedback: se mantiene medio segundo sin saber si va a abrir o no.

**Propuesta:** al cumplirse el umbral, mostrar un aviso breve (HUD) tipo `MENÚ AL SOLTAR`, o bien un cambio de borde/color en la píldora.

- **Impacto:** alto (descubribilidad y confianza).
- **Esfuerzo:** bajo; una llamada en el punto donde `largo` pasa a `true`.
- **Riesgo:** bajo, si el HUD es `NoActivate` y dura <1 s.
- **Decisión pendiente:** HUD de texto, borde, o sonido suave.

### 8.2 Convertir el gesto en opción de Opciones

El interruptor `hubGui.lpLapiz` ya existe. Para completarlo:

1. Casilla en Opciones siguiendo el patrón de `hubGui.rapidas` (`IniciarHubGUI`, ~1379-1382).
2. Clave INI propuesta: `[Hub_p<perfil>] lp_lapiz = 1|0`.
3. Al cambiar: asignar `hubGui.lpLapiz` y escribir la clave.
4. Sin tocar gestos ni píldoras.

- **Impacto:** alto para quien prefiera el comportamiento antiguo.
- **Esfuerzo:** bajo-medio.
- **Riesgo:** bajo.

### 8.3 Comprobación “hay tableta”

Añadir una verificación de digitalizador antes de habilitar el gesto (además del tipo de puntero). No es imprescindible —sin lápiz no se activa— pero elimina dudas en equipos sin tableta.

- **Impacto:** bajo.
- **Esfuerzo:** bajo.
- **Riesgo:** bajo (falsos negativos si el driver no reporta digitalizador).

### 8.4 Doble toque alternativo

Se puede añadir como segundo gesto configurable, reutilizando `_HubLPSt` y el interruptor. Requiere asumir el retraso del toque simple o aplicar el doble toque solo a algunas píldoras.

- **Impacto:** medio.
- **Esfuerzo:** medio-alto.
- **Riesgo:** alto (lentitud percibida, choque con WINDOW).

### 8.5 Mejoras del panel (independientes)

| Mejora | Impacto | Esfuerzo |
|---|---|---|
| Navegación con flechas/Enter | medio (accesibilidad) | medio |
| Scroll si no cabe en pantalla | bajo | medio |
| DPI por monitor | bajo | alto |
| Feedback de hover en filas | bajo | bajo |

### 8.6 Prioridad recomendada

1. **8.1 Señal visual** (cierra la única carencia de uso del gesto).
2. **8.2 Opción en Opciones** (deja el cambio bajo control del usuario).
3. 8.3 comprobación de tableta.
4. 8.5 hover y teclado.
5. 8.4 doble toque solo si se pide expresamente.

---

## 9. Validación realizada

### 9.1 Estática

`AutoHotkey64.exe /validate` sobre un envoltorio con `#Warn All, OutputDebug` (necesario para que ningún aviso abra un diálogo modal y bloquee la validación):

| Archivo | Resultado |
|---|---|
| Base + parche de menú | `0` |
| Base + parche de gesto | `0` |
| Base + ambos (orden A→B) | `0` |
| Base + ambos (orden B→A) | `0` |

### 9.2 Pruebas de lógica del gesto

Banco aislado que incluye la librería y evalúa la lógica pura:

| Caso | Resultado |
|---|---|
| Activo por defecto | ✅ |
| 600 ms, lápiz, quieto | dispara |
| 100 ms | no dispara |
| Movido | no dispara |
| Ratón | no dispara |
| `pointerdown` reciente | reconocido como lápiz |
| `pointerdown` antiguo | no reconocido |
| Interruptor en `false` | no dispara |
| Interruptor en `true` | dispara |

Resultado global: `FALLOS=0`.

### 9.3 Integridad de los parches

- `git apply --check` limpio sobre la base actual.
- Aplicado en copia limpia → **byte a byte idéntico** al archivo probado (SHA-256 coincidente).
- Combinación de ambos parches probada en los dos órdenes.

### 9.4 Pendiente de validación en hardware

No se puede simular la sensación real del lápiz en este entorno. Falta probar en `XPPEN_NO_ADMIN.ahk`:

- tiempo percibido de los 550 ms;
- que el toque corto siga instantáneo;
- que el gesto no interfiera con el arrastre;
- que el driver no esté en “modo ratón”;
- comportamiento con paneles bloqueados.

---

## 10. Matriz de pruebas funcionales

| # | Caso | Esperado |
|---|---|---|
| 1 | Clic derecho en píldora | Panel con las mismas opciones |
| 2 | Tocar opción con la punta | Ejecuta y cierra |
| 3 | Tocar opción con ratón | Ejecuta y cierra |
| 4 | Abrir Layout | Segundo panel; modo activo resaltado |
| 5 | Esc | Cierra sin ejecutar |
| 6 | Tocar fuera | Cierra; el toque pasa a CSP |
| 7 | 6 s sin tocar | Se cierra solo |
| 8 | Hub → WINDOW | Solo queda WINDOW |
| 9 | WINDOW → Hub | Solo queda el Hub |
| 10 | Toque corto en píldora | Acción normal |
| 11 | Mantener 0,6 s y soltar | Menú del Companion |
| 12 | Mantener y arrastrar | Arrastre, sin menú |
| 13 | Mantener 0,3 s | Acción normal |
| 14 | Dedo mantenido | Nada |
| 15 | Ratón mantenido | Nada |
| 16 | Paneles bloqueados + mantener | Menú (no barrido) |
| 17 | Paneles bloqueados + arrastrar | Barrido normal |
| 18 | `hubGui.lpLapiz := false` | El gesto no abre nada |

---

## 11. Riesgos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Driver en “modo ratón” → sin gesto | media | clic derecho/barril siguen; se puede documentar |
| Panel recortado en pantallas pequeñas | baja | clamp actual; scroll como mejora 8.5 |
| Clic fuera pinta en CSP | conocida | mismo comportamiento que WINDOW; aceptado |
| Sin feedback en el gesto | alta | propuesta 8.1 |
| Confusión de gesto con arrastre | baja | umbral de 4 px y cancelación al mover |
| Dos paneles abiertos | nula | cierre mutuo en ambos sentidos |

---

## 12. Plan de aplicación

Desde `ClipStudioPaint _ Autohotkeys\`:

```powershell
Copy-Item "lib\companion_flotantes.ahk" "lib\companion_flotantes.ahk.bak"

git apply --check "_diffs\20261116_menu_hub_stylus.diff"
git apply         "_diffs\20261116_menu_hub_stylus.diff"

git apply --check "_diffs\20261116_stylus_longpress.diff"
git apply         "_diffs\20261116_stylus_longpress.diff"

& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "XPPEN_NO_ADMIN.ahk"
```

- Orden indiferente.
- Probar primero en `XPPEN_NO_ADMIN.ahk`.
- Rollback total: `git apply -R` de ambos parches y restaurar el `.bak`.

---

## 13. Glosario breve

- **Píldora**: botón flotante redondeado del Companion.
- **Panel propio**: ventana del script que sustituye al menú de Windows.
- **Pulsación larga**: mantener la punta quieta ~0,55 s.
- **WM_POINTERDOWN**: aviso que manda Windows cuando el lápiz toca la pantalla.
- **PT_PEN**: identificador con el que Windows distingue el lápiz del dedo y del ratón.

---

## 14. Estado final

- Implementación A: **terminada y validada**, sin aplicar.
- Implementación B: **terminada y validada**, sin aplicar.
- Mejora propuesta: **documentada, pendiente de decisión** (empezando por la señal visual).
- El estable permanece intacto; la base usada es la del 2026-11-15.
