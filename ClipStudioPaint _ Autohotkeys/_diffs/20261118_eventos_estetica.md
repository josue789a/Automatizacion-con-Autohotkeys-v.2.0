# Entrega — Optimización estética «Eventos y particularidades» (calibrador Python)

**Fecha:** 2026-11-18
**Estado:** PROPUESTA — no aplicada al árbol de trabajo (solo diff).
**Diff:** `_diffs/20261118_eventos_estetica.diff`
**Archivos que toca:** `calibrador_py/xppen_calibrador/ui/blocks.py`, `calibrador_py/xppen_calibrador/ui/widgets.py`

---

## 0. Lectura de la captura

- El marcador rojo **1** señala la fila `Duración`.
- La **X roja** tacha la pista gris `Auto (1000 ms) o 100-10000 ms`.
- Las **flechas rojas 2** señalan los huecos entre `Nombrar:`, `Tamaño:` e `Icono:` en el bloque 01.
- Las **líneas rojas 3** señalan los dos huecos entre las tres opciones del bloque 02.

---

## 1. Duración: valor de fábrica en gris vs. valor propio en negro

### Antes
- El INI guarda `auto` y el campo lo mostraba como **texto real negro** (`f_entry` hacía `insert(0, "auto")`).
- La pista `Auto (1000 ms) o 100-10000 ms` ocupaba el final de la fila.

### Ahora
- Nuevo helper reutilizable en `Block`: **`f_entry_default(parent, name, width, defecto, vacio)`**.
  - Si el INI vale `vacio` (por defecto `"auto"`): el campo se ve **vacío** y muestra `1000` en **gris** (`placeholder_text_color = T.TXT3`).
  - Si hay valor propio: el número se inserta como texto real en **negro** (`T.TXT`).
  - Confirmar en blanco vuelve a guardar `auto` (hereda del motor).
  - Mantiene el borde rojo si el valor no pasa la validación de `ini_schema`.
- `A02Hud` pasa a usar `self.f_entry_default(f2, "hud_dur", 56, "1000")`.
- **Se elimina** la pista `Auto (1000 ms) o 100-10000 ms` (la X de la captura).
- El helper queda listo para replicarse a cualquier otro bloque (`f_entry_default` dentro de `Block`).

> **Decisión pendiente (importante):** hoy el motor AHK no usa 1000 ms como valor real de herencia:
> `_HudDuracionDefecto()` devuelve **1500 ms**, y por zona son **300/500/400 ms**.
> El gris `1000` es, por tanto, una **etiqueta de fábrica de la UI**, no la duración efectiva.
> Si prefieres honestidad total, se puede cambiar `defecto` por un valor dinámico (la efectiva real)
> pasándole una lambda; el helper ya está preparado para recibir cualquier texto.

---

## 2. `EvenRow`: huecos equidistantes y elásticos

### Antes
Cada bloque usaba `pack(side="left")` con `padx` fijos y distintos (`14/14/14`, `16/16/6`).
Con ventana ancha el contenido quedaba amontonado a la izquierda y sobraba un hueco muerto a la derecha.

### Ahora
Nuevo widget en `widgets.py`: **`EvenRow`**.

```python
fr = EvenRow(parent, min_gap=10)
fr.grid(row=0, column=0, sticky="ew")
fr.add(celda1); fr.add(celda2); fr.add(celda3)
```

- Reparte **todo** el ancho sobrante **por igual** entre los huecos (columnas espaciadoras con `weight=1`).
- Cuando falta espacio, los huecos se **comprimen hasta `min_gap`**.
- No salta de fila: prioriza comprimir (a diferencia de `FlowRow`).
- Efecto visual: `space-between` → primera celda a la izquierda, última al borde derecho,
  huecos idénticos en medio. Por eso `Nombrar` y `Tamaño` se desplazan a la izquierda
  y `Icono` se arrastra al extremo derecho, tal como pediste.

### 2.1 Presencia y Superficie (`B01Presencia`)
4 celdas: `[Píldora] [Nombrar + entry] [Tamaño + combo] [Icono + 📁 + nombre]`, con `min_gap=10`.

### 2.2 Disparador Espacial (`B02Disparador`)
3 celdas: `[✎ Dibujar zona] [Paso → Autoclick] [Paso → Atajo CSP + entry + ✓/✕]`, con `min_gap=12`.
El check y su campo de atajo viajan juntos en la misma celda (no se separan al estirar).

---

## 3. Criterios de prueba (runtime)

1. **Duración**
   - Abrir un evento sin `duracion_<id>` en el INI → el campo debe verse **vacío con `1000` gris**.
   - Hacer clic en el campo → el `1000` gris desaparece (placeholder estándar).
   - Escribir `350` y salir → texto **negro**, sin borde rojo; guardar y reabrir el evento → sigue negro.
   - Vaciar el campo y salir → vuelve el `1000` gris y el INI queda en `auto`.
   - Escribir `99` (fuera de 100–10000) → borde rojo y no guarda.
   - Confirmar que **ya no aparece** la pista `Auto (1000 ms) o 100-10000 ms`.
2. **Bloque 01**
   - Con la ventana al ancho por defecto: los 4 grupos deben quedar separados por huecos **iguales**.
   - Ensanchar la ventana: los 3 huecos crecen por igual, `Icono` se pega al borde derecho.
   - Estrechar hasta el mínimo (940 px): los huecos bajan hasta ~10 px sin solaparse.
3. **Bloque 02**
   - Mismo comportamiento con 3 grupos y `min_gap=12`.
   - `Paso → Atajo CSP` y su campo deben moverse **juntos**.
4. **Regresión**
   - Los checks maestros, el desplegable de tamaño y la importación de icono siguen funcionando.
   - `refresh()` al cambiar de evento sigue recargando los valores.

---

## 4. Validación ejecutada (sobre copia temporal, sin tocar el repo)

- `python -m py_compile` sobre `blocks.py` y `widgets.py` → **OK**.
- `git apply --check` del diff → **OK** (aplica limpio).

## 5. Cómo aplicar (cuando lo apruebes)

```powershell
git apply "ClipStudioPaint _ Autohotkeys/_diffs/20261118_eventos_estetica.diff"
```

Para revertir:

```powershell
git apply -R "ClipStudioPaint _ Autohotkeys/_diffs/20261118_eventos_estetica.diff"
```

---

## 6. Notas de las que dependen tus respuestas

1. **La X**: interpreté que tachaba la pista de duración y la eliminé. Si te referías al botón **✕**
   de los campos de atajo (que hoy **restaura el valor por defecto** en vez de dejar vacío),
   dímelo y preparo un segundo diff sobre `A01Base._reset`.
2. **1000 vs 1500**: 1000 es el gris de fábrica que pediste; el motor hereda 1500/300/500/400.
   Si quieres que el gris muestre la duración efectiva real, lo cambio en una línea.
3. **Placeholder al enfocar**: al hacer foco el `1000` gris se oculta (comportamiento nativo).
   Si lo quieres siempre visible mientras editas, habría que insertarlo como texto gris y limpiarlo
   al primer carácter; es una variante algo más invasiva.
