# Pulsación larga con la punta del lápiz → menú del Companion

- **Fecha:** 2026-11-16
- **Base:** `lib/companion_flotantes.ahk` del **2026-11-15 19:27** (la misma base que el parche del menú).
- **Parche:** `_diffs/20261116_stylus_longpress.diff`
- **Estado:** **no aplicado**.
- **Validación:** `/validate` → `EXITCODE=0`; pruebas de la lógica pura (`_HubLPHecha`, `_HubLPFueLapiz`, interruptor) → `FALLOS=0`; aplica limpio sobre la base y reproduce el archivo probado byte a byte.

---

## 1. Qué resuelve

Hasta ahora el menú del Companion solo se abría con:

- clic derecho del ratón, o
- el botón del barril del lápiz.

Quien tiene el lápiz configurado **sin** botón derecho se veía obligado a coger el ratón.

Este parche permite abrir ese mismo menú **con la punta del lápiz**: se apoya la punta sobre cualquier píldora del Companion y se mantiene quieta ~0,55 s. Al soltar, aparece el menú.

El toque corto sigue haciendo exactamente lo de siempre. Arrastrar sigue arrastrando.

---

## 2. Reglas exactas del gesto

| Regla | Valor |
|---|---|
| Dispositivo | **solo lápiz** (`PT_PEN=3`); el dedo (`PT_TOUCH=2`) y el ratón no lo activan |
| Tiempo | **550 ms** apoyado |
| Movimiento | se cancela si la punta se mueve **más de 4 px** |
| Apertura | **al soltar**, nunca antes (así no choca con el cierre por "clic fuera" ni con el arrastre) |
| Acción de la píldora | **se cancela** cuando el gesto se completa |
| Si sueltas antes de 550 ms | acción normal de la píldora, como siempre |

El umbral está en un solo sitio: `_HubLPHecha()` (`A_TickCount - t0 >= 550`).

---

## 3. Píldoras cubiertas

Todas las que abren el menú del Companion:

| Píldora | Camino de código |
|---|---|
| DS (slider/pincel) | `_ArrastrarPanelBloque` → `_ClickOArrastre` |
| CC (círculo de color) | ídem |
| AR (acceso rápido) | ídem |
| HC (historial de color) | ídem |
| Lock (bloquear) | ídem / rama especial de `_SweepToggle` |
| Frente (AlwaysOnTop) | ídem |
| Estab (deslizador) | ídem |
| Puntos (calibrador) | `_PuntosGUI_WM_LBUTTONDOWN` |
| Reload (recargar) | `_ReloadGUI_WM_LBUTTONDOWN` |
| WINDOW (botón ventana) | `_NvGUI_WM_LBUTTONDOWN` → `_NvClicPoll` |
| Píldoras dinámicas (eventos) | `_PillClickOArrastre` |

También funciona con los paneles **bloqueados** (`_SweepToggle`, que es el camino que se usa cuando "Bloquear Companion" está activo).

---

## 4. Cómo está montado (sin timers nuevos)

No se añade ningún timer de fondo. La detección va **dentro de los bucles de pulsación que ya existen** (los que esperan a que se suelte el botón), con `A_TickCount`:

```ahk
lp := _HubLPFueLapiz()          ; ¿esta pulsación empezó con la punta?
t0 := A_TickCount
...
while _LBtnAbajo() {
    ...
    if (!largo && _HubLPHecha(t0, movido, lp))
        largo := true
    ...
}
if (largo) { _HubLPDisparar(); return }
```

Funciones nuevas (insertadas tras `_LBtnAbajo`):

| Función | Papel |
|---|---|
| `_HubLPSt()` | guarda el instante del último `WM_POINTERDOWN` de lápiz |
| `_HubLP_WM_POINTERDOWN` | registrado una vez en `IniciarHubGUI`; marca solo lápiz y solo ventanas del script |
| `_HubLPFueLapiz()` | ¿el `pointerdown` fue hace <150 ms? (distingue lápiz de ratón) |
| `_HubLPHecha(t0, movido, esLapiz)` | 550 ms + sin movimiento + interruptor activo |
| `_HubLPDisparar()` | abre el menú con 10 ms de retraso (ya con el lápiz levantado) |

En `_NvGUI_...` (que usa sondeo por timer, no bucle) el gesto se marca y se abre al soltar, igual que en el resto.

---

## 5. Interruptor para Opciones (servido para otro agente)

Un único punto:

```ahk
_HubLPActivo() {
    global hubGui
    if (IsObject(hubGui) && hubGui.HasOwnProp("lpLapiz"))
        return hubGui.lpLapiz
    return true          ; activo por defecto
}
```

