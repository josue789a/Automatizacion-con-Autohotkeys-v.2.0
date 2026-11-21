# DOSSIER PARA ARQUITECTO — Bugs del Calibrador Companion (versión LIMPIA)

**Fecha:** 2026-11-21
**Rama de trabajo:** `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys_LIMPIA`
**Destinatario:** agente arquitecto SIN acceso a la máquina.
**Emisor:** agente ejecutor (sí tiene acceso, aplicará tus diffs y validará).

> Este documento es autosuficiente: contiene el código vivo exacto, su ubicación
> (`archivo:línea`), los datos reales del INI y la evidencia de runtime.
> No necesitas ver los archivos completos para parchear.

---

## 0. CONTRATO DE ENTREGA (leer antes de responder)

1. **Zero-rewrite.** Entrega solo diffs anclados: `archivo:línea` + bloque anterior
   literal (5–10 líneas de contexto) + bloque nuevo. Nunca "reescribe el archivo".
2. **AutoHotkey v2** (`#Requires AutoHotkey v2.0`). Todo parche AHK debe pasar:
   `AutoHotkey64.exe /validate <archivo>.ahk` → ExitCode 0.
3. **Python 3.14.6 + customtkinter 6.0.0**, Tk mainloop single-thread.
   Nada de `sleep` en el hilo de UI.
4. Si un síntoma requiere una **decisión de diseño** (p. ej. cambiar el modelo de
   captura), dilo explícitamente y da la opción A/B con su coste. No asumas.
5. Si falta un dato para anclar el diff, **pídelo** indicando el archivo y el símbolo.
6. Ordena los parches por riesgo: primero los que no tocan el INI ni el hook global.
7. Al final, incluye una **tabla de verificación manual** por parche.

---

## 1. ENTORNO Y ARQUITECTURA

### 1.1 Procesos

| Pieza | Ruta | Rol |
|---|---|---|
| AHK principal (admin) | `XPPEN AHK VERSION ESTABLE.ahk` | Ganchos, HUD, captura, remapeos |
| AHK pruebas (sin admin) | `XPPEN_NO_ADMIN.ahk` | Réplica para test local |
| Calibrador Python | `calibrador_py/xppen_calibrador/` | UI de configuración (Tk) |
| Datos | `posiciones_gui.ini` | **Fuente de verdad** (UTF-16 LE, CRLF) |
| Catálogo | `calibrador_py/data/catalogo.json` | Solo lectura para Python (lo exporta AHK) |
| Catálogo vacío | `calibrador_py/data/catalogo_vacio.json` = `{"eventos": []}` | Suite de pruebas |
| Log puente | `%TEMP%\_calibrador_py_ahk.log` | Traza `← CMD` / `CAP_RESULT` |
| Log captura | `logs/captura.log` | Resultado de cada captura |
| Log remapeos | `logs/remap_diag.log` | Cada disparo de hotkey dinámico |

### 1.2 Comunicación Python → AHK

`WM_COPYDATA` (`0x4A`, marker `0x58504E01`), texto UTF-16 `CMD|arg|arg`.
**Bloqueante con timeout de 1500 ms** (`SendMessageTimeoutW`, `SMTO_ABORTIFHUNG`).

`calibrador_py/xppen_calibrador/core/ahk_bridge.py:69-88`
```python
    def send(self, cmd: str, *args) -> bool:
        text = "|".join([cmd, *[str(a) for a in args]])
        self.sent.append(text)
        if not self.conectado:
            log.info("(sin AHK) %s", text)
            return False
        ...
        ok = ctypes.windll.user32.SendMessageTimeoutW(
            wintypes.HWND(self.ahk_hwnd), WM_COPYDATA, wintypes.WPARAM(self._own()),
            ctypes.byref(cds), SMTO_ABORTIFHUNG, 1500, ctypes.byref(res))
```

El receptor AHK despacha con `SetTimer(-1)` para devolver 1 rápido
(`lib/calibrador_py.ahk:8-10`), **pero si el hilo principal de AHK está ocupado
(reload de INI, `taskkill`, WMI), Python se come hasta 1.5 s por comando.**

### 1.3 Contexto global que gobierna TODOS los hotkeys de CSP

`lib/captura_overlay.ahk:105-111`
```ahk
Cap_Armado(*) {
    e := _CapEstado()
    return (e.fase = "ARMING" || e.fase = "ARMED" || A_TickCount < e.swallowHasta)
}

; Contexto para TODOS los #HotIf de CSP: activo en CSP y sin captura en curso
CspLibre(*) => WinActive("ahk_exe CLIPStudioPaint.exe") && !Cap_Armado()
```

Consecuencia: **mientras haya una captura en curso (o 150 ms después), TODOS los
hotkeys de CSP —incluido `RButton`— están desactivados.**

### 1.4 Modo actual

`posiciones_gui.ini`
```ini
[Modo]
legado =0
[Captura]
timeout_ms = 5000
settle_ms = 30
permitir_esc = 0
cancelar_fuera = 1
log = 1
```
`legado=0` ⇒ todo lo marcado `_LegadoActivo()` está apagado; solo vive el
despachador dinámico.

### 1.5 Catálogo real de la suite de pruebas

`calibrador_py/data/catalogo.json` y `catalogo_vacio.json` están **vacíos**
(`{"eventos": []}`). Por tanto **todos** los eventos son `custom_N` y su nombre
sale exclusivamente de `[EventosCustom]`:

```ini
[EventosEliminados]
lista=custom_8
custom_8=1

[EventosCustom]
lista = custom_1,custom_2,custom_3,custom_4,custom_5,custom_6,custom_7,custom_9
custom_9=Nuevo evento 9|Personalizados

[Remapeos]
atajo_custom_9=E
atajo_custom_3=F5
remap_custom_3=RButton
atajo_custom_4=F6
remap_custom_4=RButton+Q
atajo_custom_7=L
remap_custom_7=E

[Particularidades]
toggle_custom_9=1
toggle_b_custom_9=L
```

---

## 2. SÍNTOMAS REPORTADOS (verbatim del usuario)

> S1. "Parece el toggle, la pulsación rápida y los atajos con Alt están funcionando
> bien, pero el **RButton** no consigue funcionar aún."

> S2. "La suite de pruebas vacía está horriblemente lenta: crear un evento tarda
> como 2 s; presiono una tecla en **A) 1. Base** y la tecla aparece como 2 s
> después; es peor si me equivoco y quiero cambiar: **no cambia**."

> S3. "Necesito poder **editar el nombre de los eventos**. Quedan como
> `Nuevo evento N` y el texto del evento no los actualiza. Lo ideal sería que los
> actualice el **Texto del evento** de `2) Feedback visual`."

> S4. "A veces no me deja presionar sobre **B de pulsación rápida**: presiono el
> panel de asignación y se pone en verde, pero no se materializa… y sí se
> materializa, pero **demora como 8 s**. Los check quedan congelados: no sale el
> check, solo el box verde; el check sale luego de unos 8 s."

> S5. "Como no deja modificar las letras, tengo que **eliminar** el evento si me
> equivoco."

**Nota del ejecutor:** S4 es la misma causa que S2 (captura diferida por AHK);
S5 es la consecuencia de S2/S3. Trátalos como un solo frente, no como cuatro.

---

## 3. EVIDENCIA DE RUNTIME

### 3.1 La captura hace ping-pong de foco (S2/S4)

`%TEMP%\_calibrador_py_ahk.log` (recortado, timestamps reales):
```
02:48:23  CAP_RESULT -> 74 | ok | L
02:48:25  ← CAP_CANCEL | focus_out
02:48:26  ← CAP_ARM
02:48:30  ← CAP_CANCEL | focus_out
02:48:30  ← RELOAD_INI
02:48:30  CAP_RESULT -> 75 | focus_out
02:48:34  ← CAP_ARM
02:48:34  CAP_RESULT -> 75 | cancel_fuera
02:48:36  CAP_RESULT -> 76 | ok | L
02:48:39  ← CAP_ARM
02:48:44  ← CAP_CANCEL | focus_out
02:48:44  CAP_RESULT -> 77 | focus_out
02:48:48  CAP_RESULT -> 77 | cancel_fuera
```

`logs/captura.log`:
```
seq=61 estado=ok combo=L dt=2.37ms
seq=62 estado=focus_out combo= dt=0ms
seq=63 estado=cancel_fuera combo= dt=0ms
seq=69 estado=ok combo=L dt=1.89ms
seq=75 estado=focus_out combo= dt=0ms
seq=75 estado=cancel_fuera combo= dt=0ms
seq=79 estado=focus_out combo= dt=0ms
seq=79 estado=cancel_fuera combo= dt=0ms
```

Lectura: cuando la captura **sí** acierta, el hook tarda **1.5–2.7 ms**. El
retardo de 2 s no es del hook: es del **viaje de foco** Tk → CSP → Tk y de los
reintentos. `focus_out`/`cancel_fuera` significa que el Entry perdió el foco
justo al armarse.

### 3.2 Auto-repeat del toggle (hallazgo colateral, S1/S5)

`logs/remap_diag.log`:
```
20261121024925 DISPARO custom_9 tecla=e held=0 pausado=0   (×5 en el mismo segundo)
20261121024926 DISPARO custom_9 tecla=e held=0 pausado=0   (×5)
20261121024927 DISPARO custom_9 tecla=e held=0 pausado=0   (×2)
...
20261121024959 DISPARO custom_9 tecla=e held=0 pausado=0
```

`custom_9` tiene `toggle_custom_9=1` y `atajo_custom_9=E` ⇒ hotkey `$e` con
alternancia A⇄B. **Cada repetición de tecla alterna el estado** (5 disparos por
segundo en el log = tecla sostenida). El `KeyWait(tecla, "T10")` de
`_RemapDisparar` no lo evita (10 ms < intervalo de auto-repeat).

### 3.3 El RButton nunca dispara su remapeo

`remap_custom_4=RButton+Q` está registrado (se ve `REG` en el log en arranques
anteriores), pero en las pruebas del usuario **no hay ni una línea
`DISPARO custom_4`**. Es decir: el contexto `RButton sostenido` nunca se cumple,
o el `RButton up` no llega.

---

## 4. CÓDIGO VIVO POR SÍNTOMA

### 4.1 S1 — RButton

#### 4.1.1 Handler actual

`lib/hotkeys_csp.ahk:776-797`
```ahk
; === INFRA STYLUS: RButton universal (independiente del legado) ===
#HotIf CspLibre()
RButton:: {
    stylus.rButtonHeld := true
    stylus.comboUsado := false
    stylus.upSinteticoTick := 0
}
RButton up:: {
    elapsed := (stylus.upSinteticoTick > 0) ? (A_TickCount - stylus.upSinteticoTick) : 9999
    if (elapsed < UP_SINTETICO_MS) {
        stylus.rButtonHeld := true
        stylus.upSinteticoTick := 0
        return
    }
    stylus.rButtonHeld := false
    if (!stylus.comboUsado)
        SendInput("{RButton}")   ; cuentagotas al soltar en CSP
}
Space & RButton:: {
    stylus.comboUsado := true
    _InvSeleccionConGUI()
}
#HotIf CspLibre()
Numpad0:: {
```

