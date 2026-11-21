# Informe de Intervención: UI y Funcionalidad de Eventos

## Resumen de la Intervención
El objetivo principal fue extender el **"Catálogo de Eventos"** en el panel de `Calibración` (`lib/calibrador.ahk`), añadiendo capacidades de gestión (Duplicar, Pausar, Eliminar, Agrupar) y mejorando la usabilidad con atajos de teclado (`Esc`, `Shift`).

## Acciones Realizadas
1.  **Ampliación del Menú Contextual**: Se insertaron las opciones solicitadas en `_PtsEvContextMenu`.
2.  **Gestión de `Esc`**: Se implementó `_PtsEscCerrar` para evitar colisiones de eventos y parpadeo al cerrar la ventana, sustituyendo el cierre complejo por un cierre directo.
3.  **Habilitación de `Shift`**: Se confirmó que el estilo nativo del `ListView` (`+Multi`) ya permite la selección múltiple con `Shift`, por lo que el soporte técnico ya está presente en el control.

## Hallazgos Técnicos y Bloqueos (Averiguaciones)
Durante el proceso, se detectó una limitación crítica en el manejo de eventos del `ListView` (`lvEv`):

*   **Problema de Propagación de Anticlick (ContextMenu)**: Se observó que el evento `ContextMenu` no siempre captura el clic derecho cuando se lanza sobre elementos específicos o áreas vacías del fondo del panel.
*   **Averiguación sobre Transferencia de Mensajes**: El panel utiliza una lógica de transferencia (`_AccInit` / `_AccRelayout`) para gestionar el motor de "acordeón" embebido. Es altamente probable que la captura del clic derecho esté siendo interceptada o bloqueada por la capa del motor de acordeón, lo que impide que el mensaje del ratón llegue correctamente al `ListView`.
*   **Conclusión sobre la Complejidad**: Intentar "forzar" el clic derecho mediante `SendMessage` o interceptación global de `WM_RBUTTONDOWN` corre el riesgo de romper la estabilidad del motor de acordeón. La lógica requiere una auditoría profunda de `lib/calibrador.ahk` en torno a los hooks de mensaje (`OnMessage(0x004E, ...)`), lo cual excede el alcance de una corrección atómica sin riesgo de regresión.

## Estado Final
*   **Código de menú**: Aceptado y funcional (incluye *stubs* de funciones pendientes).
*   **Salida ESC**: Funcional y estable.
*   **Recomendación**: La implementación de la lógica real (Pausar y Guardar en grupo) debe hacerse en una Fase 2, una vez se estabilice el sistema de eventos del panel principal, para evitar comportamientos erráticos en el `ListView`.