Para que quede elegible en Opciones, el otro agente solo tiene que:

1. añadir la casilla (patrón de `hubGui.rapidas`, `IniciarHubGUI`, líneas 1379-1382);
2. leerla del INI, p. ej. `IniRead(ini, "Hub_p" PERFIL, "lp_lapiz", "1") = "1"`;
3. asignar `hubGui.lpLapiz := elegido`;
4. escribir la clave al cambiarla.

No hace falta tocar los gestos ni las píldoras.

---

## 6. Por qué no se añadió doble toque

El doble toque obliga a **retrasar la acción normal de cada toque** (~400 ms) para saber si viene un segundo. Eso haría que todas las píldoras respondieran con retraso todo el tiempo.

La pulsación larga no retrasa nada: el toque corto se resuelve al soltar como hasta ahora, y solo el gesto de mantener cambia de comportamiento.

Además, el botón WINDOW ya usa doble clic para abrir su propio menú; mezclar ambos gestos en la misma píldora sería confuso.

Si aun así se quisiera doble toque en el resto, se puede añadir después reutilizando el mismo interruptor y el estado `_HubLPSt`.

---

## 7. Relación con el parche del menú (importante)

Este parche **abre** el menú. Para **elegir opciones con la punta** hace falta también:

`_diffs/20261116_menu_hub_stylus.diff` (reemplaza el `Menu()` nativo por el panel compatible).

Los dos parches son independientes y **aplican limpio en cualquier orden** (probado en ambos órdenes + `/validate` combinado = 0).

Combinaciones:

| Aplicado | Resultado |
|---|---|
| Solo gesto | el menú se abre con la punta, pero las opciones siguen necesitando ratón |
| Solo menú | las opciones responden a la punta, pero hay que abrirlo con clic derecho/barril |
| **Ambos** | flujo completo con la punta: mantener → soltar → tocar opción |

---

## 8. Límites conocidos

1. **Solo lápiz**: si el lápiz no envía `WM_POINTERDOWN` (drivers muy antiguos o modo "mouse only"), el gesto no se activa. El clic derecho/barril sigue funcionando.
2. **Ratón**: mantener el botón izquierdo 550 ms quieto tampoco abre el menú (por diseño).
3. **Movimiento >4 px** cancela el gesto y se interpreta como arrastre.
4. **Sin señal visual** durante los 550 ms. Si se quiere, se puede añadir un HUD corto en `_HubLPDisparar`/al marcar `largo`.
5. **Píldora bloqueada**: el gesto también funciona; el barrido multi-panel sigue igual (solo se cancela si no hay movimiento).
6. **WINDOW**: conserva su doble clic para su propio menú; la pulsación larga abre el menú del Companion.

---

## 9. Pruebas recomendadas (`XPPEN_NO_ADMIN.ahk`)

| # | Caso | Esperado |
|---|---|---|
| 1 | Toque corto en cualquier píldora | Acción normal, sin retraso perceptible |
| 2 | Punta apoyada 0,6 s sin mover en DS | No cambia el slider; al soltar aparece el menú |
| 3 | Ídem en Lock, Frente, Estab, Puntos, Reload, WINDOW | Menú del Companion |
| 4 | Punta apoyada y arrastrada | Se arrastra la píldora; no aparece menú |
| 5 | Apoyar 0,3 s y soltar | Acción normal |
| 6 | Con paneles bloqueados, mantener en una píldora | Menú (no barrido) |
| 7 | Con paneles bloqueados, arrastrar entre píldoras | Barrido normal |
| 8 | Con dedo (si hay táctil) mantener | **No** abre el menú |
| 9 | Con ratón mantener pulsado | **No** abre el menú |
| 10 | `hubGui.lpLapiz := false` | El gesto deja de abrir el menú; el resto igual |
| 11 | Con el parche del menú aplicado, mantener → soltar → tocar opción | Flujo completo con la punta |
| 12 | Levantar el lápiz tras el gesto | Sin clic derecho sintético ni acción de la píldora |

---

## 10. Aplicar / rollback

Desde `ClipStudioPaint _ Autohotkeys\`:

```powershell
Copy-Item "lib\companion_flotantes.ahk" "lib\companion_flotantes.ahk.bak"
git apply --check "_diffs\20261116_stylus_longpress.diff"
git apply "_diffs\20261116_stylus_longpress.diff"
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "XPPEN_NO_ADMIN.ahk"
```

Rollback: `git apply -R "_diffs\20261116_stylus_longpress.diff"` o restaurar el `.bak`.

Orden con el otro parche: indiferente (probado en ambos).