Estado del stylus: `XPPEN_NO_ADMIN.ahk:39` / `XPPEN AHK VERSION ESTABLE.ahk:38`
```ahk
stylus := {altActive:false,rButtonHeld:false,comboUsado:false,upSinteticoTick:0,
           botonSostenido:false,smearSend:false,ignorarUpSintetico:false,
           bSinteticoTick:0,origX:0,origY:0,spaceFlipTimerRunning:0,origenCompanion:false}
UP_SINTETICO_MS := 70
```

#### 4.1.2 Remapeo `RButton+Q` (custom_4)

`lib/hotkeys_csp.ahk:294-318` (normalizador)
```ahk
_RemapNormalizar(txt) {
    ...
    partes := StrSplit(txt, "+", " `t")
    principal := _RemapNombreTecla(partes.Pop())
    ...
    return {hk: "$" mods principal, mods: mods, principal: principal, held: held}
}
```
⇒ `"RButton+Q"` produce `hk="$q"`, `held=["RButton"]`. **No usa combinación
custom de AHK**, usa `$q` + `HotIf` que consulta `stylus.rButtonHeld`.

`lib/hotkeys_csp.ahk:355-374`
```ahk
; Alt físico O Alt del botón 1 del stylus (Alt+B); RButton físico O el del botón 2
_TeclaSostenida(k) {
    if GetKeyState(k)
        return true
    kl := StrLower(k)
    if (kl = "alt" || kl = "lalt" || kl = "ralt" || kl = "!")
        return !!stylus.altActive
    if (kl = "rbutton")
        return !!stylus.rButtonHeld
    return false
}

_RemapCtxOk(held) {
    if !CspLibre()
        return false
    for k in held
        if !_TeclaSostenida(k)
            return false
    return true
}
```

`lib/hotkeys_csp.ahk:377-406` (extracto)
```ahk
_RemapDisparar(idEv, tecla, held, *) {
    ...
    if (stylus.rButtonHeld || GetKeyState("RButton"))
        stylus.comboUsado := true
    ...
    for k in held
        SendInput("{" k " up}")
    _FlushPendentes()
    if _ModActivo("toggle", idEv) {
        r := _ModToggle(idEv)
        KeyWait(tecla, "T10")   ; el auto-repeat no debe alternar A/B
        return r
    }
    atajo := IniRead(_PosGuiIniPath(), "Remapeos", "atajo_" idEv, "")
    if _ModActivo("quick", idEv)
        return _ModQuick(idEv, tecla, atajo)
    r := _ModEnviar(atajo)
    try _AvisoEvento(idEv)
    return r
}
```

#### 4.1.3 Hipótesis priorizadas (S1)

- **H-R1 (alta): el `up` se pierde al cambiar el contexto.**
  AHK evalúa `#HotIf` también en el *key-up*. Si al soltar el botón
  `CspLibre()` es falso (p. ej. `Cap_Armado()` pasó a true, o el foco saltó a
  la píldora/Companion/calibrador), el handler `RButton up` **no se ejecuta**:
  no se envía `{RButton}` (no hay cuentagotas) y `stylus.rButtonHeld` queda
  **true para siempre** (envenena todos los combos posteriores).
  El código actual no tiene red de seguridad para esto.
- **H-R2 (alta): CSP necesita el *press*, no un clic sintético al soltar.**
  `RButton::` suprime la pulsación física; CSP nunca ve el `down`. En tableta,
  CSP suele procesar el cuentagotas por `WM_POINTER`/evento de pulsación
  mantenida. Un `SendInput("{RButton}")` de 1 ms al soltar puede no activar
  nada. Hay que decidir: (a) reenviar `{RButton down}` al presionar y
  `{RButton up}` al soltar si no hubo combo, o (b) dejar pasar el físico con
  `~RButton` y cancelar el efecto por otra vía.
- **H-R3 (media): `Space & RButton::` en el mismo bloque.**
  Al declarar la combinación custom, RButton pasa a ser sufijo de combo en ese
  contexto; combinado con `RButton::`/`RButton up::` puede alterar el orden de
  eventos. Aislar la combinación en su propio `#HotIf` y verificar.
- **H-R4 (media): fuga inversa.** Si `CspLibre()` es falso al presionar pero
  true al soltar, corre `RButton up` sin `down` previo ⇒ `comboUsado` es false
  ⇒ se emite un `{RButton}` fantasma.

#### 4.1.4 Instrumentación mínima sugerida (la decides tú)

Añadir traza a ambos handlers (a `logs/remap_diag.log`):
`down/up + A_TickCount + WinActive(CSP) + Cap_Armado() + stylus.rButtonHeld + comboUsado`.
Con 3 pulsaciones del usuario se confirma o descarta H-R1 en un minuto.

---

### 4.2 S2/S4 — Captura lenta, no se puede corregir, check a los 8 s

#### 4.2.1 Capturador Python (íntegro, es el núcleo del problema)

