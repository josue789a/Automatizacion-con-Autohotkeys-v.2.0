# Informe de Diagnóstico y Solicitud de Parche — Sistema Companion

## 1. Informe de Diagnóstico (Fase JIT-1)

*   **Identificación del Problema:** Bucle de reescalado constante durante transiciones multi-monitor causado por eventos `WM_DPICHANGED`.
*   **Evidencia:** El log `logs/companion_trans.log` registra ráfagas de `WM_DPICHANGED` con `dpi=144`. Este valor indica que Windows intenta ajustar el escalado de las ventanas constantemente al cruzar monitores con diferentes densidades de píxeles.
*   **Comportamiento en Runtime:** 
    *   La falta de una bandera de "transición" permite que los timers (`LoopColorV`, `LoopColorCC`, `LoopAccesoRapido`) continúen ejecutando operaciones de reposicionamiento (`WinMove` / `SetWindowPos`) sobre ventanas cuyo DPI está cambiando, lo que deriva en los fallos visuales (texto negro, invisibilidad) y reacomodos múltiples.
    *   La identificación de monitores por índice está provocando que la ventana nazca erróneamente en el monitor principal.
*   **Componente afectado:** `lib/companion.ahk` (confirmado mediante inspección de código: contiene lógica de hover, paneles y `BorderFrame`).

---

## 2. Solicitud a Claude (Plan de Parche — Fase JIT-2)

**Objetivo:** Aplicar el parche estructural para estabilizar las transiciones multi-monitor.

**Instrucciones para el parche:**
1.  **Bloqueo de Timers:** Implementar bandera global `_trans` para detener timers durante movimientos.
2.  **Mecánica de Mover en 2 Fases:**
    *   Fase 1: Mover ventana al destino con tamaño mínimo.
    *   Fase 2: Esperar asentamiento de DPI + SetWindowPos final con coordenadas correctas.
3.  **Control de Reintentos:** Sustituir los 4 intentos actuales por un único reintento verificado.
4.  **Limpieza:** Aplicar `RedrawWindow` únicamente al finalizar la transición.
5.  **Detección de Monitores:** Refactorizar `ObtenerMonitorCSP()` para resolver por resolución/nombre de dispositivo en lugar de índice.
6.  **Validación:** Entregar diffs zero-rewrite con anclas exactas para `lib/companion.ahk`. Verificar sintaxis con `AutoHotkey64.exe /validate` contra `XPPEN_NO_ADMIN.ahk`.

---

**Nota:** Por favor, proceda con la generación del parche basándose en esta evidencia. He verificado que `lib/companion.ahk` es el archivo correcto.
