; ┌─────────────────────────────────────────────────────────┐
; │  🎨 CSP ARTIST_PRO_16_GEN2 — SCRIPT TABLET ÚNICA  v52     │
; │                                                         │
; │  1. DIRECTIVAS GLOBALES                                 │
; │  2. ESTADO (objetos agrupados)                          │
; │  3. TIMERS                                               │
; │  4. HOTKEYS GLOBALES                                     │
; │  5. HOTKEYS CSP                                          │
; │     a) Selección y reselección                          │
; │     b) Deshacer / Rehacer                               │
; │     c) Herramientas (A E W Q S O R)                      │
; │     d) Atajos con clic derecho                          │
; │     e) Modificadores de capa                             │
; │  6. CLASE BorderFrame                                    │
; │  7. FUNCIONES                                            │
; └─────────────────────────────────────────────────────────┘

; ┌───────────────────────────────────────────────────────┐
; │  1. DIRECTIVAS GLOBALES                               │
; └───────────────────────────────────────────────────────┘
#Requires AutoHotkey v2.0
#SingleInstance Force
; Auto-elevación: CSP puede correr como admin (tras updates); si el script
; no está al mismo nivel, WinSetTransparent/WinSetExStyle fallan con Error 5 (UIPI).
if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
    }
    ExitApp()
}
; DPI awareness — coordenadas reales sin escalado de Windows
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
SendMode("Input")
SetWorkingDir(A_ScriptDir)
SetKeyDelay(-1, -1)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
CoordMode("Mouse",   "Screen")
CoordMode("ToolTip", "Screen")
SetTitleMatchMode(2)

; ┌──────────────────────────────────────────────────────────┐
; │  2. ESTADO  (objetos agrupados)                          │
; └──────────────────────────────────────────────────────────┘
sys := { lastModTime: "", modoEscritura: false }
stylus := { altActive: false, rButtonHeld: false, comboUsado: false, upSinteticoTick: 0, botonSostenido: false, smearSend: false, ignorarUpSintetico: false, bSinteticoTick: 0, origX: 0, origY: 0 }
sel := { estado: 0, estadoAltX: false, estadoC: 0, guiActivo: false, sRapido: false }
colorEstado     := 0   ; 0=primario  1=secundario  2=alpha
E := { procesando: false, last: 0 }
W := { last: 0 }
Z := { last: 0, timerRunning: 0 }
Q := { last: 0, estadoEstab: 0 }
RM := { last: 0 }   ; RButton & - (envía "t"/Regla): doble toque rápido → ocultar regla (Alt+T)
A_state := { lastPress: 0 }
AltS_state    := { lastPress: 0 }
AltB_s_state  := { lastPress: 0, timerRunning: 0 }
AltB_a_state  := { lastPress: 0, timerRunning: 0 }
AltF_state    := { lastPress: 0, timerRunning: 0, held: false }
S := { estadoCaracter: 0, skipNext: false }
O := { ciclo: 0 }
N6 := { estadoEscala: 0, layerVis: 1 }
hist := { abierto: false, modo: 1 }
btn := { b1: false, b2: false, b3: false }
botDer := { b1: false, b2: false, b3: false }
colorV := {
    dsID: 0, dsVis: false, bDS: 0, hover: true, cspHwnd: 0,
    dsX: 0, dsY: 0, dsW: 0, dsH: 0, supresionHasta: 0
}
; Círculo de colores — ventana flotante independiente (igual que deslizador)
colorCC := {
    id: 0, dsVis: false, bCC: 0, hover: false,
    ccX: 0, ccY: 0, ccW: 0, ccH: 0, supresionHasta: 0
}
ar := { id: 0, dsVis: false, bAR: 0, hover: false }
floatGui := { miniTip: 0, miniGUI: 0, tooltipToggle: 0, enfoque: 0, miniTipTick: 0, miniTipID: 0, hud: 0 }
enfoque := { activo: false }
shiftSostenido := { activo: false }
; Nivel de opacidad rastreado por el script (CSP no lo expone para leerlo
; de vuelta). Arranca en 100 porque es el valor por defecto de una capa
; nueva. RButton+1/+2 lo mueven de a 10 en 10 y mandan Shift+<dígito>;
; si usas RButton+3..RButton+0 para saltar directo a un valor, el nivel
; se sincroniza también, así los pasos relativos siguen desde ahí.
opacidad := { nivel: 100 }
boost := { holdDelay: 300, maxBoost: 5 }
spc := { last: 0, downTick: 0, selectArmed: false, rotOn: false }
dial := { modo: 1, g: 0, icono: 0, label: 0, barra: 0 }
dsGui := { g: 0, icono: 0, label: 0, barra: 0 }
ccGui := { g: 0, icono: 0, label: 0, barra: 0 }
arGui := { g: 0, icono: 0, label: 0, barra: 0 }
hcGui := { g: 0, icono: 0, label: 0, barra: 0 }
reloadGui := { g: 0, icono: 0, label: 0, barra: 0 }
lockGui := { g: 0, icono: 0, barra: 0 }
; Bloque de paneles ON/OFF (Slider, Circle, Quick, HC + botón de fijar).
; locked=true: no se pueden arrastrar (el clic sigue funcionando).
; El valor real se lee del .ini en IniciarLockGUI (por defecto: fijado).
panelBlk := { locked: true }
; Separación (px) entre paneles del bloque Slider/Circle/Quick. Antes se
; usaban offsets fijos (+84/+168) asumiendo 80px reales por panel; con
; escalado de Windows (DPI) eso no siempre se cumplía y los paneles
; terminaban pisándose. Ahora cada panel se coloca a partir del ancho
; REAL del anterior (medido con WinGetPos), y esta constante es solo el
; margen que se deja entre uno y el siguiente.
PANEL_GAP := 6

; Layouts fijos de los 3 paneles flotantes (Deslizador/Circulo/AccesoRapido)
; VALORES POR DEFECTO (respaldo) — el layout real se guarda con
; Ctrl+F11 (Normal) / Ctrl+F12 (Enfoque); ver _CapturarLayout.
LAYOUT_NORMAL := {
    ds: {x: -1070, y: 146, w: 382, h: 184},
    cc: {x: -688, y: 146, w: 359, h: 343},
    ar: {x: -580, y: 489, w: 238, h: 474}
}
LAYOUT_ENFOQUE := {
    ds: {x: -862, y: 146, w: 382, h: 184},
    cc: {x: -480, y: 129, w: 359, h: 343},
    ar: {x: -480, y: 489, w: 238, h: 474}
}

; ┌──────────────────────────────────────────────────────────────────────┐
; │  3. TIMERS                                                           │
; └──────────────────────────────────────────────────────────────────────┘
SetTimer(CheckReload,            600)
SetTimer(ChequearZonaHistorial,  200)
SetTimer(ChequearZonaAltA,        10)
SetTimer(ChequearZonaDerecha,     10)
SetTimer(LoopColorV,              80)
SetTimer(LoopColorCC,             80)
SetTimer(LoopAccesoRapido,        80)
SetTimer(ResetEnfoque,         10000)
SetTimer(ResetAlphaStates,       500)
IniciarDeteccion()
IniciarDialGUI()
IniciarDsGUI()
IniciarCcGUI()
IniciarArGUI()
IniciarHCGUI()
IniciarLockGUI()
IniciarReloadGUI()

; ┌──────────────────────────────────────────────────────┐
; │  4. HOTKEYS GLOBALES                                 │
; └──────────────────────────────────────────────────────┘
EsEditorTexto() => WinActive("ahk_exe notepad++.exe") || WinActive("ahk_exe notepad.exe")

#HotIf EsEditorTexto()
^s:: {
    SendInput("^s")
    Sleep(200)
    Reload()
}
^g:: {
    ; Doble chequeo: abortar si no es un editor de texto permitido
    if !(WinActive("ahk_exe notepad++.exe") || WinActive("ahk_exe notepad.exe"))
        return
    ts       := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    repoPath := "C:\Users\JOSUE\Desktop\AHK-global-main"
    gitExe   := "git"
    cmd      := gitExe ' -C "' repoPath '" add -A'
             .  ' && ' gitExe ' -C "' repoPath '" commit -m "auto_' ts '"'
             .  ' && ' gitExe ' -C "' repoPath '" push'
    Run('cmd /k "' cmd ' && timeout /t 3 && exit"', , "")
    SetTimer(_CheckGitDone, -5000)
}
#HotIf

#SuspendExempt
|:: {
    sys.modoEscritura := !sys.modoEscritura
    if (sys.modoEscritura) {
        Suspend(1)
        MostrarIndicador("🔴📝 MODO ESCRITURA — puedes escribir libremente 📝🔴")
    } else {
        Suspend(0)
        MostrarIndicador("🟢✅ MODO AHK ACTIVO — hotkeys habilitadas ✅🟢")
    }
}
#SuspendExempt False

; ┌──────────────────────────────────────────┐
; │  5a. RBUTTON GLOBAL — fuera de #HotIf   │
; │  Sin #HotIf para que Space & RButton    │
; │  no anule el standalone como prefix key │
; └──────────────────────────────────────────┘
; ┌──────────────────┐
; │  5. HOTKEYS CSP  │
; └──────────────────┘
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")

RButton:: {
    stylus.rButtonHeld     := true
    stylus.comboUsado      := false
    stylus.upSinteticoTick := 0
    ; Sin tilde — bloquea el down completamente, CSP no ve nada.
}
RButton up:: {
    elapsed := (stylus.upSinteticoTick > 0) ? (A_TickCount - stylus.upSinteticoTick) : 9999
    if (elapsed < UP_SINTETICO_MS) {
        stylus.rButtonHeld     := true
        stylus.upSinteticoTick := 0
        return
    }
    stylus.rButtonHeld := false
    if (!stylus.comboUsado)
        SendInput("{RButton}")   ; cuentagotas al soltar
}

Space & RButton:: {
    stylus.comboUsado := true
    _InvSeleccionConGUI()
}

Numpad0:: {
    hcOn := _ToggleHistorialColor()
    ActualizarHCGUI()
    MostrarHUD(hcOn ? "🟢 DYNAMIC HISTORY" : "🔒 HISTORY LOCKED", hcOn ? "00E5FF" : "FF6B00", 5000)
}

; Devuelve true si el historial quedó dinámico (ON), false si bloqueado (OFF).
_ToggleHistorialColor() {
    hist.modo := (hist.modo = 1) ? 2 : 1
    if (hist.modo = 2 && hist.abierto) {
        hist.abierto := false
        Send("{Numpad9}")
    }
    return (hist.modo = 1)
}

^s:: {
    SendInput("^s")
    SoundBeep(600, 100)
    SoundBeep(900, 150)
    MostrarHUD("💾 GUARDADO Y MODIFICADO", "44DD88", 800)
}

; ══════════════════════════════════════════════════════════════════
; RButton del stylus — LÓGICA GENERAL
;
; El driver reporta el clic derecho del stylus como INSTANTÁNEO
; (0-15ms). La lógica es: armar rButtonHeld al presionar, diferir
; la acción al soltar según si hubo combo o no.
;   sin combo → soltar manda {RButton} → cuentagotas en CSP
;   con combo → soltar no manda nada → cuentagotas absorbido
;
; POR QUÉ SIN TILDE EN RButton:: Y RButton up::
; Con tilde, el down nativo pasa a CSP y activa el cuentagotas
; inmediatamente al presionar, antes de saber si viene combo.
; Sin tilde, AHK intercepta el down antes de que llegue a CSP.
; Los combos ~RButton & X tienen su propia tilde y funcionan
; independientemente — quitarla aquí no los afecta.
;
; POR QUÉ comboUsado := true EN CADA ~RButton & X
; Si un combo no lo marca, al soltar RButton up:: ve comboUsado=false
; y manda el cuentagotas igual, aunque se haya usado un combo.
; Regla: todo hotkey ~RButton & X debe tener esa línea al inicio.
;
; ── REHACER (RButton + Ctrl+Z del miniteclado) ──────────────────
;
; POR QUÉ {RButton up} SINTÉTICO ANTES DE ^y
; CSP ignora atajos de historial mientras RButton está físicamente
; sostenido — lo trata como herramienta temporal activa. Solución:
; mandar {RButton up} sintético para que CSP "vea" el botón soltado.
; Ese up sintético también dispara RButton up:: — hay que ignorarlo
; sin resetear rButtonHeld (de lo contrario se rompe rehacer múltiple).
;
; POR QUÉ EL CURSOR SE MUEVE A (2775, 11) ANTES DEL UP SINTÉTICO
; Sin tilde el down no llegó a CSP, pero el up sintético sí llegaría
; como un up huérfano que CSP podría interpretar de formas raras.
; Moverlo a zona segura fuera del lienzo lo hace inofensivo.
;
; CÓMO SE DISTINGUE UP SINTÉTICO VS UP REAL (upSinteticoTick)
; Se marca upSinteticoTick = A_TickCount justo antes del up sintético.
; En RButton up:: elapsed = A_TickCount - upSinteticoTick.
; Sintético llega en 20-40ms, real en ≥100ms. Umbral = UP_SINTETICO_MS.
; elapsed < umbral → sintético: re-afirmar rButtonHeld, ignorar.
; elapsed ≥ umbral → real: resetear y procesar normalmente.
;
; botonSostenido: evita mandar up sintético en cada repetición de
; key repeat de Ctrl+Z. Solo el primer tap lo manda; las repeticiones
; van directo a ^y porque CSP ya "vio" el botón soltado.
; Se resetea en $^z up:: al soltar la tecla.
;
; CAMINOS DESCARTADOS
; ignorarProximoUp — bandera consumible, se desincronizaba con
;   key repeat (varios ups sintéticos consecutivos).
; GetKeyState("RButton","P") — el up sintético también lo afecta,
;   reporta "soltado" aunque el físico siga abajo.
; MODO_REHACER_MS — timer de expiración, funcional pero con espera
;   artificial de 200-600ms antes de poder volver a deshacer.
; ══════════════════════════════════════════════════════════════════
UP_SINTETICO_MS := 70

; Pasos de la estabilización: rango real 7→87. El comentario viejo decía
; "5 por pulsación" pero la prueba real (13 pulsaciones, 7→20) confirma
; que CSP mueve 1 unidad exacta por pulsación, no 5. Techo deseado: 75.
; Pulsar (75-7) = 68 veces desde el mínimo real (7) para aterrizar en 75.
; Para reajustar el techo, recalcula: objetivo - 7.
ESTABILIZACION_PASOS := 68


~!b:: {
    ; Ignorar el "down" sintético que nosotros mismos generamos en
    ; __AltF_SEND_NORMAL (forzar {b up}{b down} porque "Smear" en CSP
    ; es justo la tecla "b" — la misma que sostienes para este combo).
    ; Mismo criterio que RButton up:: (upSinteticoTick / UP_SINTETICO_MS).
    elapsedB := (stylus.bSinteticoTick > 0) ? (A_TickCount - stylus.bSinteticoTick) : 9999
    if (elapsedB < UP_SINTETICO_MS) {
        stylus.bSinteticoTick := 0
        return
    }
    if (stylus.smearSend)
        return
    stylus.altActive := true
}
~!b up:: {
    ; Mismo filtro que arriba, para el "up" sintético del mismo forzado.
    elapsedB := (stylus.bSinteticoTick > 0) ? (A_TickCount - stylus.bSinteticoTick) : 9999
    if (elapsedB < UP_SINTETICO_MS) {
        stylus.bSinteticoTick := 0
        return
    }
    ; Forzamos el estado real de Alt a "arriba" justo aquí, sin importar
    ; qué haya dejado cualquier SendEvent("{Alt up}X{Alt down}") de los
    ; handlers de arriba (x/w/-/e/s con Alt+B sostenido). Esto evita que
    ; stylus.altActive se quede pegado en true si el "up" físico llega
    ; justo en medio de uno de esos toggles sintéticos.
    Send("{Alt up}")
    stylus.altActive := false
    if (stylus.smearSend) {
        stylus.smearSend := false
        SendInput("b")
        MostrarHUD("SMEAR", "AA44FF", 950)
    }
}