`calibrador_py/xppen_calibrador/ui/widgets.py:701-1008`
```python
def attach_keycapture(host, on_clear=None, on_commit=None, get_history=None):
    """El Entry captura combinaciones (Ctrl+Alt+Shift+Win + tecla).
    Supr/Retroceso solos = on_clear(). Doble clic = escritura manual."""
    ent = _find_entry(host)
    if ent is None:
        return None
    inner = getattr(ent, "_entry", ent)
    st = {"manual": False, "down": set(), "pico": [], "cerrado": True,
          "job": None, "armed": False, "beat": None}
    ...
    def kdown(ev):
        sym = getattr(ev, "keysym", "")
        if sym in ("Tab", "ISO_Left_Tab"):
            return None
        if sym in ("BackSpace", "Delete"):
            if callable(on_clear):
                on_clear()
            ...
            return "break"
        if sym == "Escape":
            if st.get("armed"):
                st["armed"] = False
                accent(False)
            return "break"
        if st.get("manual"):
            return None
        tok = _tok_de(ev)
        if tok and not st.get("armed"):          # ← SOLO captura local si NO está armado
            put(tok)
            if callable(on_commit):
                on_commit()
            ...
            return "break"
        return "break"                            # ← si está armado, TRAGA la tecla
    ...
    def arm_capture():
        if st.get("armed"):
            return
        st["armed"] = True
        st["manual"] = False
        ...
        st["arm_deadline"] = _mono() + _ARM_MAX_S      # _ARM_MAX_S = 7.0
        st["handoff_until"] = _mono() + _HANDOFF_S     # _HANDOFF_S = 1.5
        _cap_send("CAP_ARM")
        _poll_ahk()

    def focus_in(_e=None):
        accent(True)
        if _is_empty() and not st.get("armed") and not st.get("manual"):
            arm_capture()                              # ← arma solo si el campo está VACÍO

    def focus_out(_e=None, force=False):
        if (not force and st.get("armed")
                and _mono() < st.get("handoff_until", 0.0)):
            return
        ...
        if st["armed"]:
            st["armed"] = False
            ...
            _cap_send("CAP_CANCEL|focus_out")
```
Claves del bloque:
- `_HANDOFF_S = 1.5`, `_ARM_MAX_S = 7.0` (líneas 938-939).
- `_poll_ahk()` lee `%TEMP%\_ahk_cap_result.txt` cada **60 ms** (línea 979).
- Con `armed=True` **toda tecla local se descarta** y hay que esperar a AHK.
- El campo vacío **siempre** se arma al recibir foco; el campo con valor no.

#### 4.2.2 AHK roba el foco a CSP (causa del ping-pong)

`lib/captura_overlay.ahk:275-313`
```ahk
Cap_Armar(seq := 0, target := "", etiqueta := "") {
    e := _CapEstado()
    if _CapPyActivo() { ... return false }
    ...
    e.fase := "ARMING"
    e.tInicio := A_TickCount
    _CapHotkeys("On")                 ; primero suprimir, luego (si hace falta) devolver foco
    if !_CapEsCSP()
        try _CspFoco()                ; ← WinActivate(CSP)
    _CapMostrar(e)
    if _CapEsCSP() {
        _CapPasarAArmed(e)
    } else {
        e.estado.SetFont("cFFD54F")
        e.estado.Text := "Volviendo a CSP…"
        e.bar.Value := 100
        e.tReact := A_TickCount
        SetTimer(_CapArmingPoll, 20)
    }
    return true
}
```

`lib/captura_overlay.ahk:315-340`
```ahk
_CapArmingPoll() {
    e := _CapEstado()
    if (e.fase != "ARMING") { SetTimer(_CapArmingPoll, 0) ; return }
    if _CapEsCSP() {
        if !e.tFocoOk
            e.tFocoOk := A_TickCount
        if (A_TickCount - e.tFocoOk >= e.cfg.settleMs) {
            SetTimer(_CapArmingPoll, 0)
            _CapPasarAArmed(e)
        }
        return
    }
    e.tFocoOk := 0
    if (A_TickCount - e.tInicio > 1200) {
        SetTimer(_CapArmingPoll, 0)
        Cap_Terminar("error_foco")
        return
    }
    if (A_TickCount - e.tReact > 200) {
        e.tReact := A_TickCount
        try _CspFoco()
    }
}
```

`lib/captura_overlay.ahk:365-405` (`_CapTick`) cancela si CSP pierde el foco:
```ahk
    if !_CapEsCSP() {
        ...
        if e.cfg.cancelar_fuera {
            Cap_Terminar("cancel_fuera")
            return
        }
        ...
    }
```

#### 4.2.3 Cadena completa del retardo

1. El usuario hace clic en el Entry vacío → `focus_in` → `arm_capture()`.
2. `CAP_ARM` (bloqueante ≤1.5 s) → AHK `Cap_Armar` → `_CspFoco()` activa CSP.
3. El Entry de Tk pierde el foco → `focus_out` → `CAP_CANCEL|focus_out` (≤1.5 s).
4. AHK está en `ARMING`/`ARMED`; recibe el cancel o cae por `cancel_fuera`.
5. La tecla que el usuario pulsó mientras tanto **no se registró** (o se registró
   en CSP, no en el campo).
6. El usuario reintenta → se repite el ciclo. De ahí los 2 s (un ciclo) y los
   ~8 s (varios ciclos + deadline de 7 s).

**El hook en sí tarda 1.5–2.7 ms** (ver §3.1). El coste es 100 % foco + IPC.

#### 4.2.4 Hipótesis (S2/S4)

- **H-C1 (alta): el diseño "capturar en CSP" es incompatible con capturar desde
  un Entry de Tk.** Robar el foco al abrir la captura garantiza `FocusOut` y
  cancelación. Hay dos salidas:
  - **(A) Captura local primero**: teclado se captura en Tk (instantáneo, sin
    IPC); AHK solo interviene para RButton/stylus (F24) y para el overlay.
  - **(B) Captura global sin robar foco**: AHK captura con `#HotIf` + hook sin
    `WinActivate`, y devuelve el resultado por archivo; el Entry conserva foco.
