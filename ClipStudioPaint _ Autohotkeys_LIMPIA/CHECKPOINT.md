# CHECKPOINT — Clip Studio Paint Companion (AutoHotkey v2)
**Fecha y Hora:** 2026-11-14 14:15:00 (GMT-5)  
**Ubicación Principal del Proyecto (Única Oficial):** `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\`  
**Estado General:** ESTABLE — Calibrador Pestaña 2 rediseñada (Ajustar zona interactivo, atenuación real con silueta [anterior], dibujo en cadena desde fila seleccionada, barra de modos ergonómica), persistencia manual de perfiles (firmaManual), reposicionamiento automático de lienzos en modo Enfoque, y sincronización de perfiles en `posiciones_gui.ini`. Validado con AutoHotkey 2.0 (`/validate` → exit code 0) y probado en runtime sin admin.

---

## 1. Novedades y Mejoras de Esta Fase

| # | Módulo / Área | Estado | Detalle de Cambios y Optimizaciones |
|---|---|---|---|
| **1** | **Persistencia de Perfiles y Selección Manual (`lib/core_config.ahk`)** | ✅ **COMPLETO Y PROBADO** | • **`firmaManual`**: Cuando el usuario selecciona manualmente un perfil en el Calibrador o Tray, se guarda `firmaManual`. `ElegirPerfil()` respeta la elección del usuario y evita que el script vuelva a revertir automáticamente a otro perfil tras `Reload()` o al iniciar.<br>• Si el hardware cambia a otro perfil coincidente, se libera `firmaManual` de forma limpia. |
| **2** | **Sincronización de Perfiles en INI (`posiciones_gui.ini`)** | ✅ **APLICADO** | • Perfil 1 (Laptop + Tableta) sincronizado con las coordenadas positivas y zonas del Perfil 2 (Monitor + Tableta).<br>• Duplicado del modo Normal hacia modo Enfoque para Perfil 1 preservando firmas de pantalla independientes. |
| **3** | **Reposicionamiento Automático de Ventanas (`lib/companion.ahk`)** | ✅ **COMPLETO Y PROBADO** | • **`NvReposicionarVentanas()`**: Con `SetWinDelay(-1)` y llamado diferido vía `SetTimer` desde `AccionEnfoque()` para mover y acomodar automáticamente las ventanas de lienzo (1..8) a sus respectivas zonas asignadas (`NvZona1..8`) al alternar entre modo Normal y Enfoque sin añadir latencia perceptible. |
| **4** | **Rediseño Completo de Pestaña 2: Zonas y Rangos (`lib/calibrador.ahk`)** | ✅ **COMPLETO Y VALIDADO** | • **Barra de modos superior**: Espaciado central de 12 px con separador grabado vertical (`SS_ETCHEDVERT`), iconos `🖼 NORMAL · Modo 1` y `🎯 ENFOQUE · Modo 2`, barras de progreso de 6 px con fondo visible `D0D0D0` y azul `4A90E2`, y botones `💾` con tipografía `Segoe UI Emoji`.<br>• **ListView ampliado**: Reubicado a `y=134` con altura extendida a `h=266` (60 px adicionales) permitiendo ver 3-4 filas más directamente.<br>• **Eliminación del grupo estático numérico**: Removidos los 4 campos de texto (`X`, `Y`, `Ancho`, `Alto`) y el botón `✔ Aplicar valores`.<br>• **Nueva botonera de acciones (`y=406`)**: Organizada de izquierda a derecha en `[✏ Dibujar zona]` + `[⏩ En cadena]` (unificados), `[📐 Ajustar zona]`, `[👁 Ver zonas]` y `[↺ Por defecto]`. |
| **5** | **Herramienta Interactiva `[📐 Ajustar zona]` (`lib/calibrador.ahk`)** | ✅ **COMPLETO Y PROBADO** | • Sustituye los campos numéricos por un manipulador interactivo en pantalla (`_PtsEditarRangoInteractivo`).<br>• Monta una caja cian directamente sobre la posición actual con agarraderas de estiramiento en las 4 esquinas y 4 bordes (`NcHit`), permitiendo arrastrar para mover o estirar milimétricamente con el lápiz y confirmar con `Enter`. Normalización de puntos nulos a `{x, y, w: 0, h: 0}` para total seguridad de tipos en AHK v2. |
| **6** | **Dibujo en Cadena desde Fila Actual (`lib/calibrador.ahk`)** | ✅ **COMPLETO Y PROBADO** | • `_PtsFilaActual()` consulta `GetNext(0, "F")` (fila enfocada) y `GetNext(0)` (seleccionada), garantizando que el dibujo en cadena comience exactamente desde la fila activa en el ListView y no reinicie desde el principio. |
| **7** | **Atenuación Real con Silueta [anterior] (`lib/calibrador.ahk`)** | ✅ **COMPLETO Y PROBADO** | • `_PtsOvlAtenuar(on, dActual)`: Las demás zonas **no desaparecen** al dibujar o ajustar; permanecen en pantalla con opacidad tenue (~45) como marco y guía visual.<br>• La zona que se está calibrando proyecta su **silueta previa en cian brillante con la etiqueta `[anterior]`** a opacidad 170 para saber con exactitud dónde estaba antes.<br>• Corrección de capas (Z-Order): Las cajas de referencia se ordenan por encima de la cortina oscura `ov`. |
| **8** | **Desbloqueo de Captura con Stylus / LButton (`lib/calibrador.ahk`)** | ✅ **BLINDADO** | • Desacople de la guardia de reentrancia en `_PtsDibujarRango()` mediante `static enRango := false`, resolviendo el bug donde `_PtsOvlAtenuar(true)` bloqueaba la apertura de la ventana de dibujo.<br>• Añadido `KeyWait("LButton")` para que el clic del botón o el doble toque del ListView no se consuman como inicio involuntario del trazo. |
| **9** | **Robustez y Validación Sintáctica** | ✅ **EXIT CODE 0** | • Validación AHK v2 estricta (`/validate /ErrorStdOut`) en `XPPEN_NO_ADMIN.ahk` y `XPPEN AHK VERSION ESTABLE.ahk`.<br>• Pruebas en runtime no-admin: inicio limpio sin cuadros de diálogo modales `#Warn`, cierre ordenado de procesos. |

