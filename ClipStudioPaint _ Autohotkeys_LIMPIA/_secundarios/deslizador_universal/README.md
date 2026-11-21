# [SECUNDARIOS / TERCIARIOS] Deslizador y Estabilizador Universal

**Fecha de archivo:** 2026-11-18  
**Clasificación:** Ideas secundarias / terciarias (no prioritarias).  
**Script de respaldo:** `lib/estab_universal_experimental.ahk`

---

## 1. Concepto Original
Permitir que el valor del deslizador de estabilización sea único y global para todas las herramientas de dibujo en Clip Studio Paint (`Q` pluma, `W` aerógrafo, `E` borrador, etc.), transfiriendo instantáneamente el valor numérico al cambiar entre herramientas.

---

## 2. Diagnóstico Técnico y Motivo de Pase a Secundario
1. **Falta de API de lectura en Clip Studio Paint**: CSP no expone externamente el valor de la propiedad "Estabilización" de la sub-herramienta activa.
2. **Desincronización de estados**: Como cada pincel guarda internamente su propio valor en el motor de CSP, al forzar la transferencia sin un punto de anclaje físico exacto se producen desfasajes entre el valor mostrado por AHK y el trazo real en CSP.
3. **Complejidad vs. Valor de Uso**: El usuario determinó que el auto-transfer forzado entre herramientas no es prioritario frente a la estabilidad del flujo de trabajo habitual y el uso del deslizador individual optimizado.

---

## 3. Componentes Guardados para Desarrollo Futuro
* `Stab_ResetUniversal_Experimental`
* `_Stab_ResetFisico_Experimental` (batching raw con `_EstabEnviarRaw` y cálculo de deltas)
* Esquema de persistencia `modoUniversal` en `[Estab_p{p}]`