- **H-C2 (alta): `if tok and not st.get("armed")`** desactiva el camino rápido.
  Aunque el usuario escriba, se traga la tecla. Es la razón de "no cambia".
- **H-C3 (media): `focus_in` arma solo si está vacío** ⇒ comportamiento
  incoherente: el primer valor entra por AHK (lento) y la corrección por Tk
  (rápido)… o al revés según el estado. Unificar.
- **H-C4 (media): el check de "Pulsación rápida" (B) no se pinta hasta que
  termina la captura** porque `_check()` se llama desde `on_commit`
  (`_poll_ahk` → `put(combo)` → `on_commit` → `_on_key_commit` → `_check`).
  Los ~8 s = deadline `_ARM_MAX_S=7.0` + 60 ms de poll + margen.
- **H-C5 (baja): `reload_all()` en `_poll` cada 600 ms** reconstruye todas las
  pestañas al detectar cambio de mtime del INI (ver §4.4.3). Suma jitter.

---

### 4.3 S3 — Nombre del evento no editable

#### 4.3.1 De dónde sale el nombre

`calibrador_py/xppen_calibrador/core/catalogo.py:110-118`
```python
        lista = self.store.get("EventosCustom", "lista", "") or ""
        for cid in [c.strip() for c in lista.split(",") if c.strip()]:
            if cid in eliminados:
                continue
            nombre, _, grp_raw = (self.store.get("EventosCustom", cid, "") or cid).partition("|")
            grp_custom = ((self.store.get("EventosGrupo", cid) or "").strip()
                          or grp_raw.strip() or GRUPO_CUSTOM)
            atajo = (self.store.get("Remapeos", "atajo_" + cid, "") or "").strip()
            evs[cid] = Evento(cid, nombre or cid, grp_custom, atajo, custom=True)
```

`calibrador_py/xppen_calibrador/core/catalogo.py:200-211`
```python
    def siguiente_custom(self) -> tuple[str, str]:
        usados = {e.id for e in self.eventos}
        ...
        n = 1
        while f"custom_{n}" in usados:
            n += 1
        return f"custom_{n}", f"Nuevo evento {n}"
```

`calibrador_py/xppen_calibrador/app.py:370-392`
```python
    def _add_event(self):
        cid, nombre = self.catalogo.siguiente_custom()
        lista = [c for c in (self.store.get("EventosCustom", "lista", "") or "").split(",") if c.strip()]
        if cid not in lista:
            lista.append(cid)
        patches = [
            ("EventosCustom", "lista", ",".join(lista)),
            ("EventosCustom", cid, f"{nombre}|Personalizados"),
            ("EventosEliminados", cid, None),
        ]
        ...
        self.store.save_patches(patches)
        self.bridge.send("RELOAD_INI", "catalogo")
        self.catalogo.load()
        self.cat_panel.rebuild()
        self.cat_panel.select(cid)
```

**No existe ninguna ruta de renombrado.** El nombre solo se escribe al crear.

#### 4.3.2 El campo "Texto del evento" NO renombra (solo muestra)

`calibrador_py/xppen_calibrador/ui/blocks.py:883-898`
```python
        lbl(f2, "Texto del evento", 11, T.TXT2).pack(side="left", padx=(0, 6))
        t_entry = self.f_entry(f2, "hud_texto", 240, "Por defecto: nombre del evento")
        t_entry.pack(side="left", padx=(0, 18))
        ...
        def load_txt():
            cur_t = self.ctx.get("hud_texto")
            ev = self.ctx.catalogo.por_id(self.ctx.event_id)
            if not cur_t and ev:
                t_entry.delete(0, "end")
                t_entry.insert(0, ev.nombre)      # ← pinta el nombre, NO lo guarda
        self._loaders.append(load_txt)
```

`calibrador_py/xppen_calibrador/ui/blocks.py:341-359`
```python
    def f_entry(self, parent, name, width=140, placeholder=""):
        w = entry(parent, width, placeholder)

        def commit(_e=None):
            ok = self._commit(name, w.get())
            w.configure(border_color=T.FIELD_BORDER if ok else T.DANGER)
        w.bind("<FocusOut>", commit)
        w.bind("<Return>", commit)

        def load():
            val = str(self.ctx.get(name) or "")
            if getattr(w, "_last_val", None) == val:
                return
            w._last_val = val
            w.delete(0, "end")
            w.insert(0, val)
            w.configure(border_color=T.FIELD_BORDER)
        self._loaders.append(load)
        return w
```

Claves del contrato (`core/ini_schema.py:57-90`):
```python
    "atajo":       F("Remapeos", "atajo_{id}", "str", ""),
    "remap":       F("Remapeos", "remap_{id}", "str", ""),
    "hud_formato": F("@auto", "formato_{id}", "choice", "moderno", choices=(...), fallback="HudEventos{p}"),
    "hud_texto":   F("@auto", "texto_{id}", "str", "", fallback="HudTextos{p}"),
    "quick":       F("Particularidades", "quick_{id}", "bool", 0),
    "quick_b":     F("Particularidades", "quick_b_{id}", "str", ""),
    "quick_ms":    F("Particularidades", "quick_ms_{id}", "int", 250, 50, 2000),
    "toggle":      F("Particularidades", "toggle_{id}", "bool", 0),
    "toggle_b":    F("Particularidades", "toggle_b_{id}", "str", ""),
```

⇒ `hud_texto` es `texto_<id>` (sección `HudTextos{p}` o `@auto`). **No tiene nada
que ver con el nombre del evento**, que vive en `[EventosCustom] <id>=nombre|grupo`.

#### 4.3.3 Decisiones para el arquitecto (S3)