; ┌───────────────────────────────┐
; │  5a. SELECCIÓN Y RESELECCIÓN  │
; └───────────────────────────────┘

c:: _InvSeleccionConGUI()

; Misma lógica de la tecla c pura (icono 🔄/🔁 + color rojo/verde que
; alterna, más los beeps). La comparten c:: y Space & RButton, así
; comparten también el estado sel.estadoC.
_InvSeleccionConGUI() {
    if (sel.estadoC = 0) {
        MostrarMiniTexto("🔄 INV. ÁREA SELECC.", "FF6F61", 900)
        SoundBeep(280, 120)
        SoundBeep(220, 160)
        sel.estadoC := 1
        SetTimer(__ResetEstadoC, -2000)
    } else {
        MostrarMiniTexto("🔁 INV. ÁREA SELECC.", "32CD32", 900)
        sel.estadoC := 0
        SetTimer(__ResetEstadoC, 0)
    }
    Send("c")
}

x:: {
    if stylus.altActive
        return
    if (sel.sRapido) {
        sel.sRapido := false
        MostrarMiniTexto("❌ DESELECCIÓN", "C0392B", 700)
        Send("x")
        sel.estado := 1
        return
    }
    if (sel.estado = 0) {
        MostrarMiniTexto("❌ DESELECCIÓN", "C0392B", 700)
        Send("x")
        sel.estado := 1
    } else {
        MostrarMiniTexto("✅ RESELECCIÓN", "27AE60", 1200)
        Send("{F10}")
        sel.estado := 0
    }
}

; ┌──────────────────────────┐
; │  5b. DESHACER / REHACER  │
; └──────────────────────────┘
$^z:: _DeshacerRehacer()

; Mask (Alt+M) — RButton + Ctrl+Z. botonSostenido evita que el auto-repeat
; de la tecla mantenida vuelva a alternar la máscara; se libera en
; "$^z up" / "~RButton & z up".
_MaskRButton() {
    stylus.comboUsado := true
    if (stylus.botonSostenido)
        return
    stylus.botonSostenido := true
    Send("!m")
    MostrarHUD("MASK (ALT+M)", "00E5FF", 900)
}

; Lógica compartida por $^z y ~RButton & z (cuando Ctrl está abajo).
_DeshacerRehacer() {
    ; De momento, con RButton sostenido este botón (K10, Ctrl+Z del
    ; keydial) es Mask (Alt+M) en vez de rehacer. Alt+B sigue rehaciendo.
    if (stylus.rButtonHeld) {
        _MaskRButton()
        return
    }
    if (stylus.rButtonHeld || stylus.altActive) {
        stylus.comboUsado := true
        if (!stylus.botonSostenido) {
            stylus.botonSostenido := true
            if (stylus.rButtonHeld) {
                ; RButton: mandar up sintético para desbloquear CSP
                stylus.upSinteticoTick := A_TickCount
                MouseGetPos(&origX, &origY)
                MouseMove(-2473, 15, 0)       ; zona segura fuera del lienzo (P31, estimada: antes 2007 corrida -4480) — no cambia color
                SendInput("{RButton up}")     ; libera RButton a nivel de CSP
                SendInput("^y")
                MouseMove(origX, origY, 0)
            } else {
                ; altActive (Alt+B): no hay RButton sostenido, rehacer directo
                SendInput("^y")
            }
        } else {
            ; Key repeat — CSP ya "vio" el botón soltado, solo rehacer
            SendInput("^y")
        }
        ToolTipCS("🟢 REHACER", 600)
    } else {
        SendInput("^z")
        ToolTipCS("🔴 DESHACER", 300)
    }
}
$^z up:: {
    stylus.botonSostenido := false
}
!z:: {
    SendInput("^c")
    ToolTipCS("📋 COPIAR", 600)
}
; Alt+B (altActive) + Ctrl+Z — Alt físico sostenido intercepta antes de $^z,
; por eso se registra como !^z separado. botonSostenido comparte el mismo flag
; para que key repeat funcione igual que con RButton.
!^z:: {
    if (!stylus.botonSostenido) {
        stylus.botonSostenido := true
        SendInput("^y")
    } else {
        SendInput("^y")
    }
    ToolTipCS("🟢 REHACER", 600)
}
!^z up:: {
    stylus.botonSostenido := false
}

#HotIf stylus.altActive
z:: {
    SendInput("^c")
    ToolTipCS("📋 COPIAR", 600)
}
w:: {
    Send("+s")
    MostrarHUD("SHIFT+S", "00E5FF", 800)
}
-:: {
    _CicloO()
}
e:: {
    MostrarHUD("ALL LAYERS ERASER", "FF4444", 800)
    Send("{F5}")
}
; SWAP: x/a ahora disparan color mix/smudge (antes era layer/all layers);
; s ahora dispara layer/all layers (antes era color mix/smudge).
x:: {
    if (AltB_a_state.lastPress = 1) {
        AltB_a_state.lastPress := 0
        SendEvent("p")
        MostrarHUD("SMUDGE  (P)", "FF6B00", 950)
    } else {
        AltB_a_state.lastPress := 1
        SendEvent("d")
        MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
    }
}
a:: {
    now := A_TickCount
    if (now - AltB_a_state.lastPress < 2400) {
        AltB_a_state.lastPress := 0
        Send("p")
        MostrarHUD("SMUDGE  (P)", "FF6B00", 950)
    } else {
        AltB_a_state.lastPress := now
        Send("d")
        MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
    }
}
s:: {
    now := A_TickCount
    if (now - AltB_s_state.lastPress < 2400) {
        AltB_s_state.lastPress := 0
        SendInput("{F7}")
        MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
    } else {
        AltB_s_state.lastPress := now
        SendInput("{Blind}a")
        MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
    }
}
; Respaldo bare (sin Alt detectado por Windows) para smear — mismo patrón
; EXACTO que s:: de arriba, solo con los valores intercambiados, más el
; bloqueo de auto-repeat (F se usa sostenida, s/x no).
f:: {
    if AltF_state.held
        return
    AltF_state.held := true
    now := A_TickCount
    if (now - AltF_state.lastPress < 2400) {
        AltF_state.lastPress := 0
        SendInput("{NumpadEnd}")
        MostrarHUD("SMEAR SOFT  (2)", "FF6B00", 950)
    } else {
        AltF_state.lastPress := now
        ; Mismo choque que en __AltF_SEND_NORMAL: "b" es la misma tecla
        ; que sostienes para el combo, así que forzamos {b up}{b down}
        ; marcado como sintético para que ~!b::/~!b up:: lo ignoren.
        stylus.bSinteticoTick := A_TickCount
        SendInput("{Blind}{b up}{b down}")
        MostrarHUD("SMEAR  (1)", "00E5FF", 950)
    }
}
f up:: {
    AltF_state.held := false
}

; ROTAR LIENZO al revés (Alt+B del stylus sostenido + Space).
; Copiado de la estructura de !^z:: (Alt+B + Ctrl+Z) y _MaskRButton:
;   - primera pulsación: hace el envío completo y marca rotOn
;   - repeticiones (auto-repeat / toques rápidos): envío directo, sin
;     re-alternar Alt, sin esperas y sin bloquear el hilo
;   - al soltar: se limpia la marca (ver "*Space up" más abajo)
; El orden Space→Alt es el que CSP necesita para rotar.
$!Space:: {
    if (!spc.rotOn) {
        spc.rotOn := true
        SendInput("{Blind}{Alt up}{Space down}{Alt down}")
    } else {
        SendInput("{Blind}{Space down}")
    }
}
#HotIf

; Suelta el Space sintético de la rotación. Contexto propio (spc.rotOn)
; para que funcione aunque ya hayas soltado Alt+B antes que Space, y
; para que el doble-tap de borde de ~Space up:: no se dispare mientras
; das varios toques de Space rotando.
#HotIf spc.rotOn
*Space up:: {
    spc.rotOn := false
    SendInput("{Blind}{Space up}")
}
#HotIf

#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")

; ┌────────────────────┐
; │  5c. HERRAMIENTAS  │
; └────────────────────┘

; ╔═══╗
; ║ A ║
; ╚═══╝
$a:: {
    if stylus.altActive
        return
    now := A_TickCount
    if (now - A_state.lastPress < 2400) {
        A_state.lastPress := 0
        SendInput("{F7}")
        MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
    } else {
        A_state.lastPress := now
        SendInput("{Blind}a")
        MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
    }
}

~RButton & a:: {
    stylus.comboUsado := true
    Send("ñ")
    MostrarHUD("REFERENCE LAYER", "AA44FF", 1680)
}

; ╔═══╗
; ║ E ║
; ╚═══╝
$e:: {
    global colorEstado
    now := A_TickCount
    if GetKeyState("Shift") {
        Send("e")
        return
    }
    ; Doble-tap (<300ms): cancelar el e ya enviado y lanzar l (soft eraser)
    if (now - E.last < 300) {
        E.last := 0
        SendInput("{e up}")
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        Send("l")
        MostrarToolTipE("SOFT ERASER  (2)")
        return
    }
    ; Tap simple: mandar e inmediatamente
    E.last := now
    if (colorEstado = 2) {
        Send("k")
        colorEstado := 0
    }
    Send("e")
    MostrarToolTipE("ERASER  (1)")
}

~RButton & e:: {
    stylus.comboUsado := true
    Send("{F12}")
    MostrarHUD("ERASER LAZO", "1A1A2E", 800)
}

^e:: {
    MostrarHUD("ALL LAYERS ERASER", "FF4444", 800)
    Send("{F5}")
}

!e:: {
    MostrarHUD("ALL LAYERS ERASER", "FF4444", 800)
    Send("{F5}")
}

!q:: {
    Send("y")
    MostrarHUD("SOFT (Y)", "00E5FF", 800)
}

; Alt+1 = subir opacidad 10% (empieza en 100% asumido). Alt+2 = bajarla.
; Pensado para el keydial: cada "clic" del dial dispara un lanzamiento,
; así que cada giro mueve la opacidad de a 10 en 10 — 100→90 (Shift+9),
; otro giro→80 (Shift+8), y así, hasta un piso de 10% (CSP no tiene
; forma de mandar 0% con este atajo de un solo dígito).
; Alt como tecla PREFIJO (igual que RButton), no como modificador "!":
; así cada clic del dial dispara de nuevo mientras Alt siga sostenido,
; sin tener que soltarlo entre paso y paso.
~LAlt & 1::
~RAlt & 1:: {
    opacidad.nivel := Min(opacidad.nivel + 10, 100)
    _EnviarOpacidad()
}

~LAlt & 2::
~RAlt & 2:: {
    opacidad.nivel := Max(opacidad.nivel - 10, 10)
    _EnviarOpacidad()
}

; Acceso rápido (mismo destino que la tecla física PageDown).
!Home:: {
    Send("{PageDown}")
    MostrarHUD("ACCESO RÁPIDO", "AA8844", 800)
}

!Space:: {
    SendInput("!g")
    MostrarHUD("FLIP HORIZONTAL", "888888", 700)
    SoundBeep(800, 100)
}

!-:: {
    _CicloO()
}

; ╔═══╗
; ║ W ║
; ╚═══╝
$w:: {
    global colorEstado
    now := A_TickCount
    ; Doble-tap (<300ms): toggle alpha y reseleccionar w
    if (now - W.last < 300) {
        W.last := 0
        if (colorEstado = 2) {
            SendInput("k")
            colorEstado := 0
            SendInput("{Blind}w")
            MostrarMiniTexto("💨 AERÓGRAFO", "1A1A2E", 1200)
        } else {
            if (colorEstado = 1)
                SendInput("^2")
            SendInput("k")
            colorEstado := 2
            SendInput("{Blind}w")
            MostrarMiniTexto("⚪ AERÓGRAFO ALPHA", "1C6EA4", 1200)
            SoundPlay(A_WinDir "\Media\Windows Ding.wav")
        }
        return
    }
    ; Tap simple: mandar w inmediatamente
    W.last := now
    SendInput("{Blind}w")
    MostrarMiniTexto(colorEstado = 2 ? "⚪ AERÓGRAFO ALPHA" : "💨 AERÓGRAFO", colorEstado = 2 ? "1C6EA4" : "1A1A2E", 1200)
}

; ╔═══╗
; ║ Z ║
; ╚═══╝
; z normal (un solo tap) = z INSTANTÁNEO, con tooltip de lupa 🔍
; z rápido (doble-tap, <300ms) = cancela el z ya enviado con {z up}
;   y lanza r, con tooltip de mano ✋. El primer tap nunca espera.
; Solo aplica cuando stylus.altActive = false — cuando es true, el
; z:: bajo #HotIf stylus.altActive (rehacer) tiene prioridad y este
; ni se evalúa.
$z:: {
    now := A_TickCount
    if (now - Z.last < 300) {
        ; Doble-tap: cancelar el z ya enviado y lanzar r
        Z.last         := 0
        Z.timerRunning := 0
        SendInput("{z up}")
        SendInput("r")
        MostrarToolTipZ("✋ R", 800)
        return
    }
    ; Primer tap: disparar z inmediatamente, sin esperar
    Z.last         := now
    Z.timerRunning := 1
    SendInput("{Blind}z")
    MostrarToolTipZ("🔍 Z", 800)
}

; ╔═══╗
; ║ Q ║
; ╚═══╝
$q:: {
    if GetKeyState("Alt", "P") {
        Send("!q")
        return
    }
    now := A_TickCount
    if (now - Q.last < 300) {
        Q.last := 0
        SetTimer(__Q_SEND_NORMAL, 0)
        global colorEstado
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        SendInput("^2")
        if (colorEstado = 0) {
            colorEstado := 1
            MostrarMiniTextoOscuro("🟡 COLOR SECUNDARIO", "51D67B", 1200)
            SoundPlay(A_WinDir "\Media\Windows Battery Low.wav")
        } else {
            colorEstado := 0
            MostrarMiniTexto("🔵 COLOR PRIMARIO", "2B3B32", 1200)
        }
        return
    }
    Q.last := now
    if GetKeyState("RButton", "P") {
        AlternarEstabilizacion()
        return
    }
    SetTimer(__Q_SEND_NORMAL, -50)
}

*-:: {
    AlternarEstabilizacion()
}

_ToggleLayerVis() {
    SendEvent("{Alt up}{Shift down}d{Shift up}")
    MostrarHUD(N6.layerVis ? "🚫 HIDE LAYER" : "👁 SHOW LAYER", N6.layerVis ? "FF4444" : "44DD88", 600)
    N6.layerVis := !N6.layerVis
}

