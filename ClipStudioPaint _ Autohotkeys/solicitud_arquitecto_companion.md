# Solicitud de Análisis y Solución - Sistema Companion Multi-Monitor

**Fecha:** 2026-11-18  
**Proyecto:** AHK Global - Clip Studio Paint Automation  
**Solicitante:** Equipo de Desarrollo  
**Prioridad:** Alta - Bloqueante para flujo de trabajo multi-monitor  

---

## 🎯 Resumen Ejecutivo

El sistema companion, componente esencial de la automatización para Clip Studio Paint, presenta un comportamiento inconsistente y errático durante transiciones entre monitores (tableta vs monitor principal). El problema manifiesta en bloqueos visuales, reacomodos incorrectos y fallos en la sincronización de estado, afectando directamente la productividad del usuario.

---

## 📋 Contexto del Sistema

### Arquitectura Actual
- **Motor:** AutoHotkey v2 con enfoque event-driven
- **Componentes principales:**
  - Detección dinámica de ventanas flotantes (deslizador, círculo, acceso rápido)
  - Sistema de hover interactivo con paneles
  - Gestión de enfoque y modos de visualización
  - Sistema de estabilización de herramientas
  - HUD lienzo para zoom/rotar/mover
  - Gestión multi-lienzo con rangos personalizados

### Flujo de Trabajo Esperado
1. El companion debería nacer consistentemente en la tableta (monitor secundario)
2. En escenarios donde nace en el monitor principal, la transición a tableta debería ser fluida
3. El sistema debe mantener estado consistente sin bloqueos visuales o reacomodos múltiples

---

## 🚨 Problema Detallado

### Comportamiento Actual (Defectuoso)

#### Escenario 1: Nacimiento Incorrecto
- **Comportamiento:** El companion aparece ocasionalmente en el monitor principal en lugar de la tableta
- **Frecuencia:** Intermitente pero predecible en ciertas condiciones
- **Impacto:** Requiere intervención manual para reubicar

#### Escenario 2: Transición Fallida (El principal problema)
Cuando se intenta mover el companion del monitor principal a la tableta:

1. **Bloqueo a medio camino:** El proceso se detiene durante la actualización
2. **Corrupción visual:** Aparecen partes negras en el texto de la interfaz
3. **Reacomodos erráticos:** Los elementos se reubican incorrectamente
4. **Invisibilidad temporal:** El companion se vuelve invisible y se detiene
5. **Reintentos múltiples:** El sistema intenta avanzar parcialmente (hasta 4 veces)
6. **Reacomodo final:** Cuando finalmente llega a la tableta, se reacomoda nuevamente

### Secuencia de Fallos Observada
```
Inicio → Bloqueo → Texto negro → Reacomodo → Invisibilidad → Reintento (1/4) → Avance parcial → Bloqueo → Reintento (2/4) → ... → Llegada a tableta → Reacomodo extra
```

---

## 🔍 Análisis Preliminar de Causas

### Hipótesis Principales

#### 1. **Problema de Detección de Monitores**
- **Ubicación:** `IniciarDeteccion()` y funciones relacionadas en `companion.ahk`
- **Sospecha:** La lógica de `ObtenerMonitorCSP()` no está considerando correctamente cambios dinámicos en la configuración de monitores
- **Evidencia:** El companion nace en lugares incorrectos, indicando problema en la detección inicial

#### 2. **Sincronización de Estado en Transiciones**
- **Ubicación:** Funciones de hover y manejo de ventanas flotantes
- **Sospecha:** Los timers (`LoopColorV`, `LoopColorCC`, `LoopAccesoRapido`) no están sincronizados durante cambios de monitor
- **Evidencia:** Bloqueos y corrupción visual sugieren competencia de acceso a recursos compartidos

#### 3. **Manejo de Geometría Dinámica**
- **Ubicación:** Sistema de posicionamiento y BorderFrame
- **Sospecha:** Las coordenadas no se recalculan adecuadamente durante transiciones
- **Evidencia:** Reacomodos múltiples indican problemas en el cálculo de posición

#### 4. **Estado Persistente vs. Estado Transitorio**
- **Ubicación:** Variables globales y estado del sistema
- **Sospecha:** El sistema no distingue correctamente entre estado estable y estado en transición
- **Evidencia:** Comportamiento errático sugiere corrupción de estado durante cambios

---

## 🛠️ Requisitos para la Solución

### Requisitos Funcionales

#### RF1: Detección Confiable de Monitores
- **Objetivo:** Garantizar que el companion siempre nazca en la tableta designada
- **Criterios:** 
  - Detección proactiva de cambios en configuración de monitores
  - Fallback automático a tableta primaria si no se detecta secundaria
  - Sistema de verificación post-inicialización

#### RF2: Transición Fluida entre Monitores
- **Objetivo:** Eliminar bloqueos y comportamientos erráticos durante reubicación
- **Criterios:**
  - Proceso atómico de transición (todo o nada)
  - Indicadores visuales claros del estado de transición
  - Manejo adecuado de timeouts y reintentos controlados

#### RF3: Sincronización de Estado
- **Objetivo:** Mantener consistencia en todas las interfaces durante transiciones
- **Criterios:**
  - Coordinación entre timers de hover y posicionamiento
  - Bloqueo temporal de interacciones durante transición
  - Recalculación atómica de todas las coordenadas

### Requisitos No Funcionales