1. ¿Renombrar desde el campo "Texto del evento" (como pide el usuario) o añadir
   un campo "Nombre" en el bloque 01?
   - Si es desde "Texto del evento": al hacer commit, si el valor ≠ nombre actual
     ⇒ `save_patches([("EventosCustom", id, f"{nuevo}|{grupo}")])`, luego
     `catalogo.load()`, `cat_panel.rebuild()`, `editor.title`, `footer`, y
     `bridge.send("RELOAD_INI")`.
   - Riesgo: `hud_texto` vacío significa "usar el nombre"; hay que decidir si
     renombrar además borra `texto_<id>` para que el HUD siga al nombre.
2. ¿Se permite renombrar eventos de fábrica? Su nombre vive en
   `data/catalogo.json` (propiedad de AHK, que solo exporta si no existe).
   Haría falta una clave de override (`[EventosNombres] <id>=...`) que AHK y
   Python lean con prioridad. **Recomendación: empezar solo por `custom_*`.**
3. Unicidad / longitud / caracteres `|` (delimitador del INI). El nombre no
   puede contener `|` ni saltos.

---

### 4.4 S4 — Check "B" congelado y lentitud general

#### 4.4.1 Bloque B03 (Pulsación rápida)

`calibrador_py/xppen_calibrador/ui/blocks.py:1124-1177` (extracto)
```python
        ra2 = ctk.CTkFrame(a, fg_color="transparent")
        ra2.grid(row=1, column=0, sticky="w")
        lbl(ra2, "A:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        c_qa, e_qa = self.f_readonly_key_box(ra2, self._tecla_base, 90)
        c_qa.pack(side="left", padx=(0, 8))
        self._box_qa = e_qa
        lbl(ra2, "B:", 11, T.TXT2).pack(side="left", padx=(0, 4))
        c_qb, e_qb = self.f_key_entry(ra2, "quick_b", 90)
        c_qb.pack(side="left")
        ...
        chk = self.f_check(ra1, "quick", "Pulsación rápida")
        chk.pack(side="left")
        self._chk_widgets["quick"] = chk
```

`calibrador_py/xppen_calibrador/ui/blocks.py:1238-1270`
```python
    def _on_key_commit(self, name, value):
        """Cascada inversa: al definir B (con A ya presente), activa automáticamente la particularidad y el maestro."""
        chk_name = getattr(self, "_B_LINKS", {}).get(name)
        if chk_name:
            val_str = str(value or "").strip()
            if val_str:
                self._check(chk_name)
            else:
                self._uncheck(chk_name)

    def _check(self, chk_name):
        w = getattr(self, "_chk_widgets", {}).get(chk_name)
        if w is not None:
            if hasattr(w, "_var"):
                w._var.set(1)
            try:
                w.select()
            except Exception:
                pass
        self._commit(chk_name, 1)
        self._sync_master()

    def _uncheck(self, chk_name):
        ... análogo ...
```

`calibrador_py/xppen_calibrador/ui/blocks.py:260-275`
```python
    def f_check(self, parent, name, text):
        var = tk.IntVar(value=0)
        w = check(parent, text, var, lambda: self._commit(name, var.get()))
        w._var = var
        def _load_chk():
            v = int(bool(self.ctx.get(name)))
            if getattr(w, "_last_val", None) == v:
                return
            w._last_val = v
            var.set(v)
            try:
                (w.select if v else w.deselect)()
            except Exception:
                pass
        self._loaders.append(_load_chk)
        return w
```

`calibrador_py/xppen_calibrador/ui/blocks.py:180-192`
```python
    def _sync_master(self):
        nv = 1 if self.master_on() else 0
        if getattr(self, "_last_m_val", None) == nv and self.m_var.get() == nv:
            self.update_visual_state()
            return
        self._last_m_val = nv
        if self.m_var.get() != nv:
            self.m_var.set(nv)
        try:
            (self.m_chk.select if nv else self.m_chk.deselect)()
        except Exception:
            pass
        self.update_visual_state()
```

**Observación:** `_check()` no actualiza `w._last_val`. Si después corre un
`refresh()` (por `_poll`/`reload_all`), `_load_chk` ve `_last_val` viejo y vuelve
a pintar; no debería desmarcar (el Draft ya tiene 1), pero es frágil.

#### 4.4.2 Coste de crear un evento

`app._add_event` (§4.3.1) ejecuta, **en el hilo de UI**:
1. `store.save_patches()`: `load()` (lee INI completo) + `_backup()` (copia) +
   escritura tmp + `fsync` + `os.replace` + `load()` otra vez
   (`core/ini_store.py:196-229`). Hasta 6 reintentos con `sleep(0.04*n)`.
2. `bridge.send("RELOAD_INI", "catalogo")` → **≤1500 ms** si AHK está ocupado.
3. `catalogo.load()` (parsea el INI).
4. `cat_panel.rebuild()` + `select()` → `editor.show_event()` →
   `ctx.refresh_all()` + `_update_group_state()` + prewarm de bloques.

#### 4.4.3 Recarga completa por cambio de mtime

`calibrador_py/xppen_calibrador/app.py:446-457`
```python
    def _poll(self):
        try:
            for st in (self.store, self.theme_store):
                p = st.path
                if p.exists():
                    s_ = p.stat()
                    if st.signature and (s_.st_mtime_ns, s_.st_size) != st.signature:
                        self.reload_all()
                        break
        except OSError:
            pass
        self.after(600, self._poll)
```
`app.py:438-444`
```python
    def reload_all(self):
        self.store.load()
        self.theme_store.load()
        self.catalogo.load()
        self.ctx.refresh_all()
        self._refresh_tabs(external=True)
```
`_refresh_tabs` llama `on_external_change()`/`refresh()` de **todas** las
pestañas ya instanciadas (Zonas, Sistema, Temas). `app.py:302` documenta:
`_PREBUILD = (1, 2)  # TemasTab (~5 s) se construye solo bajo demanda`.