+w:: {
    hoverOn := _ToggleHoverPaneles()
    ActualizarDsGUI()
    ActualizarCcGUI()
    ActualizarArGUI()
    if (hoverOn)
        MostrarMiniTexto("🟠 HOVER ON — deslizador + círculo + acceso rápido", "1E8449", 1200)
    else
        MostrarMiniTexto("👁 HOVER OFF — paneles visibles", "1A5276", 1200)
}

+q:: {
    Send("y")
    MostrarHUD("SOFT (Y)", "00E5FF", 800)
}

; ── Alt+J — mismo toggle que +w, refleja el estado en los 3 botones ──
!j:: {
    hoverOn := _ToggleHoverPaneles()
    ActualizarDsGUI()
    ActualizarCcGUI()
    ActualizarArGUI()
    if (hoverOn)
        MostrarTooltipToggle("HOVER ACTIVO", "▶", "verde")
    else
        MostrarTooltipToggle("HOVER PAUSADO", "⏸", "rojo")
}

; ══════════════════════════════════════════════════════════════════
; _SetColorV / _SetColorCC / _SetAR — fuerzan el panel correspondiente
; al estado "on" indicado (true=hover activo, false=panel fijo visible).
; Devuelven el mismo "on" recibido. Son la base de los toggles
; individuales (botones separados) y del toggle combinado (+q/Alt+J).
; ══════════════════════════════════════════════════════════════════
; ══════════════════════════════════════════════════════════════════
; _FadeAlpha — transición gradual de opacidad en vez de un salto
; instantáneo (5→255 o 255→5). El salto brusco es lo que se percibía
; como un "refresh"/destello al activar-desactivar el modo fijo-visible
; de estos paneles reales de CSP. Con 6 pasos de ~10ms (≈60ms total)
; el cambio se ve como un fundido rápido, no como un parpadeo.
; ══════════════════════════════════════════════════════════════════
_FadeAlpha(hwnd, hasta, pasos := 6, delayMs := 10) {
    try actual := WinGetTransparent("ahk_id " hwnd)
    if (actual = "" || !IsNumber(actual))
        actual := hasta
    if (actual = hasta)
        return
    paso := (hasta - actual) / pasos
    valor := actual
    Loop pasos {
        valor += paso
        v := Round(valor)
        v := (v < 0) ? 0 : (v > 255 ? 255 : v)
        try WinSetTransparent(v, "ahk_id " hwnd)
        Sleep(delayMs)
    }
    try WinSetTransparent(hasta, "ahk_id " hwnd)
}

_SetColorV(on) {
    colorV.hover := on
    colorV.dsVis := !on
    if (on)
        colorV.supresionHasta := A_TickCount + 400
    if (colorV.dsID && WinExist("ahk_id " colorV.dsID)) {
        SetTimer(LoopColorV, 0)
        if (on) {
            _FadeAlpha(colorV.dsID, 5)
            try WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        } else {
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
            try WinSetExStyle("-0x20", "ahk_id " colorV.dsID)
            _FadeAlpha(colorV.dsID, 255)
        }
        SetTimer(LoopColorV, 80)
    }
    return on
}

_SetColorCC(on) {
    colorCC.hover := on
    colorCC.dsVis := !on
    if (on)
        colorCC.supresionHasta := A_TickCount + 400
    if (colorCC.id && WinExist("ahk_id " colorCC.id)) {
        SetTimer(LoopColorCC, 0)
        if (on) {
            _FadeAlpha(colorCC.id, 5)
            try WinSetExStyle("+0x20", "ahk_id " colorCC.id)
        } else {
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
            try WinSetExStyle("-0x20", "ahk_id " colorCC.id)
            _FadeAlpha(colorCC.id, 255)
        }
        SetTimer(LoopColorCC, 80)
    }
    return on
}

_SetAR(on) {
    ar.hover := on
    ar.dsVis := !on
    if (ar.id && WinExist("ahk_id " ar.id)) {
        SetTimer(LoopAccesoRapido, 0)
        if (on) {
            _FadeAlpha(ar.id, 5)
            try WinSetExStyle("+0x20", "ahk_id " ar.id)
        } else {
            if IsObject(ar.bAR)
                ar.bAR.Hide()
            try WinSetExStyle("-0x20", "ahk_id " ar.id)
            _FadeAlpha(ar.id, 255)
        }
        SetTimer(LoopAccesoRapido, 80)
    }
    return on
}

; Toggles individuales — usados por el click de cada botón GUI propio.
_ToggleColorV()  => _SetColorV(!colorV.hover)
_ToggleColorCC() => _SetColorCC(!colorCC.hover)
_ToggleAR()      => _SetAR(!ar.hover)

; ══════════════════════════════════════════════════════════════════
; _ToggleHoverPaneles — pausa/reactiva los 3 paneles flotantes juntos
; (deslizador de color, círculo de colores, acceso rápido), tomando
; colorV como referencia del estado actual. Devuelve true si quedaron
; ON, false si quedaron OFF. Compartida por +q y Alt+J.
; ══════════════════════════════════════════════════════════════════
_ToggleHoverPaneles() {
    target := !colorV.hover
    _SetColorV(target)
    _SetColorCC(target)
    _SetAR(target)
    return target
}

; ╔═══╗

; ║ S ║
; ╚═══╝
; Alt+S (stylus Alt+B + S miniteclado) → mismo toggle que $s con stylus.altActive

; SWAP: !x ahora dispara color mix/smudge (antes layer/all layers);
; !s ahora dispara layer/all layers (antes color mix/smudge).
!x:: {
    if !stylus.altActive
        return
    now := A_TickCount
    if (now - AltB_a_state.lastPress < 300) {
        SetTimer(__AltX_SEND_NORMAL, 0)
        AltB_a_state.timerRunning := 0
        AltB_a_state.lastPress := 0
        SendEvent("{Alt up}p{Alt down}")
        MostrarHUD("SMUDGE  (P)", "FF6B00", 950)
        return
    }
    AltB_a_state.lastPress     := now
    AltB_a_state.timerRunning  := 1
    SetTimer(__AltX_SEND_NORMAL, -250)
}

__AltX_SEND_NORMAL() {
    if !AltB_a_state.timerRunning
        return
    AltB_a_state.timerRunning := 0
    ; Mismo caso que __AltF_SEND_NORMAL — ver comentario ahí.
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}d")
    if (seguiaSostenido)
        SendEvent("{Alt down}")
    MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
}

!s:: {
    if !stylus.altActive
        return
    now := A_TickCount
    if (now - AltB_s_state.lastPress < 300) {
        SetTimer(__AltS_SEND_NORMAL, 0)
        AltB_s_state.timerRunning := 0
        AltB_s_state.lastPress := 0
        SendEvent("{Alt up}{F7}{Alt down}")
        MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
        return
    }
    AltB_s_state.lastPress     := now
    AltB_s_state.timerRunning  := 1
    SetTimer(__AltS_SEND_NORMAL, -250)
}

__AltS_SEND_NORMAL() {
    if !AltB_s_state.timerRunning
        return
    AltB_s_state.timerRunning := 0
    ; Mismo caso que __AltF_SEND_NORMAL — ver comentario ahí.
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}a")
    if (seguiaSostenido)
        SendEvent("{Alt down}")
    MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
}

$s:: {
    if stylus.altActive
        return
    ; Si Alt físico está presionado (!s lo maneja), no hacer nada
    if GetKeyState("Alt", "P")
        return
    if (stylus.altActive) {
        Send("d")
        MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
        return
    }
    if ((A_PriorHotkey = "$s" || A_PriorHotkey = "s") && A_TimeSincePriorHotkey < 250) {
        S.skipNext := true
        sel.sRapido := true
        MostrarMiniTexto("🟢 ÁREA CON COLOR", "27AE60", 1200)
        SendInput("^x")
        SendEvent("{F7}")
        SoundPlay(A_WinDir "\Media\Windows Exclamation.wav")
        return
    }
    if (GetKeyState("Space", "P") || spc.selectArmed) {
        S.skipNext := true
        if (spc.selectArmed)
            SetTimer(_DesarmarSpaceSelect, -500)   ; cada S encadenado reinicia la ventana corta
        if (S.estadoCaracter = 0) {
            Send(",")
            MostrarTooltipToggle("AGREGAR A SELECCION", "+", "verde")
            S.estadoCaracter := 1
        } else {
            Send(".")
            MostrarTooltipToggle("ELIMINAR SELECCIÓN", "–", "rojo")
            S.estadoCaracter := 0
        }
        SetTimer(QuitarTooltipToggle, -1500)
        return
    }
    if S.skipNext {
        S.skipNext := false
        return
    }
    Send("s")
    SetTimer(() => MostrarHUD("LASSO", "FF6B00", 950), -1)
}

; ╔═══╗
; ║ O ║
; ╚═══╝
$o:: {
    _CicloO()
}

_CicloO() {
    O.ciclo := Mod(O.ciclo, 3) + 1
    if (O.ciclo = 1) {
        Send("h")
        MostrarMiniTexto("🔍 BUSCAR CAPAS (1/3)", "1A5276", 1200)
    } else if (O.ciclo = 2) {
        SendInput("{Ctrl down}{Numpad1}{Ctrl up}")
        MostrarMiniTexto("🎨 COLOR CAPA (2/3)", "6C3483", 1200)
    } else {
        SendInput("{Ctrl down}{Numpad2}{Ctrl up}")
        MostrarMiniTexto("🗑 BORRAR COLOR CAPA (3/3)", "424949", 1200)
    }
}

$Escape:: {
    if (O.ciclo != 0) {
        O.ciclo := 0
        MostrarMiniTexto("↺ CICLO O RESETADO", "555555", 900)
    }
    global colorEstado
    if (colorEstado = 2) {
        colorEstado := 0
        Send("k")
        MostrarMiniTexto("🎨 ALPHA RESETEADO", "555555", 900)
    }
    if (sel.guiActivo) {
        sel.guiActivo  := false
        sel.estadoAltX := false
        sel.estado     := 0
        Send("{Alt down}{x}{Alt up}")
        SetTimer(ResetEstadoAltX, 0)
        MostrarMiniTexto("↩ SELECCIÓN CANCELADA", "C0392B", 700)
        Send("x")
        Send("{Escape}")
        return
    }
    Send("{Escape}")
}

+r:: {
    MostrarHUD("REFLEJAR HORIZONTAL", "00E5FF", 1500)
    Send("+r")
}

Tab:: AccionEnfoque()
F3::  AccionEnfoque()

; f rápido (doble toque en <300ms) = mismo botón de modo enfoque.
; El caso stylus.altActive=true ya lo intercepta el f:: dentro de
; #HotIf stylus.altActive (líneas ~404-438, junto a x/a/s) — ese bloque
; tiene prioridad y esta variante ni se evalúa mientras Alt esté activo.
; Este f:: (sin ~) solo corre cuando NO hay Alt activo: ya no hay
; passthrough (se quitó el ~), así que replicamos manualmente la "f"
; normal para no perder la herramienta de CSP.
f:: {
    SendInput("{Blind}f")
    static ultimoF := 0
    ahora := A_TickCount
    if (ahora - ultimoF < 300) {
        AccionEnfoque()
        ultimoF := 0
    } else {
        ultimoF := ahora
    }
}

; ┌─────────────────────────────────────┐
; │  5d. ATAJOS CON CLIC DERECHO        │
; └─────────────────────────────────────┘
~RButton & s:: {
    stylus.comboUsado := true
    MostrarHUD("LAZO CON AUTORELLENO", "FF6B00", 1200)
    Send("{F9}")
}

~RButton & q:: {
    stylus.comboUsado := true
    Send("{F6}")
    MostrarHUD("HARD (F6)", "00E5FF", 800)
}

; Toggle capa escala de grises (7) / borrar capa de corrección (8) —
; comparte el mismo estado que $Numpad6:: (misma acción, dos disparadores).
~RButton & f:: {
    stylus.comboUsado := true
    if (N6.estadoEscala = 0) {
        Send("7")
        MostrarHUD("Gray scale", "888888", 1200)
        N6.estadoEscala := 1
    } else {
        Send("8")
        MostrarHUD("color", "FF4444", 1200)
        N6.estadoEscala := 0
    }
}

~RButton & w:: {
    stylus.comboUsado := true
    Send("ñ")
    MostrarHUD("difu_mixer 2", "00E5FF", 800)
}

!w:: {
    Send("<")
    MostrarHUD("★Opc_pressure 2", "00E5FF", 800)
}

; Antes disparaba AlternarEstabilizacion() (igual que "-" suelta); ahora
; el combo con RButton manda directamente "t". "-" suelta (sin RButton)
; sigue intacta más abajo (*-::) para el estabilizador.
~RButton & -:: {
    stylus.comboUsado := true
    now := A_TickCount
    ; Doble toque rápido (<300ms) del mismo combo → ocultar regla (Alt+T)
    if (now - RM.last < 300) {
        RM.last := 0
        Send("!t")
        MostrarHUD("OCULTAR REGLA", "1A1A2E", 800)
        return
    }
    RM.last := now
    Send("t")
    MostrarHUD("Rule", "1A1A2E", 800)
}

~RButton & z:: {
    stylus.comboUsado := true
    ; Ctrl+Z con RButton sostenido también coincide con este combo y
    ; disparaba el pegado. Si Ctrl está abajo, es rehacer, no pegar.
    ; Estado LÓGICO (sin "P"): el keydial manda Ctrl+Z por driver, no como
    ; teclas físicas, así que el estado físico de Ctrl siempre era falso.
    if GetKeyState("Ctrl") {
        _MaskRButton()
        return
    }
    Send("^v")
    MostrarHUD("📋 PEGAR (CTRL+V)", "44DD88", 800)
}

~RButton & z up:: {
    stylus.botonSostenido := false
}

~RButton & x:: {
    stylus.comboUsado := true
    Send("u")
    MostrarHUD("GRADIENT (U)", "00E5FF", 900)
}

; RButton+1 = Fill (V). RButton+2 = Advanced fill (F11).
~RButton & 1:: {
    stylus.comboUsado := true
    MostrarToolTipE("FILL  (V)")
    Send("v")
}

~RButton & 2:: {
    stylus.comboUsado := true
    Send("{F11}")
    MostrarHUD("Advanced fill", "AA8844", 800)
}

