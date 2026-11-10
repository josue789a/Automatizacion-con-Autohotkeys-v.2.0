# INFORME QODER — Ola 6 (Req 6 y 8) · `lib/calibrador.ahk`

**Fecha:** 2026-11-07 22:25 (GMT-5)
**Agente:** QODER (local, escritura directa en el proyecto)
**Archivo propio tocado:** `lib/calibrador.ahk` — **ningún otro archivo del proyecto fue modificado.**
**`CHECKPOINT.md`: NO tocado** (propiedad de Antigravity). Este informe + `_estado_qoder_ola6.json` son el testigo.

---

## 1. Estado

**COMPLETO Y VALIDADO.** `/validate` del driver → **exit 0**. Arnés funcional aislado → **47 pruebas, 0 fallos**.
Falta la prueba visual en CSP con el lápiz, que le corresponde al usuario (recarga en vivo).

| Archivo | Bytes | Líneas (`wc -l`) | SHA256 | Dueño |
|---|---|---|---|---|
| `lib/calibrador.ahk` | 48837 | 1163 | `ac69059831713360082c1c2e296827023516ee9aa58a5b11f6e598fd9727a232` | **QODER (modificado)** |
| `XPPEN AHK VERSION ESTABLE.ahk` | 6461 | 146 | `56ff28b8f5921dff6110bf0712322ecbe5e3778f6c397e3ecb1e489d7e918f74` | driver (solo leído) |
| `lib/core_config.ahk` | 12101 | 391 | `1663e5fe55902b6dc4f67badcde2e0811874cb8c98c802b31ff6996083317e73` | Cline (solo leído) |
| `lib/hotkeys_csp.ahk` | 34738 | 1251 | `dc7763d7aa8105900a52573c3e6c0ee6394381216df5a275a50ab713ab026f0e` | OpenCode (solo leído) |
| `lib/hud_badges.ahk` | 21459 | 540 | `1c33cfe98d23cdde0ff4ebe2ae68a6a338c90f44dc36d6fd6fd86d027a384f5b` | Cline (solo leído) |
| `posiciones_gui.ini` | 12620 | — | `38ee952a67e79a3f605f0bcadf4a587890d16a7f282a3418be268e974ba9db9b` | ** intacto / sin cambios** |