---

## 2. Archivos Oficiales en Producción

- **Script Principal (Elevado Admin):** `XPPEN AHK VERSION ESTABLE.ahk`
- **Script de Pruebas (No Admin):** `XPPEN_NO_ADMIN.ahk`
- **Módulos (`lib/`):**
  - `lib/core_config.ahk`: Monitor, lecturas INI, cálculo de anclas, anchos dinámicos y persistencia manual de perfil (`firmaManual`).
  - `lib/theme_gfx.ahk`: Motor de tokens de diseño y perfiles de paleta.
  - `lib/audio.ahk`: Retroalimentación auditiva sintetizada de eventos, racha Undo/Redo y calibración.
  - `lib/hud_badges.ahk`: Indicadores visuales modernos y badges con brackets de 90°.
  - `lib/companion.ahk`: Píldoras flotantes, menú táctil WINDOW, reposicionador de lienzos (`NvReposicionarVentanas`) y gestión física de lienzos CSP.
  - `lib/calibrador.ahk`: Panel central de 5 pestañas: Zonas, Eventos HUD, Sistema/Perfiles, Paleta de Temas y Nuevas Ventanas.
  - `lib/estab_slider.ahk`: Slider universal y memoria por herramienta.
  - `lib/hotkeys_csp.ahk`: Mapeo atómico de teclas, stylus combos, contador de racha y aislamiento `#HotIf`.
- **Persistencia:**
  - `posiciones_gui.ini`: Calibración de geometrías, zonas de pantalla (`[Rangos1]`, `[Rangos2]`), duraciones y estados de modo.
  - `theme.ini`: Configuración activa de colores, fuentes, radios y animaciones.

---

## 3. Guía Rápida para el Próximo Chat

1. **Estado del Código:** Todo el código vivo está aplicado directamente en la carpeta raíz oficial `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\`. No hay archivos temporales ni pendientes de validación.
2. **Para pruebas locales en caliente:** Usar siempre primero `XPPEN_NO_ADMIN.ahk` sin elevar, o pulsar `[🔄 Reiniciar script]` desde la interfaz del Calibrador (`^F10`).
3. **Flujo de calibración activo:**
   - Para ajustes finos sin redibujar: botón **`[📐 Ajustar zona]`**.
   - Para redibujar: botón **`[✏ Dibujar zona]`** o **`[⏩ En cadena]`** (muestra la silueta anterior en cian y las demás zonas atenuadas).