_EnviarOpacidad() {
    key := (opacidad.nivel = 100) ? "0" : String(opacidad.nivel // 10)
    Send("+" key)
    MostrarHUD("OPACIDAD " opacidad.nivel "%", "00E5FF", 1500)
}

~RButton & 3::
~RButton & 4::
~RButton & 5::
~RButton & 6::
~RButton & 7::
~RButton & 8::
~RButton & 9::
~RButton & 0:: {
    stylus.comboUsado := true
    key        := SubStr(A_ThisHotkey, StrLen(A_ThisHotkey))
    porcentaje := (key = "0") ? 100 : Integer(key) * 10
    opacidad.nivel := porcentaje
    MostrarHUD("OPACIDAD " porcentaje "%", "00E5FF", 1500)
    Send("+" key)
}

; ┌─────────────────────────────────────┐
; │  5e. DIAL — modo tamaño / opacidad  │
; └─────────────────────────────────────┘
; 1 y 2 = subir/bajar tamaño → modo 1
; 3 y 4 = subir/bajar opacidad → modo 2
; NumpadDiv = toggle manual entre modos
~1:: {
    if (dial.modo != 1) {
        dial.modo := 1
        ActualizarDialGUI()
    }
}
~2:: {
    if (dial.modo != 1) {
        dial.modo := 1
        ActualizarDialGUI()
    }
}
~3:: {
    if (dial.modo != 2) {
        dial.modo := 2
        ActualizarDialGUI()
    }
}
~4:: {
    if (dial.modo != 2) {
        dial.modo := 2
        ActualizarDialGUI()
    }
}
NumpadDiv:: {
    dial.modo := (dial.modo = 1) ? 2 : 1
    ActualizarDialGUI()
}

; ── PANIC BUTTON — reinicio de emergencia de todas las GUIs ──────
Numpad8:: {
    _LimpiarGUIs()
    ; Destruir dial incondicionalmente con fallback nuclear
    dialHwnd := 0
    try dialHwnd := dial.g.Hwnd
    try dial.g.Destroy()
    if (dialHwnd && DllCall("IsWindow", "Ptr", dialHwnd))
        DllCall("DestroyWindow", "Ptr", dialHwnd)
    dial.g     := 0
    dial.icono := 0
    dial.label := 0
    dial.barra := 0
    ; Desregistrar OnMessage antes de recrear, evita acumulación de handlers
    try OnMessage(0x0201, _DialWM_LBUTTONDOWN, 0)
    IniciarDialGUI()
    ; Mismo tratamiento para los botones SLIDER / CIRCLE / QUICK ON-OFF
    dsHwnd := 0
    try dsHwnd := dsGui.g.Hwnd
    try dsGui.g.Destroy()
    if (dsHwnd && DllCall("IsWindow", "Ptr", dsHwnd))
        DllCall("DestroyWindow", "Ptr", dsHwnd)
    dsGui.g     := 0
    dsGui.icono := 0
    dsGui.label := 0
    dsGui.barra := 0
    try OnMessage(0x0201, _DsGUI_WM_LBUTTONDOWN, 0)
    IniciarDsGUI()

    ccHwnd := 0
    try ccHwnd := ccGui.g.Hwnd
    try ccGui.g.Destroy()
    if (ccHwnd && DllCall("IsWindow", "Ptr", ccHwnd))
        DllCall("DestroyWindow", "Ptr", ccHwnd)
    ccGui.g     := 0
    ccGui.icono := 0
    ccGui.label := 0
    ccGui.barra := 0
    try OnMessage(0x0201, _CcGUI_WM_LBUTTONDOWN, 0)
    IniciarCcGUI()

    arHwnd := 0
    try arHwnd := arGui.g.Hwnd
    try arGui.g.Destroy()
    if (arHwnd && DllCall("IsWindow", "Ptr", arHwnd))
        DllCall("DestroyWindow", "Ptr", arHwnd)
    arGui.g     := 0
    arGui.icono := 0
    arGui.label := 0
    arGui.barra := 0
    try OnMessage(0x0201, _ArGUI_WM_LBUTTONDOWN, 0)
    IniciarArGUI()
    ; Mismo tratamiento para el botón HC ON/OFF
    hcHwnd := 0
    try hcHwnd := hcGui.g.Hwnd
    try hcGui.g.Destroy()
    if (hcHwnd && DllCall("IsWindow", "Ptr", hcHwnd))
        DllCall("DestroyWindow", "Ptr", hcHwnd)
    hcGui.g     := 0
    hcGui.icono := 0
    hcGui.label := 0
    hcGui.barra := 0
    try OnMessage(0x0201, _HCGUI_WM_LBUTTONDOWN, 0)
    IniciarHCGUI()
    ; Botón de fijar el bloque
    lockHwnd := 0
    try lockHwnd := lockGui.g.Hwnd
    try lockGui.g.Destroy()
    if (lockHwnd && DllCall("IsWindow", "Ptr", lockHwnd))
        DllCall("DestroyWindow", "Ptr", lockHwnd)
    lockGui.g     := 0
    lockGui.icono := 0
    lockGui.barra := 0
    try OnMessage(0x0201, _LockGUI_WM_LBUTTONDOWN, 0)
    IniciarLockGUI()
    ToolTip("🔄 GUIs reiniciadas")
    SetTimer(() => ToolTip(), -1000)
}

; ┌─────────────────────────────────────┐
; │  5f. MODIFICADORES DE CAPA          │
; └─────────────────────────────────────┘
~Space & NumpadAdd:: {
    Send("+p")
    MostrarMiniTexto("SPACE  +  +", "1E8449", 700)
}

~Space & NumpadSub:: {
    Send("^+p")
    MostrarMiniTexto("SPACE  +  −", "922B21", 700)
}

; Combo del keydial: mantienes Space presionado (pasa igual para la
; panorámica normal) y tocas w/x → Shift+w / Shift+s. Mismo patrón
; EXACTO que Space & NumpadAdd/NumpadSub de arriba.
~Space & w:: {
    Send("+w")
    MostrarMiniTexto("Up", "1E8449", 700)
}

; Mismo patrón EXACTO que Space & w de arriba.
~Space & x:: {
    Send("+s")
    MostrarMiniTexto("Down", "1E8449", 700)
}

; Mismo patrón EXACTO que Space & w / Space & x de arriba.
; Llama a _ToggleLayerVis() directamente — misma acción, mismo estado y
; mismo HUD ("HIDE LAYER"/"SHOW LAYER") que tenía antes Space & RButton.
~Space & e:: {
    _ToggleLayerVis()
}

; Mismo patrón EXACTO que Space & w / Space & x / Space & e.
~Space & q:: {
    Send("{Esc}")
    MostrarMiniTexto("ESC", "1E8449", 700)
}

; "Shift sostenido": mantiene Shift realmente presionado (a nivel de
; sistema) para poder encadenar varios atajos con Shift sin tener que
; sostenerlo físicamente. Ya no se suelta solo — es un toggle: un
; lanzamiento lo activa, el siguiente lanzamiento lo desactiva.
~Space & f:: {
    shiftSostenido.activo := !shiftSostenido.activo
    if (shiftSostenido.activo) {
        Send("{Shift down}")
        MostrarHUD("SHIFT SOSTENIDO", "AA8844", 900)
    } else {
        Send("{Shift up}")
        MostrarHUD("SHIFT LIBERADO", "555555", 700)
    }
}

~Space & Numpad1::
~Space & Numpad2::
~Space & Numpad3::
~Space & Numpad4::
~Space & Numpad5::
~Space & Numpad6:: {
    tecla := SubStr(A_ThisHotkey, StrLen(A_ThisHotkey))
    tipos := Map("1", "HSV (Hue / Sat / Val)"
               , "2", "Brillo / Contraste"
               , "3", "Equilibrio de color"
               , "4", "Curva de tonos"
               , "5", "Corrección de nivel"
               , "6", "Degradado")
    MostrarHUD("Capa: " tipos[tecla], "AA44FF", 500)
    Send("^!" tecla)
}



$Numpad6:: {
    if (N6.estadoEscala = 0) {
        Send("7")
        MostrarHUD("CAPA ESCALA DE GRISES", "888888", 1200)
        N6.estadoEscala := 1
    } else {
        Send("8")
        MostrarHUD("BORRAR CAPA DE CORRECCIÓN", "FF4444", 1200)
        N6.estadoEscala := 0
    }
}

*Backspace:: {
    if GetKeyState("Space", "P") {
        Send("8")
        MostrarHUD("BORRAR CAPA DE CORRECCIÓN", "FF4444", 1200)
        N6.estadoEscala := 0
        return
    }
    Send("{Backspace}")
}

~Space:: {
    spc.downTick := A_TickCount
}

~Space up:: {
    held := A_TickCount - spc.downTick
    now  := A_TickCount

    ; Doble-tap de borde: umbral estricto (pensado para teclado físico).
    if (held <= 180) && (now - spc.last < 320) {
        spc.last := 0
        sel.guiActivo := true
        if sel.estadoAltX {
            MostrarMiniTexto("👁 MOSTRAR BORDE", "2ECC71", 1200)
            sel.estadoAltX := false
        } else {
            MostrarMiniTexto("🚫 OCULTAR BORDE", "E74C3C", 1200)
            sel.estadoAltX := true
        }
        Send("{Alt down}{x}{Alt up}")
        SetTimer(ResetEstadoAltX, -3000)
        return
    }
    if (held <= 180)
        spc.last := now

    ; Armar bifurcación Space+S: umbral más permisivo (450ms) porque el
    ; keydial tarda más en registrar el clic que una tecla física — un
    ; hold real de Space (paneo del lienzo) dura bastante más que eso.
    if (held <= 450) {
        spc.selectArmed := true
        SetTimer(_DesarmarSpaceSelect, -500)
    }
}

_DesarmarSpaceSelect() {
    spc.selectArmed := false
}

#HotIf

; ┌────────────────────────────────────────────────────────────────┐
; │  6. CLASE BorderFrame                                          │
; └────────────────────────────────────────────────────────────────┘
class BorderFrame {
    T := 0
    B := 0
    L := 0
    R := 0

    __New(color) {
        opts := "-Caption +AlwaysOnTop +ToolWindow +E0x20"
        for side in ["T", "B", "L", "R"] {
            g := Gui(opts)
            g.BackColor := color
            g.Show("w0 h0 NoActivate")
            this.%side% := g
        }
    }

    Show(x, y, w, h, g := 1) {
        ; Usar SetWindowPos directo (bypass del scaling de Gui.Show).
        ; Gui.Show interpreta coords como lógicas del monitor primario (dpi=120)
        ; y las escala — SetWindowPos recibe coords físicas del sistema directamente.
        SWP_NOACTIVATE := 0x10
        SWP_SHOWWINDOW := 0x40
        flags := SWP_NOACTIVATE | SWP_SHOWWINDOW
        DllCall("SetWindowPos", "Ptr", this.T.Hwnd, "Ptr", -1, "Int", x,       "Int", y,           "Int", w, "Int", g, "UInt", flags)
        DllCall("SetWindowPos", "Ptr", this.B.Hwnd, "Ptr", -1, "Int", x,       "Int", y + h - g,   "Int", w, "Int", g, "UInt", flags)
        DllCall("SetWindowPos", "Ptr", this.L.Hwnd, "Ptr", -1, "Int", x,       "Int", y,           "Int", g, "Int", h, "UInt", flags)
        DllCall("SetWindowPos", "Ptr", this.R.Hwnd, "Ptr", -1, "Int", x + w - g, "Int", y,         "Int", g, "Int", h, "UInt", flags)
        ; Opacidad reducida (120→85 de 255) para que el marco sea más sutil.
        WinSetTransparent(85, "ahk_id " this.T.Hwnd)
        WinSetTransparent(85, "ahk_id " this.B.Hwnd)
        WinSetTransparent(85, "ahk_id " this.L.Hwnd)
        WinSetTransparent(85, "ahk_id " this.R.Hwnd)
    }

    Hide() {
        this.T.Hide()
        this.B.Hide()
        this.L.Hide()
        this.R.Hide()
    }
}

; ┌────────────────────────────────────────────────────────────────┐
; │  7. FUNCIONES                                                  │
; └────────────────────────────────────────────────────────────────┘

; ══════════════════════════════════════════════════════════════════
; ObtenerMonitorCSP — devuelve {x, y, w, h} del monitor donde está
; la ventana principal de CSP. Fallback al monitor primario.
; ══════════════════════════════════════════════════════════════════
ObtenerMonitorCSP() {
    if (colorV.cspHwnd) {
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " colorV.cspHwnd)
            cx := wx + ww // 2
            cy := wy + wh // 2
            loop MonitorGetCount() {
                MonitorGet(A_Index, &mL, &mT, &mR, &mB)
                if (cx >= mL && cx < mR && cy >= mT && cy < mB)
                    return { x: mL, y: mT, w: mR - mL, h: mB - mT }
            }
        }
    }
    ; Fallback: monitor primario
    pri := MonitorGetPrimary()
    MonitorGet(pri, &mL, &mT, &mR, &mB)
    return { x: mL, y: mT, w: mR - mL, h: mB - mT }
}

IniciarDeteccion() {
    bestHwnd := 0
    bestArea := 0
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            WinGetPos(&tx, &ty, &tw, &th, "ahk_id " hwnd)
            if (tw * th > bestArea) {
                bestArea := tw * th
                bestHwnd := hwnd
            }
        }
    }
    colorV.cspHwnd := bestHwnd
    colorV.dsID := BuscarVentanaCSP(0, "eslizador", "colores")
    if (colorV.dsID) {
        colorV.bDS   := BorderFrame("44AA66")
        colorV.hover := true
        colorV.dsVis := false
        try WinSetTransparent(5,    "ahk_id " colorV.dsID)
        try WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
    }
    colorCC.id := BuscarVentanaCSP(0, "rculo de colores", "olores")
    if (colorCC.id) {
        colorCC.bCC   := BorderFrame("AA6622")
        colorCC.hover := false
        colorCC.dsVis := true
        try WinSetTransparent(255,  "ahk_id " colorCC.id)
        try WinSetExStyle("-0x20", "ahk_id " colorCC.id)
    }
    ar.id := BuscarVentanaCSP(0, "Acceso r", "pido")
    if (ar.id) {
        ar.bAR   := BorderFrame("AA8844")
        ar.hover := false
        ar.dsVis := true
        try WinSetTransparent(255,  "ahk_id " ar.id)
        try WinSetExStyle("-0x20", "ahk_id " ar.id)
    }
}

BuscarVentanaCSP(idActual, frag1, frag2) {
    if (idActual) {
        try {
            if WinExist("ahk_id " idActual)
                return idActual
        }
    }
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            t := WinGetTitle("ahk_id " hwnd)
            if InStr(t, frag1) && InStr(t, frag2)
                return hwnd
        }
    }
    return 0
}

CheckReload() {
    newTime := FileGetTime(A_ScriptFullPath, "M")
    if (sys.lastModTime = "") {
        sys.lastModTime := newTime
        return
    }
    if (newTime != sys.lastModTime) {
        sys.lastModTime := newTime
        mon := ObtenerMonitorCSP()
        x := mon.x + (mon.w // 2) - 120
        y := mon.y + (mon.h // 2) - 20
        ToolTip("💾 Script actualizado y recargado", x, y)
        SoundBeep(750, 180)
        SoundBeep(950, 180)
        SoundBeep(850, 180)
        Sleep(300)
        ToolTip()
        Reload()
    }
}

; ══════════════════════════════════════════════════════════════════
; ChequearZonaHistorial — franja "peek" del panel Historial de color,
; recalibrada con CALIBRADOR_v3_DPI en la Artist Pro 16 Gen2.
;   Zona (P27-P30): x[-2229,-396]  y[1491,1595]  (ESTIMADA: antigua x[2251,4084] corrida -4480)
; ══════════════════════════════════════════════════════════════════
ChequearZonaHistorial() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    if (hist.modo = 2)
        return
    MouseGetPos(&mx, &my)
    enZona := (mx >= -2229 && mx <= -396 && my >= 1491 && my <= 1595)
    if (enZona && !hist.abierto) {
        hist.abierto := true
        Send("{Numpad9}")
    } else if (!enZona && hist.abierto) {
        hist.abierto := false
        Send("{Numpad9}")
    }
}

; ══════════════════════════════════════════════════════════════════
; ChequearZonaAltA — botones IZQUIERDA (3 zonas, recalibradas con
; CALIBRADOR_v3_DPI en la Artist Pro 16 Gen2 — DPI awareness correcto).
; Zonas exactas, sin margen, derivadas de los 4 puntos-esquina de cada icono.
;   Botón 1 (P1-P4)   :  x[-2556,-2504]  y[107,142]
;   Botón 2 (P5-P8)   :  x[-2556,-2506]  y[152,186]
;   Botón 3 (P9-P12)  :  x[-2556,-2506]  y[191,226]
;   (Tableta ahora a la izquierda del monitor principal: x negativas.)
; ══════════════════════════════════════════════════════════════════
ChequearZonaAltA() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= -2556 && mx <= -2504 && my >= 107 && my <= 142)
    if (enZona1 && !btn.b1) {
        btn.b1 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona1 && btn.b1)
        btn.b1 := false
    enZona2 := (mx >= -2556 && mx <= -2506 && my >= 152 && my <= 186)
    if (enZona2 && !btn.b2) {
        btn.b2 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona2 && btn.b2)
        btn.b2 := false
    enZona3 := (mx >= -2556 && mx <= -2506 && my >= 191 && my <= 226)
    if (enZona3 && !btn.b3) {
        btn.b3 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona3 && btn.b3)
        btn.b3 := false
}

