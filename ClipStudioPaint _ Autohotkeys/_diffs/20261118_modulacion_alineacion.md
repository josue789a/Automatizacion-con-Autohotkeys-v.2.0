# Entrega — Ajuste estético 2: «Modulación de Tecla» (calibrador Python)

**Fecha:** 2026-11-18
**Estado:** APLICADO en el árbol de trabajo y verificado en runtime (no commiteado todavía).
**Diff:** `_diffs/20261118_modulacion_alineacion.diff`
**Archivos:** `calibrador_py/xppen_calibrador/ui/blocks.py`, `.../ui/widgets.py`, `.../core/draft.py`

---

## 1. Umbral: alineado con la caja B y «ms» dentro de la caja

### Antes
```
[✓] Pulsación rápida   Umbral: [250 ▴▾] ms        ← «ms» se salía de la línea
A: [........] ✓✕   B: [........] ✓✕              ← borde derecho de referencia
```
El renglón del umbral se empaquetaba con `pack(side="left")` y `padx` fijos, así que
el borde derecho de la caja no tenía relación con la caja B de abajo; el «ms» quedaba
fuera de la línea de alineación.

### Ahora
```
[✓] Pulsación rápida   Umbral: [250 ms ▴▾]
A: [........] ✓✕   B: [........] ✓✕
                                ▲ mismo borde derecho (Δ = 0 px medido)
```
- `Stepper` acepta `suffix=`: el sufijo se dibuja **dentro** del marco, antes de las
  flechas. El borde derecho de la caja es el final del grupo.
- El bloque 03 mide en runtime el borde derecho de la caja B (`c_qb.x + entry.width`)
  y ajusta un hueco elástico (mínimo 4 px) para que el grupo «Umbral: + caja»
  termine exactamente en esa vertical. Se recalcula en cada `<Configure>` (cambios de
  ancho/autoescala DPI), así que sigue alineado en cualquier tamaño de ventana.

## 2. «250» con lógica de número por defecto

### Antes
El umbral se mostraba siempre en negro, como si estuviera asignado a mano.

### Ahora
Misma lógica que «Duración», reutilizable (`Block.f_stepper_default()`):
- **Sin valor propio** en el INI → número **gris** con el valor de fábrica **real del
  evento**: 250 (shift sostenido, regla), 300 (mayoría), 400 (lazo / área de color).
  No es un 250 fijo: sale de `particularidades_defaults`.
- **Con valor propio** → negro.
- Vaciar el campo y confirmar → vuelve al gris y **no deja cambio sucio** (el borrador
  descarta el valor si coincide con el de fábrica).
- Los ▴/▾ parten del valor de fábrica aunque el campo esté en gris, y al primer
  movimiento el número pasa a negro.

## 3. Corrección colateral encontrada en la verificación visual

La caja **Duración** (bloque 02) se veía **vacía**: el placeholder gris `1000` se
insertaba al crear el `CTkEntry` y el `load()` lo borraba con `delete(0, "end")`
sin reactivarlo. Ahora `f_entry_default.load()` reactiva el placeholder cuando no hay
valor propio. Verificado en pantalla: `Duración [1000] ms` con el número en gris.

---

## Criterios de prueba (runtime, ya ejecutados)

| # | Acción | Resultado esperado | Verificado |
|---|---|---|---|
| 1 | Seleccionar «Deslizador de Estabilización», desplegar 03 | Borde derecho de la caja Umbral == borde derecho de la caja B | ✅ Δ = 0 px |
| 2 | Leer el umbral sin tocar nada | Gris (`#9D97B0`) con 250 (shift) / 300 (pluma) / 400 (lazo) | ✅ |
| 3 | Escribir `420` + Enter | Negro (`#201B38`), 1 cambio sucio | ✅ |
| 4 | Vaciar + Enter | Vuelve a gris 250, 0 cambios sucios | ✅ |
| 5 | Pulsar ▾ con el campo en gris | 250 → 200, en negro | ✅ |
| 6 | Bloque 02 | `Duración [1000] ms` en gris (ya no vacío) | ✅ |
| 7 | Estrechar/ensanchar la ventana | La alineación se mantiene (se recalcula) | ✅ |
| 8 | `pytest -q` | 45 OK, 3 fallos preexistentes (`_Cell.cget`, temas, cadena de zonas) | ✅ |

> Los 3 fallos de pytest son los mismos de antes del cambio (reproducidos con el
> código de HEAD); no hay regresiones nuevas.