#### RNF1: Performance
- **Máximo tiempo de transición:** 2 segundos
- **Uso CPU:** < 5% durante transiciones
- **Memoria:** Sin fugas durante operaciones repetidas

#### RNF2: Robustez
- **Tolerancia a fallos:** Sistema debe recuperarse de interrupciones inesperadas
- **Consistencia:** Mismo resultado bajo mismas condiciones
- **Logging:** Registro detallado para diagnóstico post-mortem

---

## 🎯 Enfoque de Trabajo (JIT - Just-In-Time)

### Metodología Propuesta

#### Fase 1: Diagnóstico Detallado (JIT-1)
**Objetivo:** Identificar la causa raíz exacta del problema

**Actividades:**
1. **Análisis de logs existentes**
   - Revisar patrones en los archivos de respaldo (`_backups/`)
   - Identificar condiciones que desencadenan el fallo

2. **Monitoreo en tiempo real**
   - Instrumentar el sistema con logging detallado
   - Capturar eventos durante transiciones fallidas
   - Registrar estados de variables críticas

3. **Reproducción controlada**
   - Crear escenarios de prueba que reproduzcan consistentemente el problema
   - Documentar secuencia exacta de eventos

**Entregable:** Informe de diagnóstico con evidencia concreta

#### Fase 2: Implementación Atómica (JIT-2)
**Objetivo:** Implementar solución quirúrgica sin afectar funcionalidad existente

**Actividades:**
1. **Desarrollo incremental**
   - Modificar solo componentes identificados como problemáticos
   - Mantener compatibilidad con API existente

2. **Pruebas continuas**
   - Verificar cada cambio en entorno controlado
   - Usar `XPPEN_NO_ADMIN.ahk` para pruebas sin privilegios

3. **Validación final**
   - Pruebas en escenario real (tableta + monitor)
   - Verificación de criterios de aceptación

**Entregable:** Código parcheado con documentación de cambios

---

## 📦 Entregas Esperadas

### Documentación

#### 1. Informe Técnico de Diagnóstico
- **Contenido:**
  - Análisis detallado del problema
  - Evidencia de causa raíz
  - Recomendaciones de arquitectura
  - Plan de mitigación

#### 2. Especificación de Solución
- **Contenido:**
  - Diseño detallado de la solución propuesta
  - Diagramas de flujo corregidos
  - Especificaciones de interfaces
  - Plan de pruebas

### Código

#### 1. Parches Quirúrgicos
- **Alcance:** Solo componentes afectados
- **Formato:** Diffs exactos con contexto
- **Validación:** Pruebas unitarias y de integración

#### 2. Sistema de Monitoreo
- **Componente:** Logging mejorado para transiciones
- **Propósito:** Diagnóstico futuro y prevención
- **Integración:** Sin impacto en performance

#### 3. Pruebas Automatizadas
- **Escenarios:** Reproducción del problema y validación de solución
- **Herramientas:** Scripts de prueba para regresión
- **Integración:** En flujo de trabajo existente

---

## 📊 Criterios de Prueba

### Pruebas Funcionales

#### 1. Prueba de Nacimiento Correcto
- **Pasos:**
  1. Iniciar sistema con tableta conectada
  2. Verificar ubicación inicial del companion
  3. Repetir 10 veces en diferentes condiciones
- **Criterio:** 100% de nacimiento en tableta

#### 2. Prueba de Transición Fluida
- **Pasos:**
  1. Forzar nacimiento en monitor principal
  2. Activar transición a tableta
  3. Monitorear comportamiento durante 30 segundos
- **Criterio:** Sin bloqueos, < 2 segundos de transición, sin corrupción visual

#### 3. Prueba de Consistencia
- **Pasos:**
  1. Realizar 20 transiciones consecutivas
  2. Verificar estado final después de cada una
  3. Monitorear recursos del sistema
- **Criterio:** 100% de éxito, sin degradación de performance

### Pruebas de Regresión

#### 1. Funcionalidad Existente
- **Verificación:** Todas las funciones actuales siguen operando
- **Alcance:** Hover, estabilización, HUD, paneles flotantes

#### 2. Compatibilidad
- **Entornos:** Diferentes configuraciones de monitores
- **Periféricos:** Varias marcas de tabletas y monitores

---

## ⏱️ Cronograma Estimado

| Fase | Actividad | Duración | Entregable |
|------|-----------|----------|------------|
| JIT-1 | Diagnóstico detallado | 2-3 días | Informe técnico |
| JIT-2 | Implementación quirúrgica | 3-5 días | Código parcheado |
| Validación | Pruebas completas | 2-3 días | Reporte final |
| **Total** | **Entrega completa** | **7-11 días** | **Sistema operativo** |

---

## 📞 Contacto y Seguimiento

**Responsable del proyecto:** Equipo de Desarrollo AHK  
**Canal de comunicación:** Sesiones de revisión diarias  
**Punto de contacto:** Para consultas técnicas durante desarrollo  

---

## 🎯 Próximos Pasos

1. **Aprobación de solicitud** por parte de arquitecto
2. **Asignación de recursos** para desarrollo JIT
3. **Inicio de Fase 1 (Diagnóstico)**
4. **Comunicación diaria** de progreso

---

**Adjuntos:**
- Código fuente actual del companion
- Logs de errores recientes
- Configuración de sistema actual

*Este documento constituye la solicitud formal para análisis y solución del problema del sistema companion multi-monitor.*