; ══════════════════════════════════════════════════════════════════
; ChequearZonaDerecha — botones DERECHA (3 zonas, recalibradas con
; CALIBRADOR_v3_DPI en la Artist Pro 16 Gen2 — DPI awareness correcto).
;   Botón 1 (P13-P16): x[-56,-4]  y[108,142]
;   Botón 2 (P17-P20): x[-57,-6]  y[151,183]
;   Botón 3 (P21-P24): x[-56,-7]  y[191,230]
; ══════════════════════════════════════════════════════════════════
ChequearZonaDerecha() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= -56 && mx <= -4 && my >= 108 && my <= 142)
    if (enZona1 && !botDer.b1) {
        botDer.b1 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona1 && botDer.b1)
        botDer.b1 := false
    enZona2 := (mx >= -57 && mx <= -6 && my >= 151 && my <= 183)
    if (enZona2 && !botDer.b2) {
        botDer.b2 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona2 && botDer.b2)
        botDer.b2 := false
    enZona3 := (mx >= -56 && mx <= -7 && my >= 191 && my <= 230)
    if (enZona3 && !botDer.b3) {
        botDer.b3 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona3 && botDer.b3)
        botDer.b3 := false
}

LoopColorV() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorV.hover) {
            if (colorV.dsVis && colorV.dsID) {
                colorV.dsVis := false
                try WinSetTransparent(5,   "ahk_id " colorV.dsID)
                try WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
            }
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
        }
        return
    }
    if (!colorV.dsID) {
        colorV.dsID := BuscarVentanaCSP(0, "eslizador", "colores")
        if (colorV.dsID) {
            colorV.bDS   := BorderFrame("44AA66")
            colorV.dsVis := false
            try WinSetTransparent(5,    "ahk_id " colorV.dsID)
            try WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorV.dsID) {
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
            colorV.dsID  := 0
            colorV.dsVis := false
            return
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " colorV.dsID)
        if (wx != colorV.dsX || wy != colorV.dsY) {
            colorV.dsX := wx
            colorV.dsY := wy
            colorV.dsW := ww
            colorV.dsH := wh
        } else {
            wx := colorV.dsX
            wy := colorV.dsY
            ww := colorV.dsW
            wh := colorV.dsH
        }
    } catch {
        if IsObject(colorV.bDS)
            colorV.bDS.Hide()
        colorV.dsID  := 0
        colorV.dsVis := false
        return
    }
    ; Modo fijo (hover=false): el deslizador ya quedó permanentemente
    ; visible por el propio toggle. Ya refrescamos su posición arriba
    ; (para que el círculo pueda usarla en su propio cruce) — no
    ; tocamos su visibilidad aquí.
    if (!colorV.hover)
        return

    MouseGetPos(&mx, &my)
    enDS := (mx >= wx && mx <= wx+ww && my >= wy && my <= wy+wh)
    ; Zona círculo de colores → deslizador (dirección original pedida):
    ; - Círculo FIJO: se usa su geometría real (colorCC sigue refrescándola
    ;   aunque esté fijo).
    ; - Círculo en HOVER (ambos ocultos por defecto): se usa colorCC.dsVis,
    ;   que ya refleja "el mouse está encima ahora mismo" resuelto por
    ;   LoopColorCC. Así, pasar el mouse por el círculo sigue mostrando el
    ;   deslizador aunque ambos estén ocultos.
    ; Ojo: esto es a propósito unidireccional. El enlace inverso
    ; (deslizador→círculo) solo aplica cuando el deslizador está FIJO
    ; (ver LoopColorCC) — si también reaccionara en modo hover, pasar el
    ; mouse por CUALQUIERA de los dos encendería a los dos.
    enCirculo := false
    if (colorCC.id && colorCC.ccW > 0) {
        if (colorCC.hover)
            enCirculo := colorCC.dsVis
        else
            enCirculo := (mx >= colorCC.ccX && mx <= colorCC.ccX + colorCC.ccW
                       && my >= colorCC.ccY && my <= colorCC.ccY + colorCC.ccH)
    }
    if (A_TickCount < colorV.supresionHasta) {
        enDS := false
        enCirculo := false
    }
    if (enDS || enCirculo) {
        if (!colorV.dsVis) {
            colorV.dsVis := true
            try WinSetTransparent(255,  "ahk_id " colorV.dsID)
            try WinSetExStyle("-0x20", "ahk_id " colorV.dsID)
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
        }
    } else {
        if (colorV.dsVis) {
            colorV.dsVis := false
            try WinSetTransparent(5,    "ahk_id " colorV.dsID)
            try WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        }
        if IsObject(colorV.bDS)
            colorV.bDS.Show(wx, wy, ww, wh)
    }
}