⇒ Cualquier escritura del INI (propia o de AHK) puede disparar una
reconstrucción de ~5–8 s.

#### 4.4.4 Hipótesis (S4 / lentitud)

- **H-P1 (alta):** el check de B espera al resultado de la captura AHK (H-C4).
- **H-P2 (alta):** `_poll`→`reload_all()` reconstruye pestañas tras cada
  escritura del INI; coincide con el "todo congelado ~8 s".
- **H-P3 (media):** `bridge.send` bloqueante (1.5 s) dentro de callbacks de UI.
- **H-P4 (media):** `save_patches` hace doble `load()` + copia de respaldo +
  `fsync` en cada creación (2 s).

---

### 4.5 S1/S5 — Toggle con auto-repeat

`lib/hotkeys_csp.ahk:264-285`
```ahk
; Cada pulsación alterna A ⇄ B.
_ModToggle(idEv, defA := "", defB := "") {
    lado := _ModLado()
    if (defA = "")
        defA := IniRead(_PosGuiIniPath(), "Remapeos", "atajo_" idEv, "")
    if (!_ModActivo("toggle", idEv))
        return _ModEnviar(defA)
    esB := lado.Get(idEv, false)
    if (esB) {
        atB := _ModAtajo("toggle", "b", idEv, defB)
        if (atB = "") {
            lado[idEv] := false
            MostrarHUD("⚠️ Alternador: Falta Tecla B", "FF3366", 1200)
            return _ModEnviar(_ModAtajo("toggle", "a", idEv, defA))
        }
        lado[idEv] := false
        return _ModEnviar(atB, "🔁 B: " atB "  ▸ A", "FFB300")
    }
    lado[idEv] := true
    atA := _ModAtajo("toggle", "a", idEv, defA)
    return _ModEnviar(atA, "🔁 A: " atA "  ▸ B", "00E5FF")
}
```

**Bug:** no hay guarda de "ya procesado hasta key-up". El auto-repeat del
teclado alterna A⇄B sin parar (en el log se ven 5 disparos por segundo, es
decir, repetición sostenida). `KeyWait(tecla, "T10")` en `_RemapDisparar:397`
no sirve: 10 ms es menor que cualquier intervalo de repetición.

---

## 5. RESUMEN DE HIPÓTESIS → PARCHE ESPERADO

| ID | Síntoma | Causa raíz propuesta | Tipo de parche |
|---|---|---|---|
| H-R1 | S1 | `RButton up` pierde el contexto `#HotIf` | AHK: quitar `#HotIf` del `up` o usar `~RButton` + estado propio |
| H-R2 | S1 | CSP necesita el press real | AHK: reenviar `down`/`up` reales, no clic sintético |
| H-R3 | S1 | `Space & RButton` contamina el bloque | AHK: aislar contexto |
| H-C1 | S2/S4 | Captura AHK roba foco a Tk | Py+AHK: captura local primero (decisión A/B) |
| H-C2 | S2 | `if tok and not armed` traga teclas | Py: permitir corrección local siempre |
| H-C3 | S2 | `focus_in` arma solo si vacío | Py: unificar criterio |
| H-C4 | S4 | Check espera captura (7 s) | Py: feedback inmediato + commit diferido |
| H-P1/2/3/4 | S2/S4 | Bloqueos en hilo UI | Py: no bloquear; `_poll` incremental |
| H-T1 | S1/S5 | Toggle sin guarda de auto-repeat | AHK: flag hasta key-up |
| H-N1 | S3 | No hay ruta de renombrado | Py: rename desde "Texto del evento" |

---

## 6. PREGUNTAS QUE NECESITO QUE RESPONDAS ANTES DE PARCHEAR

1. **Captura (H-C1):** ¿opción A (local primero) u opción B (global sin robar
   foco)? A es más simple y arregla S2/S4 de raíz; B conserva la captura de
   combos con stylus desde el propio Entry.
2. **RButton (H-R2):** ¿aceptas cambiar la semántica a "reenviar press real y
   suprimir solo si hubo combo", o prefieres mantener "suprimir y clic al
   soltar"? La primera es la única compatible con el cuentagotas mantenido.
3. **Nombre (S3):** ¿renombrar desde "Texto del evento" o campo nuevo en 01?
   ¿Solo `custom_*` o también fábrica (con override)?
4. **Toggle (H-T1):** ¿la guarda va en `_RemapDisparar` (global) o en
   `_ModToggle` (por evento)? Global es más seguro.
5. **`_poll`:** ¿puedo sustituir el `reload_all()` completo por un refresh
   dirigido (solo catálogo + editor) cuando el cambio venga de nuestra propia
   escritura?

---

## 7. FIRMAS DE HELPERS (para que escribas diffs sin ver los archivos)