El ini real **no fue escrito** por Qoder: todas las pruebas de escritura corrieron sobre una copia en
`%TEMP%\qoder_ola6_test\`. Hash idéntico al respaldo de inicio de ola.

### Zero-rewrite auditado
`diff -u` contra el respaldo de inicio de ola: **+276 / −44, 14 hunks, 0 líneas en blanco borradas.**
Las 44 líneas borradas son exactamente las reemplazadas: 6 (ListView + anchos de columna), 2 (layout y texto
de la pestaña 2), 25 (etiquetas del catálogo), 5 (`_GuardarDuracionesHUD`), 2 (`_PtsEvFilas`), 3 (`_PtsEvCambio`),
1 (`_PtsEvProbar`). Ninguna reestructuración, ningún ID existente renombrado (son claves del ini).

### Respaldos creados antes de guardar
- `_backups/lib_calibrador.ahk.bak-qoder-ola6-20261107-214709` → `5ba170d7ca795eecb7fceadc7c552c0ba3567d46e7ffb681265e8ac79eebb7e0` (931 líneas, original)
- `_backups/lib_calibrador.ahk.bak-qoder-ola6b-20261107-220639` → `5e995df282b86bdf23da06a17ebc51904e535881393f8aa7ace527b028bcc5d6` (1127 líneas)
- `_backups/lib_calibrador.ahk.bak-qoder-ola6c-20261107-222027` → estado previo a los arreglos de backup/etiqueta
- `_backups/posiciones_gui.ini.bak-qoder-ola6-20261107-214709` → `38ee952a…`

---

## 2. Lo implementado

### Req 6 — Eventos nuevos
Los 5 IDs del contrato están en `_PtsEventosDefs()`, sin duplicados (catálogo = **51 eventos**):
`shift_anclado` (Lienzo y Reglas), `capa_ocultar`, `capa_mostrar`, `macro_capas`, `mascara_recorte` (Capas y Archivo).
Se guardan con las mismas claves de siempre: `formato_<id>`, `zona_<id>`, `opacidad_<id>`, y ahora `duracion_<id>`.

### Req 8 — Nombres sincronizados con el atajo real
25 etiquetas reescritas contra lo que el motor emite de verdad (leído en `hotkeys_csp.ahk`, no inventado).
Ejemplos: `color_alpha` decía **(C)** y el código manda **K** (`hotkeys_csp.ahk:762-775`); `pincel_duro` ahora
dice `RButton + Q → F6`; `borrador_lazo`, `RButton + E → F12`; `opc_presion`, `Alt + W → <`.
Los IDs nuevos quedaron así, verificados contra el emisor:

| ID | Etiqueta | Emisor real |
|---|---|---|
| `capa_ocultar` | Ocultar Capa · Hide Layer (Space + E → Shift + D) | `hotkeys_csp.ahk:524` (`_ToggleLayerVis` manda `{Shift down}d`) |
| `capa_mostrar` | Mostrar Capa · Show Layer (Space + E → Shift + D) | `hotkeys_csp.ahk:526` |
| `shift_anclado` | Shift Anclado ON / OFF (RButton + F) | `hotkeys_csp.ahk:879,884` |
| `mascara_recorte` | Máscara de Capa / Recorte (RButton + S → M) | `hotkeys_csp.ahk:851-857` (manda **M**, ver §4.5) |
| `macro_capas` | Macro de Capas 1→2→3 (O / − va por pasos) | **sin emisor conectado**, ver §4.4 |
| `capa_visibilidad` | Visibilidad de Capa (heredado · Space + E) | legacy, ver §4.6 |

Prohibido dejar un nombre genérico sin comando: `macro_capas` no anuncia "(O)" porque O no dispara ese evento.

### Botón de backup rápido (pestaña 3)
Grupo `🗂 Copia de seguridad de posiciones_gui.ini` con `💾 Crear backup`, `↩ Restaurar último` y etiqueta
con el nombre + fecha del último. Copia a `posiciones_gui_AAAAMMDD_HHMMSS.bak.ini` junto al driver.
- Restaurar **pide confirmación**, antes guarda una copia del estado actual (deshacer) y luego `Reload()`.
- **No llama a `GuardarPuntos()`**: los puntos en memoria son los viejos y pisarían el ini recién restaurado.
- Sin backups, el botón está deshabilitado y la función sale sin abrir diálogo.
- El "último" se ordena por **el sello del nombre**, no por la fecha de modificación (ver §3, bug real corregido).
- Dos clics en el mismo segundo no se pisan: `_PtsSelloLibre()` espera al siguiente segundo.

### UX pestaña 2
- **Desactivados al final**: reorder estable en dos pasadas (activos en orden de catálogo, luego desactivados
  en orden de catálogo). La selección se restaura **por id de evento**, no por índice de fila.
- **Más contraste en la fila seleccionada**: `Background16161E c8A93A6` en el ListView (base apagada para que
  el resaltado del sistema salte) + banner `stEv` en `Background2A2140 cFFFFFF`, negrita, que muestra el
  nombre completo de la acción. Verificado por lectura LVM: fondo `0x1E1616`, texto `0xA6938A` (BGR).
  *Se descartó `NM_CUSTOMDRAW`*: fuera de pantalla solo llega `CDDS_PREPAINT` y un `OnMessage(0x4E)` global
  puede interferir con el `ItemSelect`/`DoubleClick` del propio AHK.
- Columna **Duración** (6ª) y fila `Duración de este evento (ms)` + `⏱ Aplicar` + etiqueta `Efectiva: N ms · origen`.
  Aplica a **toda la selección múltiple**. Vacío = hereda. Acepta el atajo `3` = 300 ms. Rango 1..60000.
- El panel de duraciones por prioridad ahora escribe **también** `[HudDuracion<PERFIL>]` (`alta|media|baja`, en ms
  ya normalizados), que es lo que lee `HudDuracionDe()`, y sigue escribiendo `[HudDuraciones<PERFIL>]` para
  `HudDuracionZona()`. Antes el panel escribía una sección que el motor nuevo no lee.

---

## 3. Bugs reales encontrados y corregidos (con evidencia)

1. **`_gDurCache` quedaba stale.** `core_config.ahk:138` solo limpia la caché en `_FlushIni()`, que dispara
   `GuardarIniDiferido`. El calibrador escribe con `IniWrite` directo → `HudDuracionDe()` devolvía el valor
   viejo después de guardar. Arreglado: `_gDurCache.Clear()` en `_PtsEvDurAplicar` y `_GuardarDuracionesHUD`.
   Prueba T12: escribir 1234 tras haber cacheado 900 → el motor devuelve 1234.
2. **El "último backup" podía ser el equivocado.** `FileCopy` **hereda la fecha de modificación del original**.
   Evidencia medida: `posiciones_gui_20261107_222037.bak.ini` tiene `LastWriteTime 22:18:28` (el del ini), no
   22:18:29 (su creación). Con granularidad de 1 s, dos copias seguidas **empatan** y `Loop Files` se queda con
   la primera → el botón de deshacer restauraba otro estado. Arreglado ordenando por el sello del nombre
   (`yyyyMMdd_HHmmss`, que además es un timestamp AHK válido para `FormatTime`). Prueba T16d.
3. **Colisión de nombres en el mismo segundo.** `FileCopy` sin overwrite lanza si el destino existe: crear
   backup y restaurar en el mismo segundo abortaba la restauración. Arreglado con `_PtsSelloLibre()`. T14e.
4. **La etiqueta mentía al heredar.** Sin clave `zona_<id>` en el ini, `HudDuracionDe()` cae en
   `_HudDuracionDefecto(id)` (1200 para `capa_ocultar`), **no** en la prioridad. La etiqueta decía
   "heredada de Baja" mientras mostraba 1200 ms (Baja = 400). Ahora dice `por defecto del evento` cuando
   el valor no coincide con `HudDuracionZona(z)`. T10b.
5. **Índice de fila viejo tras el reorder.** `_PtsEvCambio` nombraba el evento usando la fila previa al
   rebuild → con los desactivados movidos, el status podía nombrar otro evento. Ahora captura `evNom`
   antes de `_PtsEvFilas()`. T06.

### Prueba de guardar el ini y comparar contra el backup (lo pide el brief)
Verificada **dos veces por caminos distintos**:
- Dentro del arnés (memcmp sobre `FileRead(...,"RAW")`): backup == ini byte a byte → PASS T14b.
- Fuera de AHK, con `Get-FileHash` de PowerShell sobre los artefactos generados:
  ```
  b8cce8effe4deba55d176cda459e68be6bcbb86faa0efea34512b4dfef13c411  posiciones_gui_20261107_222037.bak.ini  13074
  b8cce8effe4deba55d176cda459e68be6bcbb86faa0efea34512b4dfef13c411  snap_pre_restore.ini                    13074
  999b974f6f7e2b34277cc394323867b236f2c560a56f0d8d388910ef106c59bb  posiciones_gui_20261107_222038.bak.ini  13134  <- copia de deshacer, con el marcador
  ```
  El backup es idéntico al ini del momento de la copia; la copia previa a restaurar es distinta y conserva
  el marcador (T16c/T16e), o sea el deshacer funciona. El ini sigue en **UTF-16LE** (`FF FE`, T17).

### Arnés
47 pruebas, 0 fallos. Corre en `%TEMP%` sobre copias byte-idénticas, con GUI en `x-32767 y-32767` y
`NoActivate` (no roba foco ni tapa la pantalla del usuario). Log completo archivado en
`_backups/qoder_ola6_pruebas.txt`; arnés en `_backups/qoder_ola6_arnes.ahk.txt` (extensión .txt a propósito:
no deja un .ahk ejecutable suelto en una carpeta que el usuario explora).

---

## 4. Pendientes de OTROS agentes (Qoder no tocó sus archivos)

### 4.1 Cline — `core_config.ahk:333` y `:335`: sección mal concatenada  **[ALTA]**
```ahk
d := Trim(IniRead(ini, "HudEventos2" PERFIL, "duracion_" id, ""))   ; -> [HudEventos22] con PERFIL=2
if (d = "")
    d := Trim(IniRead(ini, "HudEventos2", "duracion_" id, ""))      ; -> [HudEventos2] literal