; ══════════════════════════════════════════════════════════════════
; LoopColorCC — hover + borde para el Círculo de colores flotante.
; Detecta la ventana dinámica por título ("Circulo de colores"),
; actualiza su posición en colorCC.ccX/Y/W/H para que LoopColorV
; use esas coordenadas reales como zona de activación del deslizador.
; ══════════════════════════════════════════════════════════════════
LoopColorCC() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorCC.hover) {
            if (colorCC.dsVis && colorCC.id) {
                colorCC.dsVis := false
                try WinSetTransparent(5,   "ahk_id " colorCC.id)
                try WinSetExStyle("+0x20", "ahk_id " colorCC.id)
            }
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
        }
        colorCC.ccW := 0
        return
    }
    if (!colorCC.id) {
        colorCC.id := BuscarVentanaCSP(0, "rculo de colores", "olores")
        if (colorCC.id) {
            colorCC.bCC   := BorderFrame("AA6622")
            colorCC.dsVis := false
            try WinSetTransparent(5,    "ahk_id " colorCC.id)
            try WinSetExStyle("+0x20", "ahk_id " colorCC.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorCC.id) {
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
            colorCC.id   := 0
            colorCC.dsVis := false
            colorCC.ccW  := 0
            return
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " colorCC.id)
        colorCC.ccX := wx
        colorCC.ccY := wy
        colorCC.ccW := ww
        colorCC.ccH := wh
    } catch {
        if IsObject(colorCC.bCC)
            colorCC.bCC.Hide()
        colorCC.id   := 0
        colorCC.dsVis := false
        colorCC.ccW  := 0
        return
    }
    ; Modo fijo (hover=false): el panel ya quedó permanentemente visible
    ; por el propio toggle. Ya refrescamos su posición arriba (para el
    ; cruce con el deslizador) — no tocamos su visibilidad aquí.
    if (!colorCC.hover)
        return

    MouseGetPos(&mx, &my)
    dentro := (mx >= wx && mx <= wx+ww && my >= wy && my <= wy+wh)
    ; Cruce con el deslizador: solo cuando el deslizador está FIJO
    ; (hover=false) — ahí sí tiene sentido que pasar el mouse por él
    ; también muestre el círculo. Si el deslizador está en hover (ambos
    ; ocultos por defecto), no se activa el círculo desde acá: el enlace
    ; círculo→deslizador en ese caso es intencionalmente unidireccional
    ; (ver LoopColorV) — así, pasar el mouse por el deslizador solo por
    ; sí solo no enciende también al círculo.
    if (!dentro) {
        enDeslizador := false
        if (!colorV.hover && colorV.dsID && colorV.dsW > 0)
            enDeslizador := (mx >= colorV.dsX && mx <= colorV.dsX + colorV.dsW
                           && my >= colorV.dsY && my <= colorV.dsY + colorV.dsH)
        dentro := enDeslizador
    }
    if (A_TickCount < colorCC.supresionHasta)
        dentro := false
    if (dentro) {
        if (!colorCC.dsVis) {
            colorCC.dsVis := true
            try WinSetTransparent(255,  "ahk_id " colorCC.id)
            try WinSetExStyle("-0x20", "ahk_id " colorCC.id)
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
        }
    } else {
        if (colorCC.dsVis) {
            colorCC.dsVis := false
            try WinSetTransparent(5,    "ahk_id " colorCC.id)
            try WinSetExStyle("+0x20", "ahk_id " colorCC.id)
        }
        if IsObject(colorCC.bCC)
            colorCC.bCC.Show(wx, wy, ww, wh)
    }
}

LoopAccesoRapido() {
    if (!ar.hover)
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (ar.dsVis && ar.id) {
            ar.dsVis := false
            try WinSetTransparent(5,   "ahk_id " ar.id)
            try WinSetExStyle("+0x20", "ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Hide()
        return
    }
    if (!ar.id) {
        ar.id := BuscarVentanaCSP(0, "Acceso r", "pido")
        if (ar.id) {
            ar.bAR   := BorderFrame("AA8844")
            ar.dsVis := false
            try WinSetTransparent(5,    "ahk_id " ar.id)
            try WinSetExStyle("+0x20", "ahk_id " ar.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " ar.id) {
            if IsObject(ar.bAR)
                ar.bAR.Hide()
            ar.id    := 0
            ar.dsVis := false
            return
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " ar.id)
    } catch {
        if IsObject(ar.bAR)
            ar.bAR.Hide()
        ar.id    := 0
        ar.dsVis := false
        return
    }
    MouseGetPos(&mx, &my)
    dentro := (mx >= wx && mx <= wx+ww && my >= wy && my <= wy+wh)
    if (dentro) {
        if (!ar.dsVis) {
            ar.dsVis := true
            try WinSetTransparent(255,  "ahk_id " ar.id)
            try WinSetExStyle("-0x20", "ahk_id " ar.id)
            if IsObject(ar.bAR)
                ar.bAR.Hide()
        }
    } else {
        if (ar.dsVis) {
            ar.dsVis := false
            try WinSetTransparent(5,    "ahk_id " ar.id)
            try WinSetExStyle("+0x20", "ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Show(wx, wy, ww, wh)
    }
}

; ══════════════════════════════════════════════════════════════════
; VigilarAltPegado — red de seguridad contra el bug de "Alt atorado".
; Si stylus.altActive quedó en true pero el Alt físico ya no está
; realmente presionado (GetKeyState dice que no), lo corrige solo.
; Esto es lo que evitaba que E/-/W/Z/X/A/S se quedaran disparando la
; versión "Alt+B sostenido" de esas teclas para siempre.
; ══════════════════════════════════════════════════════════════════
; VigilarAltPegado eliminada — no existía en la Artist Pro 14 Gen2 y
; era la única causa real de que se cortara el hold-and-repeat de
; Alt+B con el keydial. Port 1:1 del comportamiento de la 14.

ResetProcesando() => E.procesando := false


__Q_SEND_NORMAL() {
    global colorEstado
    SendInput("q")
    if (colorEstado = 1)
        MostrarMiniTextoOscuro("🟡 COLOR SECUNDARIO", "51D67B", 800)
    else if (colorEstado = 2)
        MostrarMiniTexto("⚪ ALPHA TRANSPARENTE", "1C6EA4", 800)
    else
        MostrarMiniTexto("🔵 COLOR PRIMARIO", "2B3B32", 800)
}

AlternarEstabilizacion() {
    static ocupado := false
    ; Si ya hay una ráfaga en curso (todavía "asentándose" en CSP), se
    ; ignora este toggle en vez de dejar que se cruce con la anterior.
    ; Antes, si llegaba un segundo toggle mientras el primero seguía
    ; mandando teclas (o el usuario empezaba a dibujar en ese momento),
    ; las dos ráfagas de "-"/"j" se entrelazaban en CSP y el valor final
    ; quedaba a mitad de camino (ej. 35, 100) en vez de fijo en 7 o 75.
    if (ocupado)
        return
    ocupado := true
    if (Q.estadoEstab = 0) {
        Q.estadoEstab := 1
        MostrarMiniTexto("🟢 ESTABILIZACIÓN ALTA", "1A5C2A", 1000)
        SendInput("{Blind}{- " ESTABILIZACION_PASOS "}")
        Sleep(250)
        SoundBeep(830, 80)
        SoundBeep(960, 80)
    } else {
        Q.estadoEstab := 0
        MostrarMiniTexto("🔵 ESTABILIZACIÓN BAJA", "1A2E5C", 1000)
        SendInput("{Blind}{j " ESTABILIZACION_PASOS "}")
        Sleep(250)
        SoundBeep(420, 80)
    }
    ocupado := false
}

_CheckGitDone() {
    MostrarHUD("✅ GitHub actualizado", "44DD88", 2000)
    SoundPlay(A_WinDir "\Media\Windows Navigation Start.wav")
}

ResetEstadoAltX() {
    sel.estadoAltX := false
    sel.guiActivo  := false
}

__ResetEstadoC() {
    sel.estadoC := 0
}

; ── ToolTips / HUD ───────────────────────────────────────────────
; Slot 1 : ToolTip nativo — solo CheckReload y ^g (notepad++)
; HUD    : MostrarHUD — GUI estilo dial para todas las herramientas

; ══════════════════════════════════════════════════════════════════
; MostrarHUD — GUI unificada estilo dial para feedback de hotkeys
; Fondo oscuro 1a1a1a, texto bold blanco, barra de color abajo.
; Posición: dinámica vía ObtenerMonitorCSP() — centrada horizontal
; Y verticalmente en el monitor CSP. Esta es la caja de avisos rápidos
; (E, E rápido, Alt+Q/W/E, etc.) — distinta del GUI permanente del
; dial (Tamaño/Opacidad), que va arriba.
; colorBarra: hex sin # (ej. "00E5FF"). duracion en ms.
; ══════════════════════════════════════════════════════════════════
_DestruirGui(guiObj) {
    if !IsObject(guiObj)
        return
    hwnd := 0
    try hwnd := guiObj.Hwnd
    try guiObj.Destroy()
    ; Fallback nuclear: si la ventana sigue viva después de Destroy(), cerrarla por hwnd
    if (hwnd && DllCall("IsWindow", "Ptr", hwnd))
        DllCall("DestroyWindow", "Ptr", hwnd)
}

_LimpiarGUIs() {
    _DestruirGui(floatGui.hud)
    floatGui.hud := 0

    _DestruirGui(floatGui.miniTip)
    floatGui.miniTip     := 0
    floatGui.miniTipID   := 0
    floatGui.miniTipTick := 0

    _DestruirGui(floatGui.tooltipToggle)
    floatGui.tooltipToggle := 0

    _DestruirGui(floatGui.miniGUI)
    floatGui.miniGUI := 0

    _DestruirGui(floatGui.enfoque)
    floatGui.enfoque := 0
    enfoque.activo   := false
}

MostrarHUD(texto, colorBarra := "00E5FF", duracion := 1200) {
    _LimpiarGUIs()
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := "1a1a1a"
    g.MarginX := 0
    g.MarginY := 0
    WinSetTransparent(210, g)
    lbl := g.Add("Text", "x0 y7 w208 h26 cWhite +0x200 Center", texto)
    lbl.SetFont("s12 bold", "Segoe UI")
    bar := g.Add("Progress", "x0 y35 w208 h5 Background333333")
    bar.Opt("c" colorBarra)
    bar.Value := 100
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - 208) // 2
    y := mon.y + (mon.h - 40) // 2
    g.Show("x" x " y" y " w208 h40 NoActivate")
    floatGui.hud := g
    hwnd := g.Hwnd
    SetTimer(() => _OcultarHUDSi(hwnd), -duracion)
}

_OcultarHUDSi(hwnd) {
    try {
        if (IsObject(floatGui.hud) && floatGui.hud.Hwnd = hwnd) {
            floatGui.hud.Destroy()
            floatGui.hud := 0
        }
    } catch {
        floatGui.hud := 0
    }
}

QuitarToolTip()      => ToolTip()
OcultarToolTip()     => ToolTip()
OcultarToolTipAltG() => ToolTip()
OcultarToolTipQ()    => ToolTip()
OcultarIndicador()   => ToolTip()
QuitarToolTipE()     => ToolTip(, , , 3)
QuitarToolTipZ()     => ToolTip(, , , 4)

MostrarIndicador(texto) {
    ToolTip(texto)
    SetTimer(OcultarIndicador, -2500)
}

; Slot 3 exclusivo — no interfiere con QuitarToolTip (slot 1)
MostrarToolTipE(texto, duracion := 2190) {
    MostrarHUD(texto, "FF4444", duracion)
}

; Slot 4 exclusivo — no interfiere con slot 1 ni con MostrarToolTipE (slot 3)
MostrarToolTipZ(texto, duracion := 800) {
    MostrarHUD(texto, "00E5FF", duracion)
}

ToolTipCS(texto, duracion := 800) {
    MostrarHUD(texto, texto = "🟢 REHACER" ? "44DD88" : "FF4444", duracion)
}

CustomToolTip(text, duration := 1500) {
    ToolTip(text, , , 2)
    SetTimer(RemoveCustomToolTip, -duration)
}

RemoveCustomToolTip() => ToolTip(, , , 2)

MostrarMiniTexto(texto, colorHex := "222222", duracion := 800, colorTexto := "FFFFFF") {
    _LimpiarGUIs()
    thisID := A_TickCount
    floatGui.miniTipID   := thisID
    floatGui.miniTipTick := thisID
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := colorHex
    g.SetFont("s12 Bold", "Segoe UI")
    g.AddText("c" colorTexto " Center w260", texto)
    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    mon := ObtenerMonitorCSP()
    targetX := mon.x + (mon.w - w) // 2
    targetY := mon.y + Round(mon.h * 0.47)
    g.Show("x" targetX " y" targetY " w" w " h" h " NoActivate")
    WinSetTransparent(200, "ahk_id " g.Hwnd)
    floatGui.miniTip := g
    capturedID := thisID
    SetTimer(() => _OcultarMiniTipSi(capturedID), -duracion)
}

_OcultarMiniTipSi(id) {
    if (floatGui.miniTipID != id)
        return
    try {
        if IsObject(floatGui.miniTip)
            floatGui.miniTip.Destroy()
    }
    floatGui.miniTip     := 0
    floatGui.miniTipID   := 0
    floatGui.miniTipTick := 0
}

MostrarMiniTextoOscuro(texto, colorHex := "EEEEEE", duracion := 800) {
    MostrarMiniTexto(texto, colorHex, duracion, "000000")
}

OcultarMiniTip() {
    try {
        if IsObject(floatGui.miniTip)
            floatGui.miniTip.Destroy()
    }
    floatGui.miniTip     := 0
    floatGui.miniTipID   := 0
    floatGui.miniTipTick := 0
}

MostrarMiniGUI(texto, colorHex := "222222", duracion := 1200) {
    if IsObject(floatGui.miniGUI)
        try floatGui.miniGUI.Destroy()
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := colorHex
    g.SetFont("s12 Bold", "Segoe UI")
    g.AddText("cFFFFFF Center w260", texto)
    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    mon := ObtenerMonitorCSP()
    g.Show("x" mon.x + (mon.w - w) // 2 " y" mon.y + Round(mon.h * 0.02) " w" w " h" h " NoActivate")
    WinSetTransparent(200, "ahk_id " g.Hwnd)
    floatGui.miniGUI := g
    hwndMG := g.Hwnd
    SetTimer(() => _OcultarMiniGUISi(hwndMG), -duracion)
}

_OcultarMiniGUISi(hwndMG) {
    try {
        if (IsObject(floatGui.miniGUI) && floatGui.miniGUI.Hwnd = hwndMG) {
            floatGui.miniGUI.Destroy()
            floatGui.miniGUI := 0
        }
    } catch {
        floatGui.miniGUI := 0
    }
}

OcultarMiniGUI() {
    if IsObject(floatGui.miniGUI)
        try floatGui.miniGUI.Destroy()
    floatGui.miniGUI := 0
}

MostrarTooltipToggle(titulo, simbolo, color) {
    _LimpiarGUIs()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    if (color = "verde") {
        g.BackColor := "1F4D3A"
        g.SetFont("s12 Bold cWhite", "Segoe UI")
        simColor := "Lime"
    } else {
        g.BackColor := "D92B2B"
        g.SetFont("s12 Bold cWhite", "Segoe UI")
        simColor := "White"
    }
    g.AddText("x8 y5 w221 h23 Center", titulo)
    g.SetFont("s12 Bold c" simColor, "Segoe UI")
    g.AddText("x232 y4 w23 h23 Center", simbolo)
    mon := ObtenerMonitorCSP()
    g.Show("x" mon.x + (mon.w - 260) // 2 " y" mon.y + Round(mon.h * 0.47) " w260 h34 NoActivate")
    floatGui.tooltipToggle := g
    hwndT := g.Hwnd
    SetTimer(() => _OcultarToggleSi(hwndT), -1500)
}

_OcultarToggleSi(hwndT) {
    try {
        if (IsObject(floatGui.tooltipToggle) && floatGui.tooltipToggle.Hwnd = hwndT) {
            floatGui.tooltipToggle.Destroy()
            floatGui.tooltipToggle := 0
        }
    } catch {
        floatGui.tooltipToggle := 0
    }
}

QuitarTooltipToggle() {
    if IsObject(floatGui.tooltipToggle)
        try floatGui.tooltipToggle.Destroy()
    floatGui.tooltipToggle := 0
}

SendKeyWithBoost(key, startTick) {
    elapsed := A_TickCount - startTick
    if (elapsed < boost.holdDelay)
        return
    ratio := Min((elapsed - boost.holdDelay) / 100, 1)
    b     := Max(Round(boost.maxBoost * (ratio ** 0.1)), 1)
    Loop b
        SendInput("{Blind}" key)
}

; ══════════════════════════════════════════════════════════════════
; AccionEnfoque — clicks de modo enfoque recalibrados con CALIBRADOR_v3_DPI
; en la Artist Pro 16 Gen2 (tableta a la izquierda del principal, x negativas):
; izquierdo en P25 (-2514, 86), derecho en P26 (-50, 84).
; ══════════════════════════════════════════════════════════════════
AccionEnfoque() {
    enfoque.activo := !enfoque.activo
    if (enfoque.activo) {
        MostrarGUIEnfoque()
        SoundBeep(1200, 40)
        Sleep(30)
        SoundBeep(1500, 40)
    } else {
        OcultarGUIEnfoque()
    }
    ; Reubica Deslizador/Circulo/AccesoRapido según el estado al que se
    ; acaba de entrar (enfoque.activo ya quedó actualizado arriba).
    ; INTERCAMBIADO a pedido: al activar enfoque se aplica el layout guardado
    ; como "Normal" y al salir el guardado como "Enfoque" (los layouts de
    ; Ctrl+F11 / Ctrl+F12 quedaron invertidos respecto al estado real).
    _AplicarLayoutPaneles(enfoque.activo ? "Normal" : "Enfoque")
    ; Obtener posición del mouse para restaurar después
    MouseGetPos(&origX, &origY)
    ; Click izquierdo — absoluto (-2514, 86)
    MouseMove(-2514, 86, 0)
    Sleep(8)
    Click()
    Sleep(12)
    ; Click derecho — absoluto (-50, 84)
    MouseMove(-50, 84, 0)
    Sleep(8)
    Click()
    Sleep(12)
    MouseMove(origX, origY, 0)
}

; ══════════════════════════════════════════════════════════════════
; Layouts de los 3 paneles flotantes (Deslizador / Círculo / Acceso rápido)
; por modo: "Normal" y "Enfoque". Se aplican al alternar enfoque.
;
; Se GUARDAN en posiciones_gui.ini (sección LayoutNormal / LayoutEnfoque)
; como distancia desde la esquina del monitor de CSP, así sobreviven a
; recargas y a cambios de monitor. Si no hay nada guardado para un panel,
; se usan los valores por defecto de LAYOUT_NORMAL / LAYOUT_ENFOQUE.
;
;   Ctrl+F11 = guarda las posiciones ACTUALES como layout Normal
;   Ctrl+F12 = guarda las posiciones ACTUALES como layout Enfoque
;
; Al aplicar, la posición se recorta para que el panel SIEMPRE quede
; dentro del monitor de CSP: nunca puede irse fuera de pantalla.
; ══════════════════════════════════════════════════════════════════
_IdsPaneles() {
    global colorV, colorCC, ar
    ids := Map()
    ids["ds"] := colorV.dsID
    ids["cc"] := colorCC.id
    ids["ar"] := ar.id
    return ids
}

_LayoutPanelGuardado(nombre, clave, mon) {
    ini := _PosGuiIniPath()
    sec := "Layout" nombre
    x := IniRead(ini, sec, clave "x", "")
    y := IniRead(ini, sec, clave "y", "")
    w := IniRead(ini, sec, clave "w", "")
    h := IniRead(ini, sec, clave "h", "")
    if (x = "" || y = "" || w = "" || h = "")
        return 0
    return { x: mon.x + Integer(x), y: mon.y + Integer(y), w: Integer(w), h: Integer(h) }
}

_AplicarLayoutPaneles(nombre) {
    global LAYOUT_NORMAL, LAYOUT_ENFOQUE
    mon := ObtenerMonitorCSP()
    def := (nombre = "Enfoque") ? LAYOUT_ENFOQUE : LAYOUT_NORMAL
    for clave, id in _IdsPaneles() {
        if (!id || !WinExist("ahk_id " id))
            continue
        r := _LayoutPanelGuardado(nombre, clave, mon)
        if (!r)
            r := def.%clave%
        x := Max(mon.x, Min(r.x, mon.x + mon.w - r.w))
        y := Max(mon.y, Min(r.y, mon.y + mon.h - r.h))
        try WinMove(x, y, r.w, r.h, "ahk_id " id)
    }
}

_CapturarLayout(nombre) {
    global colorV, colorCC, ar
    ; Feedback inmediato (sonido + tooltip) para saber que el atajo sí
    ; llegó al script, aunque después falle algo más abajo.
    SoundBeep(1000, 80)
    ToolTip("Guardando layout " nombre "...")
    SetTimer(() => ToolTip(), -1500)
    ; Si algún panel todavía no se ha resuelto (no le has pasado el mouse),
    ; se intenta encontrar por título.
    try {
        if (!colorV.dsID)
            colorV.dsID := BuscarVentanaCSP(0, "eslizador", "colores")
        if (!colorCC.id)
            colorCC.id := BuscarVentanaCSP(0, "rculo de colores", "olores")
        if (!ar.id)
            ar.id := BuscarVentanaCSP(0, "Acceso r", "pido")
    }
    mon := ObtenerMonitorCSP()
    ini := _PosGuiIniPath()
    sec := "Layout" nombre
    guardados := 0
    for clave, id in _IdsPaneles() {
        if (!id || !WinExist("ahk_id " id))
            continue
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " id)
            IniWrite(x - mon.x, ini, sec, clave "x")
            IniWrite(y - mon.y, ini, sec, clave "y")
            IniWrite(w, ini, sec, clave "w")
            IniWrite(h, ini, sec, clave "h")
            guardados++
        }
    }
    MostrarHUD("LAYOUT " StrUpper(nombre) " GUARDADO (" guardados "/3)", guardados = 3 ? "44DD88" : "FF6B00", 1600)
}

$^F11:: _CapturarLayout("Normal")
$^F12:: _CapturarLayout("Enfoque")

MostrarGUIEnfoque() {
    if IsObject(floatGui.enfoque)
        try floatGui.enfoque.Destroy()
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := "1A1A2E"
    g.SetFont("s12 Bold", "Segoe UI")
    g.AddText("cFFFFFF Center", "🎯 MODO ENFOQUE")
    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    mon := ObtenerMonitorCSP()
    g.Show("x" mon.x + (mon.w - w) // 2 " y" mon.y + Round(mon.h * 0.47) " w" w " h" h " NoActivate")
    WinSetTransparent(210, "ahk_id " g.Hwnd)
    floatGui.enfoque := g
}

OcultarGUIEnfoque() {
    if !IsObject(floatGui.enfoque)
        return
    g := floatGui.enfoque
    floatGui.enfoque := 0
    try {
        Loop 7 {
            transp := 210 - (A_Index * 30)
            if (transp < 0)
                transp := 0
            WinSetTransparent(transp, "ahk_id " g.Hwnd)
            Sleep(30)
        }
        g.Destroy()
    } catch {
        try g.Destroy()
    }
}

ResetEnfoque() {
    if (enfoque.activo) {
        enfoque.activo := false
        OcultarGUIEnfoque()
    }
}

ResetAlphaStates() {
    global colorEstado
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorEstado = 2)
            Send("k")
        if (colorEstado = 1)
            SendInput("^2")
        colorEstado := 0
        if IsObject(dial.g)
            dial.g.Hide()
        if IsObject(dsGui.g)
            dsGui.g.Hide()
        if IsObject(ccGui.g)
            ccGui.g.Hide()
        if IsObject(arGui.g)
            arGui.g.Hide()
        if IsObject(hcGui.g)
            hcGui.g.Hide()
        if IsObject(lockGui.g)
            lockGui.g.Hide()
        if IsObject(reloadGui.g)
            reloadGui.g.Hide()
        return
    }
    ; Restaurar dial, dsGui/ccGui/arGui, hcGui y reloadGui si CSP recuperó el foco
    if IsObject(dial.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", dial.g.Hwnd)
                dial.g.Show("NoActivate")
        }
    }
    if IsObject(dsGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", dsGui.g.Hwnd)
                dsGui.g.Show("NoActivate")
        }
    }
    if IsObject(ccGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", ccGui.g.Hwnd)
                ccGui.g.Show("NoActivate")
        }
    }
    if IsObject(arGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", arGui.g.Hwnd)
                arGui.g.Show("NoActivate")
        }
    }
    if IsObject(hcGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", hcGui.g.Hwnd)
                hcGui.g.Show("NoActivate")
        }
    }
    if IsObject(lockGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", lockGui.g.Hwnd)
                lockGui.g.Show("NoActivate")
        }
    }
    if IsObject(reloadGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", reloadGui.g.Hwnd)
                reloadGui.g.Show("NoActivate")
        }
    }
    ; Watchdog miniTip
    if (floatGui.miniTipID != 0 && floatGui.miniTipTick != 0) {
        if (A_TickCount - floatGui.miniTipTick > 4000) {
            try {
                if IsObject(floatGui.miniTip)
                    try floatGui.miniTip.Destroy()
            }
            floatGui.miniTip     := 0
            floatGui.miniTipID   := 0
            floatGui.miniTipTick := 0
        }
    }
}

