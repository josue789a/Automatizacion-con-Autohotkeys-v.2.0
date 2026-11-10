# Proyecto AHK — Clip Studio Paint

> [!IMPORTANT]
> **DIRECTORIO RAÍZ DEL PROYECTO (ÚNICA FUENTE DE LA VERDAD / MAIN OFICIAL):**
> `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\`
> Todas las modificaciones, parches y validaciones deben realizarse EXCLUSIVAMENTE sobre esta carpeta y sus submódulos en `lib/`. Cualquier archivo o script en otras rutas es obsoleto o histórico.

- **Script principal de producción:** `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\XPPEN AHK VERSION ESTABLE.ahk` (AutoHotkey v2, elevado a Administrador).
- **Script de pruebas sin admin:** `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\XPPEN_NO_ADMIN.ahk`.
- **Perfiles/calibración:** `posiciones_gui.ini`.
- **Reglas originales:** `PureRef/Reglas_PureRef.md`.

## Reglas obligatorias de flujo y ejecución

- **Límite de reintentos (Fail-Fast a 2 intentos)**:
  - Máximo 2 intentos autónomos para resolver un bug, ajuste fino o tarea compleja.
  - Al 3.er intento sin éxito, DETENERSE de inmediato, reportar el diagnóstico exacto del bloqueo y solicitar confirmación expresa del usuario antes de continuar o delegar a Claude. Prohibido entrar en bucles de prueba prolongados.
- **Procesamiento atómico (Paso a paso)**:
  - Si una solicitud contiene múltiples temas, atajos o requerimientos complejos, descomponerlos y abordarlos uno por uno. Nunca intentar resolver todo simultáneamente en un solo bloque.
- **Guardia ante ambigüedad o falta de detalle (Pausa de Clarificación)**:
  - Si una instrucción es abstracta, poco específica o faltan detalles técnicos (atajo exacto, comportamiento del stylus, coordenadas o estados), NO asumir ni adivinar código: emitir un aviso claro y pedir clarificación puntual antes de modificar archivos.
- **Pruebas en entorno sin Admin primero (`XPPEN_NO_ADMIN.ahk`)**:
  - Todo cambio se ejecuta y verifica primero en `XPPEN_NO_ADMIN.ahk` (modo usuario estándar).
  - Verificar en runtime la ausencia de cuadros de diálogo modales `#Warn` y que el proceso finalice limpiamente sin dejar procesos huérfanos ni exigir cierre manual desde la bandeja.
  - En pruebas locales, asegurar directivas no-bloqueantes (`#Warn All, OutputDebug` / `StdOut`) para que ningún warning levante popups modales en la barra de tareas.
  - Mantener atajo de salida de emergencia (`^!+q:: ExitApp()`) y ciclo de vida limpio con `OnExit` (detener timers, destruir GUIs y `GdiplusShutdown`).
- **Economía de Tokens y Delegación Quirúrgica (/delegar y /delegara)**:
  - Prohibido pasar archivos enteros de miles de líneas a agentes en la nube (Claude/Cline).
  - Enviar exclusivamente el bloque vivo a modificar (5-10 líneas de contexto) y una lista de 1 línea por firma de funciones auxiliares existentes.
  - En auditorías y bugs complejos, aplicar siempre la Estrategia en 2 Fases: Fase 1 = Diagnóstico/Informe (cero código); Fase 2 = Parche atómico por chat limpio.
- **Entrega por Diffs Exactos (Zero-rewrite)**:
  - Solo tras comprobar el éxito en el entorno sin admin, se replican únicamente las líneas y bloques exactos en la versión principal (`XPPEN AHK VERSION ESTABLE.ahk` y `lib/`). Nunca reescribir ni reestructurar scripts completos.
- **Respaldo previo**:
  - Crear un `.bak` antes de guardar cualquier cambio en archivos de `lib/` o principales.
- **Validar siempre antes de entregar**:
  ```powershell
  & "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "<archivo>.ahk"
  ```
  Código de salida `0` = sintaxis correcta.
- **Aislar por `#HotIf`**:
  - CSP (`ahk_exe CLIPStudioPaint.exe`) y PureRef (`ahk_exe PureRef.exe`) no deben cruzar pulsaciones.
- **Stylus combo**:
  - Cada combinación con el lápiz (`~RButton & tecla`) debe marcar `stylus.comboUsado := true`.

## Módulos

- `XPPEN AHK VERSION ESTABLE.ahk`: lanzador principal elevado a Administrador.
- `XPPEN_NO_ADMIN.ahk`: réplica idéntica sin auto-elevación para pruebas locales y verificación automatizada.
- `lib/core_config.ahk`: cálculo de monitores, lecturas de INI, caché de duraciones.
- `lib/hud_badges.ahk`: badges y avisos HUD (modo moderno con brackets 90°, modo bruto, `_HudRangoEv`).
- `lib/calibrador.ahk`: panel de calibración de zonas, duraciones, edición directa de texto de eventos y reubicación.
- `lib/hotkeys_csp.ahk`: atajos de teclado y combinaciones con el stylus en CSP.
- `posiciones_gui.ini`: persistencia de coordenadas, rangos (`[Rangos<P>]`), duraciones y textos personalizados.