```
Debería ser `"HudEventos" PERFIL`. Con `PERFIL=2` funciona **por accidente** (el fallback literal
`[HudEventos2]` es justo la sección del perfil 2). Con `PERFIL=1` o `3`, **ignora la duración que el usuario
acaba de guardar**. Evidencia (T19 del arnés):
```
INFO T19 PERFIL=1: [HudEventos1]duracion_capa_ocultar=777 pero HudDuracionDe=300
```
Mismo patrón en `_HudDuracionZonaDeId` (`:356-358`), aunque ahí sí hay fallback correcto a
`"HudEventos" PERFIL` en `:360`, así que la zona sí se resuelve bien.

### 4.2 Cline — `HudDuracionDe` no normaliza el atajo de segundos  **[MEDIA]**
`HudDuracionZona` (`:319`) hace `if (val <= 10 && val > 0) val := val * 100`; `HudDuracionDe` (`:337,346`)
hace `d * 1` a secas. Un `alta=3` escrito a mano significa 300 ms para una función y **3 ms** para la otra.
Qoder lo resolvió en su lado normalizando **antes de escribir** (tanto `duracion_<id>` como `[HudDuracion…]`),
así que el ini que sale del calibrador ya está en ms reales. Si alguien escribe esas claves a mano o desde
otro módulo, la divergencia sigue ahí.

### 4.3 Cline — invalidación de `_gDurCache`  **[MEDIA]**
Solo `_FlushIni()` la limpia. Cualquier módulo que escriba duraciones con `IniWrite` directo (no con
`GuardarIniDiferido`) debe limpiarla o el motor sigue mostrando el valor viejo. Qoder ya lo hace en sus dos
escritores; conviene documentarlo en la API pública o exponer un `_DurCacheClear()`.

### 4.4 OpenCode / Cursor — `MacroCapas_Ejecutar` no tiene ningún llamador  **[ALTA]**
`hotkeys_csp.ahk:794` define la función del contrato, pero **nadie la llama** (grep en todo el proyecto:
solo la definición). `_CicloO()` (`:778-790`, disparado por `$o::` en `:777`) sigue mandando
`MostrarMiniTexto` por paso, así que el evento `macro_capas` **nunca se emite**. La fila del calibrador existe
y se puede configurar, pero está muerta hasta que se conecte (botón HUB o el propio ciclo O).
Qoder etiquetó la fila como `Macro de Capas 1→2→3 (O / − va por pasos)` para no anunciar un atajo que no la dispara.

### 4.5 OpenCode — `mascara_recorte` manda M, no recorte  **[MEDIA]**
`hotkeys_csp.ahk:851-857`: `~RButton & s:: Send("m")` con comentario propio de OpenCode:
*"Tu CSP no tiene atajo para layerchangebelowclip (recorte real); si se lo asignas, cámbialo aquí."*
M = máscara de capa. El ID del contrato se respetó, pero la etiqueta dice la verdad:
`Máscara de Capa / Recorte (RButton + S → M)`. Si el usuario asigna el atajo de recorte real, hay que
actualizar el `Send` **y** la etiqueta del calibrador.

### 4.6 Cline — `hud_badges.ahk:360-361` sigue enrutando al ID legacy  **[BAJA]**
```ahk
if InStr(t, "HIDE LAYER") || InStr(t, "SHOW LAYER") || InStr(t, "VISIBILIDAD")
    return "capa_visibilidad"