#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
; Sin SetTimer/diferido: responde de inmediato en cada toque real, sin el
; lag de 250ms. AltF_state.held bloquea el auto-repeat de Windows mientras
; F sigue físicamente abajo (F se usa sostenida, a diferencia de s/x).
; La ventana de 300ms (igual que s/x) decide si el toque cuenta como
; "rápido" (SMEAR SOFT) o "suelto" (SMEAR). El choque con la "b" del combo
; Alt+B sigue resuelto igual: forzamos {b up}{b down} marcado como sintético.
!f:: {
    if !stylus.altActive
        return
    if AltF_state.held
        return
    AltF_state.held := true
    now := A_TickCount
    if (now - AltF_state.lastPress < 300) {
        AltF_state.lastPress := 0
        seguiaSostenido := stylus.altActive
        SendEvent("{Alt up}{NumpadEnd}")
        if (seguiaSostenido)
            SendEvent("{Alt down}")
        MostrarHUD("SMEAR SOFT  (2)", "FF6B00", 950)
    } else {
        AltF_state.lastPress := now
        stylus.bSinteticoTick := A_TickCount
        seguiaSostenido := stylus.altActive
        SendEvent("{Alt up}{b up}{b down}")
        if (seguiaSostenido)
            SendEvent("{Alt down}")
        MostrarHUD("SMEAR  (1)", "00E5FF", 950)
    }
}
!f up:: {
    AltF_state.held := false
}

~b & k:: {
    global colorEstado
    if (colorEstado = 1)
        SendInput("^2")
    Send("k")
    Send("k")
    colorEstado := 0
    MostrarMiniTexto("🔄 RESET → COLOR PRIMARIO", "1A1A2E", 1200)
}
#HotIf

; ┌──────────────────────────────────────────────────────────┐
; │  DIAL GUI — indicador permanente de modo del dial        │
; │  (tamaño 50% mayor y posición P5, Artist Pro 16 Gen2)     │
; └──────────────────────────────────────────────────────────┘
; ══════════════════════════════════════════════════════════════════
; GuardarPosicionGUI / LeerPosicionGUI — persisten la posición de los
; paneles arrastrables (dial, dsGui/ccGui/arGui) en un .ini junto al script,
; para que recuerden dónde los dejaste entre sesiones.
; ══════════════════════════════════════════════════════════════════
; Función en vez de variable global: una asignación suelta aquí nunca
; se ejecutaría, porque en AHK v2 la sección de auto-ejecución termina
; en el primer hotkey del script, y esto está muy por debajo de esa
; línea — quedaría vacía. Como función, se calcula cada vez que se llama.
_PosGuiIniPath() => A_ScriptDir "\posiciones_gui.ini"

GuardarPosicionGUI(nombre, hwnd) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    IniWrite(NumGet(rc, 0, "int"), _PosGuiIniPath(), nombre, "x")
    IniWrite(NumGet(rc, 4, "int"), _PosGuiIniPath(), nombre, "y")
}

; Devuelve un objeto {x, y} si hay posición guardada, o 0 si no.
LeerPosicionGUI(nombre) {
    x := IniRead(_PosGuiIniPath(), nombre, "x", "")
    y := IniRead(_PosGuiIniPath(), nombre, "y", "")
    if (x = "" || y = "")
        return 0
    return { x: Integer(x), y: Integer(y) }
}

; Verdadero si el punto (x,y) cae dentro de algún monitor conectado.
; Protege contra posiciones guardadas que quedaron fuera de pantalla
; (monitor desconectado, resolución cambiada, guardado corrupto, etc.)
; — sin esto, un GUI "invisible" no tiene forma fácil de recuperarse.
_PosicionValidaEnPantalla(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x <= r && y >= t && y <= b)
            return true
    }
    return false
}

; ══════════════════════════════════════════════════════════════════
; BLOQUE Slider + Circle + Quick — se comportan como una sola unidad.
; Arrastrar cualquiera de los tres mueve a los tres juntos. Solo se
; persiste el ancla (posición de dsGui); cc/ar se calculan siempre
; como offsets fijos desde el ancla, así que al reabrir el script
; SIEMPRE vuelven a quedar alineados en bloque, sin importar qué se
; haya hecho en la sesión anterior.
;
; Ahora el bloque incluye también HC y el botón de fijar (🔒/🔓). Con el
; bloque FIJADO no se puede arrastrar nada (el clic sigue funcionando).
; Se eliminó el arrastre suelto con Ctrl: el bloque siempre va unido.
; ══════════════════════════════════════════════════════════════════
_AnclaBloquePaneles() {
    static ancla := 0
    if IsObject(ancla)
        return ancla
    mon := ObtenerMonitorCSP()
    ; Ancho total del bloque horizontal (estimado, solo para centrar el
    ; primer panel): 3 paneles de 80px lógicos + 2 separaciones. El
    ; posicionamiento real de ccGui/arGui ya no depende de este valor
    ; (ver PANEL_GAP e IniciarCcGUI/IniciarArGUI), así que un desajuste
    ; aquí como mucho descentra un poco el bloque, no lo superpone.
    anchoBloque := 104 + PANEL_GAP + 104 + PANEL_GAP + 104
    defX := mon.x + (mon.w - anchoBloque) // 2
    defY := mon.y + Round(mon.h * 0.02) + 42 + 4
    guardada := LeerPosicionGUI("PanelBlock")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x, guardada.y) {
        ancla := guardada
        return ancla
    }
    ; Migración: si ya existía una posición individual guardada del
    ; slider (de antes de agrupar los paneles), se usa como ancla
    ; inicial para no perder la ubicación que ya se había encontrado.
    vieja := LeerPosicionGUI("Slider")
    if IsObject(vieja) && _PosicionValidaEnPantalla(vieja.x, vieja.y) {
        ancla := vieja
        return ancla
    }
    ancla := { x: defX, y: defY }
    return ancla
}

; Manejador compartido de arrastre del BLOQUE (dsGui, ccGui, arGui, hcGui
; y el botón de fijar). guiObj es el panel sobre el que se hizo clic.
; - Bloque FIJADO (panelBlk.locked): el arrastre no mueve nada; un clic
;   corto sigue haciendo el toggle propio del panel.
; - Bloque libre: arrastrar cualquiera mueve los cinco juntos y se
;   persiste solo el ancla (dsGui). Ya no hay arrastre suelto con Ctrl.
_ArrastrarPanelBloque(hwndClick, lParam, guiObj) {
    global dsGui, ccGui, arGui, hcGui, lockGui, panelBlk
    static arrastrando := false
    if (arrastrando)
        return
    if !IsObject(guiObj.g)
        return
    if !(hwndClick = guiObj.g.Hwnd || guiObj.g.Hwnd = DllCall("GetParent", "Ptr", hwndClick, "Ptr"))
        return
    arrastrando := true

    pt := Buffer(8, 0)
    NumPut("int", lParam & 0xFFFF,        pt, 0)
    NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
    DllCall("ClientToScreen", "Ptr", hwndClick, "Ptr", pt)
    clickX := NumGet(pt, 0, "int")
    clickY := NumGet(pt, 4, "int")

    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", guiObj.g.Hwnd, "Ptr", rc)
    origX := NumGet(rc, 0, "int")
    origY := NumGet(rc, 4, "int")
    offX := clickX - origX
    offY := clickY - origY

    ; Posiciones originales del resto del bloque, para moverlo junto.
    otros := []
    if !panelBlk.locked {
        for g in [dsGui, ccGui, arGui, hcGui, lockGui] {
            if (IsObject(g.g) && g.g.Hwnd != guiObj.g.Hwnd) {
                DllCall("GetWindowRect", "Ptr", g.g.Hwnd, "Ptr", rc)
                otros.Push({ g: g, x0: NumGet(rc, 0, "int"), y0: NumGet(rc, 4, "int") })
            }
        }
    }

    SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010
    cur := Buffer(8, 0)
    movido := false
    while GetKeyState("LButton", "P") {
        DllCall("GetCursorPos", "Ptr", cur)
        mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
        if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
            movido := true
            if !panelBlk.locked {
                newX := mx - offX
                newY := my - offY
                DllCall("SetWindowPos", "Ptr", guiObj.g.Hwnd, "Ptr", 0
                    , "int", newX, "int", newY, "int", 0, "int", 0
                    , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
                dx := newX - origX
                dy := newY - origY
                for o in otros {
                    DllCall("SetWindowPos", "Ptr", o.g.g.Hwnd, "Ptr", 0
                        , "int", o.x0 + dx, "int", o.y0 + dy, "int", 0, "int", 0
                        , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
                }
            }
        }
        Sleep(8)
    }

    if !movido {
        ; Click corto → toggle propio de este panel.
        if (guiObj.g.Hwnd = dsGui.g.Hwnd) {
            _ToggleColorV()
            ActualizarDsGUI()
        } else if (guiObj.g.Hwnd = ccGui.g.Hwnd) {
            _ToggleColorCC()
            ActualizarCcGUI()
        } else if (guiObj.g.Hwnd = arGui.g.Hwnd) {
            _ToggleAR()
            ActualizarArGUI()
        } else if (guiObj.g.Hwnd = hcGui.g.Hwnd) {
            _ToggleHistorialColor()
            ActualizarHCGUI()
        } else {
            _ToggleBloqueo()
        }
    } else if !panelBlk.locked {
        ; Se movió el bloque completo — se persiste solo el ancla.
        GuardarPosicionGUI("PanelBlock", dsGui.g.Hwnd)
    }
    arrastrando := false
}

; Fijar / liberar el bloque. Se guarda en el .ini (sección PanelBlock).
_ToggleBloqueo() {
    global panelBlk
    panelBlk.locked := !panelBlk.locked
    IniWrite(panelBlk.locked ? 1 : 0, _PosGuiIniPath(), "PanelBlock", "locked")
    ActualizarLockGUI()
    MostrarHUD(panelBlk.locked ? "🔒 BLOQUE FIJADO" : "🔓 BLOQUE LIBRE — arrastra para mover"
             , panelBlk.locked ? "44DD88" : "FF6B00", 1200)
}

; Offset del botón HC respecto al ancla del bloque (dsGui). Si no hay
; offset guardado, se migra desde la posición absoluta que tenía HC
; (así no cambia donde ya lo tenías) o, si no hay, va justo debajo.
_HcOffsetBloque() {
    global dsGui
    ini := _PosGuiIniPath()
    dx := IniRead(ini, "PanelBlock", "hcdx", "")
    dy := IniRead(ini, "PanelBlock", "hcdy", "")
    if (dx != "" && dy != "")
        return { dx: Integer(dx), dy: Integer(dy) }
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", dsGui.g.Hwnd, "Ptr", rc)
    ax := NumGet(rc, 0, "int"), ay := NumGet(rc, 4, "int")
    ah := NumGet(rc, 12, "int") - ay
    vieja := LeerPosicionGUI("HC")
    if IsObject(vieja) && _PosicionValidaEnPantalla(vieja.x, vieja.y) {
        dx := vieja.x - ax
        dy := vieja.y - ay
    } else {
        dx := 0
        dy := ah + PANEL_GAP
    }
    IniWrite(dx, ini, "PanelBlock", "hcdx")
    IniWrite(dy, ini, "PanelBlock", "hcdy")
    return { dx: dx, dy: dy }
}

IniciarDialGUI() {

    global dial
    dial.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    dial.g.BackColor := "1a1a1a"
    dial.g.MarginX := 0
    dial.g.MarginY := 0
    WinSetTransparent(200, dial.g)

    dial.icono := dial.g.Add("Text", "x6 y3 w34 h31 +0x200 cWhite", "")
    dial.icono.SetFont("s18 bold", "Segoe UI")

    dial.label := dial.g.Add("Text", "x43 y6 w130 h26 cWhite", "")
    dial.label.SetFont("s13 bold", "Segoe UI")

    dial.barra := dial.g.Add("Progress", "x0 y37 w182 h5 Background333333")

    OnMessage(0x0201, _DialWM_LBUTTONDOWN)

    ; Posición: centro horizontal del monitor CSP, mismo criterio que
    ; MostrarHUD/MostrarMiniGUI — ya no depende de un punto fijo.
    ; Si hay una posición guardada de un arrastre anterior, se usa esa.
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - 182) // 2
    y := mon.y + Round(mon.h * 0.02)
    guardada := LeerPosicionGUI("Dial")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x, guardada.y) {
        x := guardada.x
        y := guardada.y
    }
    dial.g.Show("x" x " y" y " w182 h42 NoActivate")
    ActualizarDialGUI()
}

ActualizarDialGUI() {
    if (dial.modo = 1) {
        dial.icono.Value := "🖌"
        dial.label.Value := "Tamaño"
        dial.barra.Opt("c00e5ff")
        dial.barra.Value := 100
    } else {
        dial.icono.Value := "◑"
        dial.label.Value := "Opacidad"
        dial.barra.Opt("cff6b00")
        dial.barra.Value := 100
    }
}

; ══════════════════════════════════════════════════════════════════
; _DialWM_LBUTTONDOWN — arrastre manual del dial GUI.
; El truco anterior (PostMessage WM_NCLBUTTONDOWN/HTCAPTION) delegaba
; el drag a Windows, pero al soltar el botón la posición se revertía
; (la ventana -ToolWindow +AlwaysOnTop nunca confirmaba el nuevo punto
; ante el propio sistema). Ahora se sigue el mouse a mano con WinMove
; en cada iteración y se corta al soltar el botón — la posición final
; queda fija de verdad, sin snap-back.
; ══════════════════════════════════════════════════════════════════
_DialWM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global dial
    static arrastrando := false
    if (arrastrando)
        return
    if (hwnd = dial.g.Hwnd || dial.g.Hwnd = DllCall("GetParent", "Ptr", hwnd, "Ptr")) {
        arrastrando := true
        ; Todo el arrastre usa API de Windows en crudo (Get/SetCursorPos,
        ; GetWindowRect, SetWindowPos) — antes se mezclaba ClientToScreen
        ; (crudo) con MouseGetPos/Gui.Move (con su propio ajuste de DPI de
        ; AHK), lo que dejaba un desfase residual. SWP_NOZORDER además evita
        ; que el dial reclame "encima" en cada tick, que era lo que hacía
        ; parpadear a los paneles de hover (deslizador/círculo/acceso rápido)
        ; mientras se arrastraba.
        pt := Buffer(8, 0)
        NumPut("int", lParam & 0xFFFF,        pt, 0)
        NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
        DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
        clickX := NumGet(pt, 0, "int")
        clickY := NumGet(pt, 4, "int")

        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", dial.g.Hwnd, "Ptr", rc)
        offX := clickX - NumGet(rc, 0, "int")
        offY := clickY - NumGet(rc, 4, "int")

        cur := Buffer(8, 0)
        SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010
        while GetKeyState("LButton", "P") {
            DllCall("GetCursorPos", "Ptr", cur)
            mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
            DllCall("SetWindowPos", "Ptr", dial.g.Hwnd, "Ptr", 0
                , "int", mx - offX, "int", my - offY, "int", 0, "int", 0
                , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
            Sleep(8)
        }
        GuardarPosicionGUI("Dial", dial.g.Hwnd)
        arrastrando := false
    }
}