```python
# app.py
CalibradorApp._select(id_ev)                      # editor.show_event + bridge SELECT_EVENT
CalibradorApp._on_dirty()                         # footer.set_info
CalibradorApp._add_event()                        # crea custom_N
CalibradorApp.save() -> bool
CalibradorApp.reload_all()
CalibradorApp._poll()                             # cada 600 ms
CalibradorApp._refresh_tabs(external=False)

# core/catalogo.py
Catalogo.load() -> Catalogo
Catalogo.por_id(id) -> Evento | None
Catalogo.siguiente_custom() -> (id, nombre)
Catalogo.eliminar_eventos(eids)
Evento(id, nombre, grupo, atajo_def, remap_def, bloques, custom, pausado)

# core/draft.py
Draft.get(name, id_ev); Draft.set(name, id_ev, value) -> bool
Draft.get_key(sec, key, default); Draft.set_key(sec, key, val, default)
Draft.patches() -> [(sec, key, val)]; Draft.count; Draft.clear()

# core/ini_store.py
IniFile.load(); IniFile.get(sec, key, default); IniFile.set(sec, key, val)
IniFile.delete(sec, key); IniFile.save_patches(patches, retries=6)
IniFile.keys(sec); IniFile.sections()

# ui/blocks.py
Block._commit(name, value) -> bool
Block.f_check(parent, name, text) -> CTkCheckBox
Block.f_entry(parent, name, width, placeholder) -> CTkEntry
Block.f_key_entry(parent, name, width, on_clear, defecto) -> (frame, entry)
Block.f_readonly_key_box(parent, text_fn, width) -> (frame, entry)
Block._sync_master(); Block.refresh(); Block._check(n); Block._uncheck(n)
A02Hud._probar_hud_cb(); A02Hud._test_hud()
B03Modulacion._tecla_base(); B03Modulacion._warn(); B03Modulacion._check/_uncheck

# ui/widgets.py
attach_keycapture(host, on_clear, on_commit, get_history) -> Entry
set_captura_bridge(send)
_tok_de(ev); _acorde_txt(pico); _find_entry(w)
KeyHistory(get_value, set_value)  # .seed/.push/.undo/.items/.apply/.history_tuple

# ui/panels.py
CatalogoPanel.rebuild(keep=True); .select(id_ev, notify=True); ._filter(keep); ._render_canvas(keep)
EditorPanel.show_event(ev); ._update_group_state(aplicar_colapso=False); ._schedule_prewarm(delay)
Footer.set_info(nombre, dirty, icon); Footer.flash(text, ok=True)
```

```ahk
; lib/hotkeys_csp.ahk
_RemapCargarHotkeys(); _RemapDescargarHotkeys()
_RemapNormalizar(txt) -> {hk, mods, principal, held}
_RemapCtx(held) -> fn            ; cache por firma de held
_RemapCtxOk(held) -> bool        ; CspLibre() + _TeclaSostenida
_RemapDisparar(idEv, tecla, held, *)
_TeclaSostenida(k) -> bool
_ModEnviar(atajo, hud := "", colorHud := "00E5FF") -> bool
_ModQuick(idEv, tecla, defBase, defParticular := "")
_ModToggle(idEv, defA := "", defB := "")
_ModActivo(fila, idEv) -> bool   ; Particularidades <fila>_<id> = "1"
_ModAtajo(fila, campo, idEv, def)
_LegadoActivo() -> bool
CspLibre() -> bool               ; captura_overlay.ahk

; lib/captura_overlay.ahk
Cap_Armar(seq := 0, target := "", etiqueta := "")
Cap_Cancelar(motivo := "api")
Cap_Preparar(target := "", etiqueta := "", seq := 0)
Cap_Armado() -> bool
Cap_FijarCallback(fn)            ; fn(seq, estado, combo, target)
_CapHotkeys(modo)                ; "On"/"Off"
_CapEsCSP() -> bool
_CspFoco()                       ; hotkeys_csp.ahk

; lib/calibrador_py.ahk
_CalPyEnviarPython(texto)
_CalPyCapResultado(seq, estado, combo, target)
_CalPyCapEstado() -> {on, tick}
_CalPyCapturaOn(); _CalPyCapturaOff()
_CalPyLog(msg)
```

---

## 8. DATOS EXACTOS PARA REPRODUCIR

- 8 eventos `custom_1..7,9`; `custom_8` eliminado pero con `atajo_custom_8=E`
  residual (el loader lo ignora por `[EventosEliminados]`).
- `custom_9`: `atajo=E`, `toggle=1`, `toggle_b=L` → reproduce H-T1.
- `custom_4`: `atajo=F6`, `remap=RButton+Q` → reproduce S1.
- `custom_3`: `atajo=F5`, `remap=RButton` → segundo caso de S1.
- Suite vacía: `--catalogo calibrador_py/data/catalogo_vacio.json`.

### Secuencia de prueba que falló (reconstruida del log)

1. Seleccionar `custom_9` → clic en "Atajo CSP" (vacío) → captura.
2. Escribir `E` → aparece ~2 s después (o no aparece).
3. Ir a B de "Pulsación rápida" → escribir `L` → el check se pinta ~8 s después.
4. Intentar corregir `E` → no cambia; hay que borrar el evento.
5. En CSP: botón 2 del lápiz → no sale el cuentagotas; botón 2 + Q → no dispara.

---

## 9. LO QUE NO SE DEBE TOCAR

- `IniFile` (preservación byte a byte, BOM UTF-16, `save_patches` atómico).
- El contrato de claves de `core/ini_schema.py` (nombres `campo_<id>`).
- `_LegadoActivo()` y los bloques `#HotIf CspLibre() && _LegadoActivo()`:
  son el modo legado; `legado=0` debe seguir funcionando.
- La estructura `[EventosCustom] <id>=nombre|grupo` (la lee AHK en
  `lib/calibrador.ahk:1834` y `:4865`).

---

**Fin del dossier.** Con esto puedes emitir diffs anclados sin acceso a la
máquina. Si necesitas un bloque que no esté aquí, pídelo por
`archivo + símbolo` y lo extraigo literal.