```
El atajo vivo ya emite `capa_ocultar` / `capa_mostrar` por `_AvisoEvento` directo, así que esas tres cadenas
deberían rutear a los IDs nuevos si alguna ruta de `MostrarAvisoUI` las sigue usando. Qoder conservó
`capa_visibilidad` (es clave del ini, no se puede borrar sin perder configuración) y la etiquetó `heredado`.

### 4.7 Tooling — `/validate` de un módulo suelto cuelga un modal  **[AVISO AL EQUIPO]**
`lib/calibrador.ahk` y `lib/core_config.ahk` validados **solos** producen un diálogo modal de `#Warn`:
*"This local variable appears to never be assigned a value. Specifically: ptsEd"* — porque los super-globals
los declara el driver. **`/ErrorStdOut` NO suprime los warnings de carga**, solo los errores. Eso dejó varios
diálogos huérfanos titulados `calibrador.ahk` durante la ola (ya no queda ninguno). Regla: validar siempre
**el driver**, y si se quiere probar un módulo aislado, declarar antes los super-globals del driver y poner
`#Warn All, OutputDebug` (así está hecho el arnés archivado).

---

## 5. Lo que falta para cerrar la ola

1. **Prueba visual del usuario en CSP** (recarga en vivo): pestaña 2 → contraste de la fila seleccionada,
   desactivados al final, columna Duración, `⏱ Aplicar` en selección múltiple; pestaña 3 → `💾 Crear backup`
   y `↩ Restaurar último` (el restaurar reinicia el script, es esperado).
2. **Cline**: §4.1 (crítico para perfiles 1 y 3), §4.2, §4.3, §4.6.
3. **OpenCode/Cursor**: §4.4 (conectar `MacroCapas_Ejecutar`), §4.5 (atajo de recorte real).
4. **Antigravity**: integrar en el orden del brief (Cline + Claude 1 → Claude 2 + OpenCode → Cursor + Qoder)
   y empaquetar. Qoder no renombró `[LayoutNormal]` / `[LayoutEnfoque]` ni tocó `companion.ahk`,
   `hud_badges.ahk`, `theme_gfx.ahk`, `audio.ahk`, `estab_slider.ahk`, `hotkeys_csp.ahk` ni `core_config.ahk`.

---

FINALIZADO, REALIZAR PRUEBAS EN ANTIGRAVITY

```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\XPPEN AHK VERSION ESTABLE.ahk"
```
*(Qoder lo corrió con `MSYS_NO_PATHCONV=1 … /ErrorStdOut /validate` desde Git Bash → **exit 0**.)*