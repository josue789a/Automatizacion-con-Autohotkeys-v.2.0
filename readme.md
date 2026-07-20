# Sistema de Automatización para Flujo de Trabajo Digital

Motor de automatización que reconstruye desde cero la capa de interacción entre un usuario y una herramienta de software, coordinando más de 60 acciones contextuales sobre ~1,900 líneas de lógica basada en eventos y estados.

El sistema combina presiones simples, dobles y sostenidas; modificadores estándar (Alt, Shift, Ctrl) y modificadores no convencionales (Espacio, Tab) — estos últimos necesarios porque la aplicación base no permite reasignar ciertas combinaciones por defecto. Cada acción tiene su propio timing calibrado individualmente, en vez de un valor genérico compartido.

Incorpora también retroalimentación visual y sonora en tiempo real, diseñada para que el usuario pueda operar el sistema por reconocimiento de patrones (un sonido o un indicador visual específico) sin necesidad de mirar la pantalla para confirmar que una acción se ejecutó correctamente. Algunas acciones son condicionales sobre eventos internos previos — es decir, una señal (sonido o indicador) solo se dispara si una acción anterior ya ocurrió, permitiendo secuencias de estado de varios pasos en vez de acciones aisladas. El sistema incluye además su propia capa de diagnóstico: detección de estados inconsistentes, reinicio selectivo de interfaces sin reiniciar el programa completo, y recarga automática ante cambios en el propio código.

## Subsistemas que lo componen

- **Desambiguación de combos multi-fuente.** Distingue tap simple, doble-tap y combinaciones sostenidas entre stylus, teclado auxiliar y teclado estándar, todo dentro de ventanas de tiempo calibradas individualmente (300ms, 2400ms, etc. según el caso), sin que un evento pise al otro.
- **Resolución de eventos sintéticos vs. reales.** El stylus reporta "botón soltado" en 0–15ms, indistinguible a simple vista de un evento generado por el propio script para desbloquear una acción. Se resolvió midiendo la ventana de tiempo entre eventos (umbral de 70ms) para no duplicar ni perder acciones — clave para que una acción como "deshacer múltiple" funcione de forma fluida y no a saltos.
- **Detección dinámica de ventanas flotantes.** El software genera paneles (selector de color, círculo de color, accesos rápidos) con handles que cambian en cada sesión. El sistema los localiza en tiempo real por fragmentos de título, sin coordenadas fijas ni configuración manual.
- **Paneles que aparecen al pasar el cursor.** Los paneles flotantes permanecen casi invisibles y no interceptan la vision de lo que haya detras de él hasta que el cursor entra en su zona real, momento en que se vuelven visibles e interactivos. Esta zona se recalcula en cada ciclo porque su posición cambia con el layout del monitor.- **Zonas de activación calibradas por DPI.
- ** 5 zonas de pantalla mapeadas a nivel de píxel, con conciencia de escalado de Windows para no desalinearse entre monitores de distinta resolución.
- **Interfaz de estado persistente.** Un indicador flotante propio, siempre visible, que muestra en qué modo opera el sistema en cada momento, sin depender de la UI nativa del software.
- **Auto-diagnóstico y recuperación.** Un control dedicado destruye y reconstruye todas las interfaces del sistema si algo queda en estado inconsistente, sin reiniciar el programa completo. El script también se auto-recarga al detectar cambios en su propio archivo.
- **Versionado integrado al flujo.** Un atajo dedicado ejecuta commit + push con timestamp automático, para iterar sobre el sistema sin salir del entorno de trabajo.

## Impacto estimado en tiempo

Cada corrección manual de herramienta, cada búsqueda de panel, cada combinación fallida por timing, son segundos que se acumulan por decenas a lo largo de una sesión. Tomando una estimación conservadora de ~20 minutos ahorrados por jornada de 8 horas (variable según cuánto dependa el usuario de atajos), el impacto proyectado es:

| Período | Ahorro estimado |
|---|---|
| Diario | ~20 min |
| Semanal (5 jornadas) | ~1.5–2 horas |
| Mensual (~20 jornadas) | ~6–7 horas |

En términos relativos, equivale a recuperar casi un día completo de trabajo cada mes — sin contar la reducción de fricción y fatiga por repetición, que no se mide en minutos pero afecta directamente la calidad del trabajo sostenido.


## ¿Es trasladable a otros entornos?

Sí. El sistema fue construido para una herramienta específica, pero ninguno de sus mecanismos centrales depende de ella:

- La desambiguación de eventos por timing (tap simple vs. doble vs. sostenido) aplica a cualquier input físico — stylus, teclado, mando, sensor.
- La detección dinámica de ventanas por fragmento de título, en vez de handles fijos, funciona contra cualquier aplicación de escritorio que genere ventanas flotantes o modales.
- El patrón de "observar estado externo → decidir acción según contexto" es el mismo que sostiene automatización de flujos entre aplicaciones sin API oficial, sincronización de datos entre sistemas legados, o cualquier proceso donde una acción del usuario deba traducirse en una secuencia condicional de pasos.

Migrar el sistema a otro software de destino implicaría remapear las zonas de pantalla y los fragmentos de título — no rediseñar la arquitectura de eventos y estados que lo sostiene.

## Stack
AutoHotkey v2 · Event-driven architecture · State machines · Real-time window & zone detection · Git automation

## Herramienta de calibración (CALIBRADOR_v3_DPI)

El sistema incluye un calibrador independiente que resuelve la recalibración de las 5 zonas de activación cada vez que cambia el hardware (tableta o monitor). Usa la misma DPI awareness que el motor principal, así que basta con capturar (F1) los mismos puntos de referencia que definen cada zona en el código, copiarlos (F2) y reemplazar las coordenadas viejas — sin tener que calcularlas ni editarlas a ciegas.

Uso: F1 captura la coordenada del punto donde está el cursor, F2 copia todos los puntos capturados al portapapeles listos para pegar en el script principal, y F3 limpia la lista para una nueva ronda. Incluye además un modo de coordenadas en vivo (F4) para ubicar bordes exactos con precisión de píxel.

Una recalibración completa toma segundos en vez de editar coordenadas a ciegas dentro del código del motor principal.