; ┌──────────────────────────────────────────────────────────┐
; │  DS / CC / AR GUI — 3 botones permanentes (deslizador de   │
; │  color, círculo de colores, acceso rápido), mismo estilo    │
; │  visual que el dial (icono + label + barra). Un click corto │
; │  en cada uno alterna SOLO ese panel; +q / Alt+J siguen       │
; │  alternando los 3 juntos y refrescan los 3 botones.          │
; │  Se comportan como UN BLOQUE al arrastrarlos (ver             │
; │  _ArrastrarPanelBloque / _AnclaBloquePaneles más arriba):     │
; │  mover cualquiera mueve a los tres, y solo se persiste el     │
; │  ancla — así siempre se reagrupan al reabrir el script.        │
; │  Ctrl+arrastre mueve un panel suelto de forma puntual (no      │
; │  se guarda).                                                    │
; └──────────────────────────────────────────────────────────┘
IniciarDsGUI() {
    global dsGui
    dsGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    dsGui.g.BackColor := "1a1a1a"
    dsGui.g.MarginX := 0
    dsGui.g.MarginY := 0
    WinSetTransparent(200, dsGui.g)

    dsGui.icono := dsGui.g.Add("Text", "x4 y1 w20 h21 +0x200 cWhite", "")
    dsGui.icono.SetFont("s12 bold", "Segoe UI")

    dsGui.label := dsGui.g.Add("Text", "x26 y3 w76 h19 cWhite", "")
    dsGui.label.SetFont("s9 bold", "Segoe UI")

    dsGui.barra := dsGui.g.Add("Progress", "x0 y22 w104 h3 Background333333")

    OnMessage(0x0201, _DsGUI_WM_LBUTTONDOWN)

    ; Posición: ancla del bloque Slider+Circle+Quick (ver _AnclaBloquePaneles).
    ancla := _AnclaBloquePaneles()
    dsGui.g.Show("x" ancla.x " y" ancla.y " w104 h25 NoActivate")
    ActualizarDsGUI()
}

ActualizarDsGUI() {
    if (colorV.hover) {
        dsGui.icono.Value := "🎚"
        dsGui.label.Value := "SLIDER ON"
        dsGui.barra.Opt("c1E8449")
        dsGui.g.BackColor := "163D22"
        dsGui.barra.Value := 100
    } else {
        dsGui.icono.Value := "⏸"
        dsGui.label.Value := "SLIDER OFF"
        dsGui.barra.Opt("cD92B2B")
        dsGui.g.BackColor := "421A1A"
        dsGui.barra.Value := 100
    }
}

_DsGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global dsGui
    _ArrastrarPanelBloque(hwnd, lParam, dsGui)
}

IniciarCcGUI() {
    global ccGui
    ccGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    ccGui.g.BackColor := "1a1a1a"
    ccGui.g.MarginX := 0
    ccGui.g.MarginY := 0
    WinSetTransparent(200, ccGui.g)

    ccGui.icono := ccGui.g.Add("Text", "x4 y1 w20 h21 +0x200 cWhite", "")
    ccGui.icono.SetFont("s12 bold", "Segoe UI")

    ccGui.label := ccGui.g.Add("Text", "x26 y3 w76 h19 cWhite", "")
    ccGui.label.SetFont("s9 bold", "Segoe UI")

    ccGui.barra := ccGui.g.Add("Progress", "x0 y22 w104 h3 Background333333")

    OnMessage(0x0201, _CcGUI_WM_LBUTTONDOWN)

    ; Posición: justo a la derecha de dsGui, medido con su rectángulo REAL
    ; en pantalla (no un ancho asumido) — así no se superpone aunque el
    ; escalado/DPI de Windows haga que dsGui ocupe físicamente más o menos
    ; de los 80px "lógicos". Si por lo que sea el hwnd de dsGui todavía no
    ; está disponible (carrera al reload), no se cae el script: se usa una
    ; posición de respaldo calculada desde el ancla del bloque.
    try {
        WinGetPos(&dsX, &dsY, &dsW, &dsH, "ahk_id " dsGui.g.Hwnd)
    } catch {
        ancla := _AnclaBloquePaneles()
        dsX := ancla.x, dsY := ancla.y, dsW := 104
    }
    ccGui.g.Show("x" (dsX + dsW + PANEL_GAP) " y" dsY " w104 h25 NoActivate")
    ActualizarCcGUI()
}

ActualizarCcGUI() {
    if (colorCC.hover) {
        ccGui.icono.Value := "🎨"
        ccGui.label.Value := "CIRCLE ON"
        ccGui.barra.Opt("c1E8449")
        ccGui.g.BackColor := "163D22"
        ccGui.barra.Value := 100
    } else {
        ccGui.icono.Value := "⏸"
        ccGui.label.Value := "CIRCLE OFF"
        ccGui.barra.Opt("cD92B2B")
        ccGui.g.BackColor := "421A1A"
        ccGui.barra.Value := 100
    }
}

_CcGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global ccGui
    _ArrastrarPanelBloque(hwnd, lParam, ccGui)
}

IniciarArGUI() {
    global arGui
    arGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    arGui.g.BackColor := "1a1a1a"
    arGui.g.MarginX := 0
    arGui.g.MarginY := 0
    WinSetTransparent(200, arGui.g)

    arGui.icono := arGui.g.Add("Text", "x4 y1 w20 h21 +0x200 cWhite", "")
    arGui.icono.SetFont("s12 bold", "Segoe UI")

    arGui.label := arGui.g.Add("Text", "x26 y3 w76 h19 cWhite", "")
    arGui.label.SetFont("s9 bold", "Segoe UI")

    arGui.barra := arGui.g.Add("Progress", "x0 y22 w104 h3 Background333333")

    OnMessage(0x0201, _ArGUI_WM_LBUTTONDOWN)

    ; Posición: justo a la derecha de ccGui, medido con su rectángulo REAL
    ; en pantalla (mismo motivo que en IniciarCcGUI). Mismo respaldo si el
    ; hwnd de ccGui todavía no está disponible.
    try {
        WinGetPos(&ccX, &ccY, &ccW, &ccH, "ahk_id " ccGui.g.Hwnd)
    } catch {
        ancla := _AnclaBloquePaneles()
        ccX := ancla.x + 104 + PANEL_GAP, ccY := ancla.y, ccW := 104
    }
    arGui.g.Show("x" (ccX + ccW + PANEL_GAP) " y" ccY " w104 h25 NoActivate")
    ActualizarArGUI()
}

ActualizarArGUI() {
    if (ar.hover) {
        arGui.icono.Value := "⚡"
        arGui.label.Value := "QUICK ON"
        arGui.barra.Opt("c1E8449")
        arGui.g.BackColor := "163D22"
        arGui.barra.Value := 100
    } else {
        arGui.icono.Value := "⏸"
        arGui.label.Value := "QUICK OFF"
        arGui.barra.Opt("cD92B2B")
        arGui.g.BackColor := "421A1A"
        arGui.barra.Value := 100
    }
}

_ArGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global arGui
    _ArrastrarPanelBloque(hwnd, lParam, arGui)
}

; ┌──────────────────────────────────────────────────────────┐
; │  HC GUI — botón permanente HC ON/OFF (Historial de Color  │
; │  dinámico). Mismo tamaño/estilo que dsGui/ccGui/arGui. Un    │
; │  corto = mismo efecto que Numpad0. Se apila debajo de      │
; │  arGui y también se puede arrastrar para reposicionar.     │
; └──────────────────────────────────────────────────────────┘
IniciarHCGUI() {
    global hcGui
    hcGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    hcGui.g.BackColor := "1a1a1a"
    hcGui.g.MarginX := 0
    hcGui.g.MarginY := 0
    WinSetTransparent(200, hcGui.g)

    hcGui.icono := hcGui.g.Add("Text", "x4 y1 w20 h21 +0x200 cWhite", "")
    hcGui.icono.SetFont("s12 bold", "Segoe UI")

    hcGui.label := hcGui.g.Add("Text", "x26 y3 w76 h19 cWhite", "")
    hcGui.label.SetFont("s9 bold", "Segoe UI")

    hcGui.barra := hcGui.g.Add("Progress", "x0 y22 w104 h3 Background333333")

    OnMessage(0x0201, _HCGUI_WM_LBUTTONDOWN)

    ; Posición: relativa al ancla del bloque (dsGui), para moverse junto
    ; con Slider/Circle/Quick (ver _HcOffsetBloque).
    WinGetPos(&aX, &aY, , , "ahk_id " dsGui.g.Hwnd)
    off := _HcOffsetBloque()
    x := aX + off.dx
    y := aY + off.dy
    hcGui.g.Show("x" x " y" y " w104 h25 NoActivate")
    ActualizarHCGUI()
}

ActualizarHCGUI() {
    if (hist.modo = 1) {
        hcGui.icono.Value := "🟢"
        hcGui.label.Value := "HC ON"
        hcGui.barra.Opt("c1E8449")
        hcGui.g.BackColor := "163D22"
        hcGui.barra.Value := 100
    } else {
        hcGui.icono.Value := "🔒"
        hcGui.label.Value := "HC OFF"
        hcGui.barra.Opt("cD92B2B")
        hcGui.g.BackColor := "421A1A"
        hcGui.barra.Value := 100
    }
}

; Click corto = toggle (como Numpad0). Arrastre = mueve el bloque (si
; no está fijado); todo lo maneja _ArrastrarPanelBloque.
_HCGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global hcGui
    _ArrastrarPanelBloque(hwnd, lParam, hcGui)
}

; ┌──────────────────────────────────────────────────────────┐
; │  LOCK GUI — botón de fijar el bloque. Va a la derecha de   │
; │  arGui y forma parte del bloque (se mueve con él cuando    │
; │  está libre). 🔒 = fijado (no se puede arrastrar),         │
; │  🔓 = libre. Click corto = alternar. Se guarda en el .ini. │
; └──────────────────────────────────────────────────────────┘
IniciarLockGUI() {
    global lockGui, panelBlk
    panelBlk.locked := (IniRead(_PosGuiIniPath(), "PanelBlock", "locked", "1") = "1")
    lockGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    lockGui.g.BackColor := "1a1a1a"
    lockGui.g.MarginX := 0
    lockGui.g.MarginY := 0
    WinSetTransparent(200, lockGui.g)

    lockGui.icono := lockGui.g.Add("Text", "x0 y0 w31 h22 +0x201 cWhite", "")
    lockGui.icono.SetFont("s14 bold", "Segoe UI")
    lockGui.barra := lockGui.g.Add("Progress", "x0 y22 w31 h3 Background333333")

    OnMessage(0x0201, _LockGUI_WM_LBUTTONDOWN)

    try {
        WinGetPos(&arX, &arY, &arW, &arH, "ahk_id " arGui.g.Hwnd)
    } catch {
        ancla := _AnclaBloquePaneles()
        arX := ancla.x + 2 * (104 + PANEL_GAP), arY := ancla.y, arW := 104
    }
    lockGui.g.Show("x" (arX + arW + PANEL_GAP) " y" arY " w31 h25 NoActivate")
    ActualizarLockGUI()
}

ActualizarLockGUI() {
    if (panelBlk.locked) {
        lockGui.icono.Value := "🔒"
        lockGui.barra.Opt("c1E8449")
        lockGui.g.BackColor := "163D22"
    } else {
        lockGui.icono.Value := "🔓"
        lockGui.barra.Opt("cFF6B00")
        lockGui.g.BackColor := "5A3A0F"
    }
    lockGui.barra.Value := 100
}

_LockGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global lockGui
    _ArrastrarPanelBloque(hwnd, lParam, lockGui)
}

; ┌──────────────────────────────────────────────────────────┐
; │  RELOAD GUI — botón permanente para recargar el script.   │
; │  Mismo tamaño/estilo que dsGui/hcGui. Un click corto        │
; │  llama a Reload() directo — NO es el botón de pánico       │
; │  (Numpad8), es un reload limpio y simple. Se apila debajo  │
; │  de hcGui y también se puede arrastrar para reposicionar.  │
; └──────────────────────────────────────────────────────────┘
IniciarReloadGUI() {
    global reloadGui
    reloadGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    reloadGui.g.BackColor := "1a1a1a"
    reloadGui.g.MarginX := 0
    reloadGui.g.MarginY := 0
    WinSetTransparent(200, reloadGui.g)

    ; Solo el símbolo, centrado — botón ajustado al tamaño del icono.
    reloadGui.icono := reloadGui.g.Add("Text", "x0 y0 w31 h22 +0x201 cWhite", "🔄")
    reloadGui.icono.SetFont("s17 bold", "Segoe UI")

    reloadGui.barra := reloadGui.g.Add("Progress", "x0 y22 w31 h3 Background333333 c00A2E8")
    reloadGui.barra.Value := 100

    OnMessage(0x0201, _ReloadGUI_WM_LBUTTONDOWN)

    ; Justo debajo de hcGui, alineado a la izquierda de esa columna
    ; (mismo x que los otros paneles, sin recentrar por su propio ancho
    ; angosto), salvo que haya una posición guardada de un arrastre anterior.
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - 104) // 2
    y := mon.y + Round(mon.h * 0.02) + 42 + 4 + 25 + 4 + 25 + 4 + 25 + 4 + 25 + 4
    guardada := LeerPosicionGUI("Reload")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x, guardada.y) {
        x := guardada.x
        y := guardada.y
    }
    reloadGui.g.Show("x" x " y" y " w31 h25 NoActivate")
}

; Click corto = Reload() directo. Arrastre = mover el botón.
_ReloadGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global reloadGui
    static arrastrando := false
    if (arrastrando)
        return
    if (hwnd = reloadGui.g.Hwnd || reloadGui.g.Hwnd = DllCall("GetParent", "Ptr", hwnd, "Ptr")) {
        arrastrando := true
        pt := Buffer(8, 0)
        NumPut("int", lParam & 0xFFFF,        pt, 0)
        NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
        DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
        clickX := NumGet(pt, 0, "int")
        clickY := NumGet(pt, 4, "int")

        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", reloadGui.g.Hwnd, "Ptr", rc)
        offX := clickX - NumGet(rc, 0, "int")
        offY := clickY - NumGet(rc, 4, "int")

        cur := Buffer(8, 0)
        SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010
        movido := false
        while GetKeyState("LButton", "P") {
            DllCall("GetCursorPos", "Ptr", cur)
            mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
            if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                movido := true
                DllCall("SetWindowPos", "Ptr", reloadGui.g.Hwnd, "Ptr", 0
                    , "int", mx - offX, "int", my - offY, "int", 0, "int", 0
                    , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
            }
            Sleep(8)
        }
        if !movido {
            SoundBeep(700, 60)
            Reload()
        } else {
            GuardarPosicionGUI("Reload", reloadGui.g.Hwnd)
        }
        arrastrando := false
    }
}
